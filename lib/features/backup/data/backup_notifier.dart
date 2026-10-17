import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/local_library_provider.dart';
import '../../equalizer/data/equalizer_notifier.dart';
import '../../favorites/favorites.dart';
import '../../history/listening_history.dart';
import '../../import/data/import_service.dart';
import '../../playlists/playlists_provider.dart';
import '../../settings/data/settings_store.dart';
import '../domain/backup_manifest.dart';
import 'backup_folder.dart';
import 'backup_service.dart';

/// Una copia en la carpeta.
class BackupEntry {
  const BackupEntry({required this.file, required this.date, required this.sizeBytes});
  final File file;
  final DateTime date;
  final int sizeBytes;
}

class BackupState {
  const BackupState({this.folder, this.copies = const [], this.busy = false, this.error});

  final Directory? folder;

  /// De la más nueva a la más vieja.
  final List<BackupEntry> copies;
  final bool busy;
  final String? error;

  DateTime? get lastBackup => copies.isEmpty ? null : copies.first.date;

  BackupState copyWith({Directory? folder, List<BackupEntry>? copies, bool? busy, String? error, bool clearError = false}) =>
      BackupState(
        folder: folder ?? this.folder,
        copies: copies ?? this.copies,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Copia de seguridad (Tarea U): una por día, automática; se guardan las
/// últimas 7; restaurar con vista previa y una copia de lo actual antes.
class BackupNotifier extends Notifier<BackupState> {
  BackupNotifier({
    Future<Directory> Function()? dataDirectory,
    Future<Directory> Function()? defaultFolder,
    DateTime Function()? clock,
    this.platform,
  })  : _dataDirectory = dataDirectory ?? getApplicationSupportDirectory,
        _defaultFolder = defaultFolder ?? defaultBackupFolder,
        _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _dataDirectory;
  final Future<Directory> Function() _defaultFolder;
  final DateTime Function() _clock;
  /// Para el manifiesto (en los tests, fijo).
  final String? platform;
  Timer? _timer;
  final Completer<void> _ready = Completer();

  /// Se completa cuando ya se ubicó la carpeta y se hizo (o no) la copia diaria.
  Future<void> get ready => _ready.future;

  BackupService get _service => BackupService(dataDirectory: _dataDirectory, platform: platform);

  @override
  BackupState build() {
    ref.onDispose(() => _timer?.cancel());
    unawaited(Future.microtask(_init));
    return const BackupState();
  }

  Future<void> _init() async {
    try {
      await ref.read(settingsProvider.notifier).loaded;
      await _locate();
      await maybeAutoBackup();
      // Si Kiji queda abierta días, se revisa cada hora.
      _timer = Timer.periodic(const Duration(hours: 1), (_) => unawaited(maybeAutoBackup()));
    } catch (error) {
      debugPrint('=== COPIA: no se pudo preparar: $error ===');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<Directory> _folder() async {
    final chosen = ref.read(settingsProvider).backupFolder;
    return chosen != null ? Directory(chosen) : await _defaultFolder();
  }

  Future<void> _locate() async {
    final folder = await _folder();
    state = state.copyWith(folder: folder, copies: await _list(folder));
  }

  Future<List<BackupEntry>> _list(Directory folder) async {
    try {
      return [
        for (final file in await _service.list(folder))
          BackupEntry(file: file, date: backupDateFromName(p.basename(file.path))!, sizeBytes: await file.length()),
      ];
    } catch (error) {
      debugPrint('=== COPIA: no se pudo leer la carpeta ${folder.path}: $error ===');
      return const [];
    }
  }

  /// Hace la copia del día si está activa y todavía no se hizo.
  Future<void> maybeAutoBackup() async {
    if (!ref.read(settingsProvider).autoBackup || state.busy) return;
    if (!shouldAutoBackup(state.lastBackup, _clock())) return;
    await _create('diaria');
  }

  Future<bool> backupNow() => _create('manual');

  Future<bool> _create(String reason) async {
    final folder = state.folder ?? await _folder();
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _service.create(folder, reason: reason, now: _clock());
      state = state.copyWith(folder: folder, copies: await _list(folder), busy: false);
      return true;
    } catch (error) {
      debugPrint('=== COPIA: no se pudo hacer ($reason): $error ===');
      state = state.copyWith(busy: false, error: 'No se pudo hacer la copia en ${folder.path}.');
      return false;
    }
  }

  Future<void> setAutoBackup(bool value) async {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(autoBackup: value));
    if (value) await maybeAutoBackup();
  }

  /// Cambia la carpeta (null = la de fábrica). Devuelve el motivo si no sirve.
  Future<String?> setFolder(String? path) async {
    final folder = path == null ? await _defaultFolder() : Directory(path);
    final problem = await checkWritable(folder);
    if (problem != null) return problem;
    await ref
        .read(settingsProvider.notifier)
        .update((s) => path == null ? s.copyWith(defaultBackupFolder: true) : s.copyWith(backupFolder: path));
    await _locate();
    return null;
  }

  Future<BackupPreview> preview(File file) => _service.preview(file);

  /// Restaura [file] (antes guarda lo actual) y recarga los datos de Kiji.
  Future<BackupPreview> restore(File file) async {
    final folder = state.folder ?? await _folder();
    state = state.copyWith(busy: true, clearError: true);
    try {
      final preview = await _service.restore(file, safetyFolder: folder);
      // Cada parte vuelve a leer su archivo.
      ref
        ..invalidate(settingsProvider)
        ..invalidate(playlistsProvider)
        ..invalidate(favoritesProvider)
        ..invalidate(listeningHistoryProvider)
        ..invalidate(equalizerProvider)
        ..invalidate(importsProvider)
        ..invalidate(localLibrarySourceProvider);
      await ref.read(settingsProvider.notifier).loaded;
      state = state.copyWith(busy: false);
      await _locate();
      return preview;
    } catch (error) {
      state = state.copyWith(busy: false, error: '$error');
      rethrow;
    }
  }

  /// Vuelve a poner en la cola de descargas las canciones de la copia.
  /// Devuelve cuántas se pusieron y el primer motivo de las que no.
  Future<(int, String?)> redownload(List<BackupDownload> downloads) async {
    final notifier = ref.read(downloadsProvider.notifier);
    var started = 0;
    String? blocked;
    for (final d in downloads) {
      if (ref.read(downloadsProvider).completed.containsKey(d.videoId)) continue;
      final track = Track(
        id: 'yt-${d.videoId}',
        title: d.title,
        artist: d.artist,
        album: d.album,
        durationMs: d.durationMs,
        coverColor: const Color(0xFF7C5CFF),
        audioUrl: '',
        source: TrackSource.youtube,
      );
      final check = await notifier.check(track);
      if (check.canDownload) {
        notifier.start(track, check.estimate!);
        started++;
      } else {
        blocked ??= check.blockedReason;
      }
    }
    return (started, blocked);
  }
}

final backupProvider = NotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
