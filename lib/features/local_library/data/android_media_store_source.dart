import 'package:flutter/foundation.dart';

import '../../../models/track.dart';
import '../domain/local_exclusions.dart';
import '../domain/music_filter.dart';
import '../domain/local_library_source.dart';
import 'local_library_service.dart';
import 'local_scan_store.dart';
import 'local_scanner.dart';

/// Android: la lista sale de la biblioteca del sistema (MediaStore, por el canal propio `kiji/media`),
/// con su fecha de agregado; los datos completos y la portada, de cada archivo (con caché: solo
/// se leen los nuevos o cambiados). Si un archivo no se puede leer, queda lo del MediaStore.
class AndroidMediaStoreSource implements LocalLibrarySource {
  AndroidMediaStoreSource([LocalLibraryService? service, LocalScanStore? store])
    : _service = service ?? LocalLibraryService(),
      _store = store ?? LocalScanStore();

  final LocalLibraryService _service;
  final LocalScanStore _store;


  @override
  bool get usesFolders => false;

  @override
  Future<List<String>> folders() async => const [];

  @override
  Future<bool> hasAccess() => _service.hasPermission();

  @override
  Future<bool> requestAccess() => _service.requestPermission();

  @override
  Future<void> removeFolder(String folder) async {}

  /// Las carpetas con audios de la última lectura (para "Carpetas de música").
  static List<MusicFolder> lastFolders = const [];

  /// El último resumen registrado (para registrarlo una sola vez, y otra solo si cambia).
  static String? _lastSummary;

  static AudioCandidate _candidate(MediaStoreSong song) => AudioCandidate(
    path: song.data,
    artist: song.artist,
    isMusic: song.isMusic,
    isRecording: song.isRecording,
    durationMs: song.duration,
  );

  /// Las carpetas con audios y si se muestran (lee el MediaStore; no cambia nada).
  Future<List<MusicFolder>> musicFolders({LocalExclusions exclusions = LocalExclusions.defaults}) async {
    final songs = await _service.fetchSongs();
    return lastFolders = filterMusic([for (final s in songs) _candidate(s)], exclusions: exclusions, choices: exclusions.choices).folders;
  }

  @override
  Future<List<Track>> loadTracks({bool force = false, LocalExclusions exclusions = LocalExclusions.defaults}) async {
    final songs = await _service.fetchSongs();
    final result = filterMusic([for (final s in songs) _candidate(s)], exclusions: exclusions, choices: exclusions.choices);
    lastFolders = result.folders;
    // Una vez (y otra solo si cambia): cuántos quedaron afuera y por qué. Sin nombres de archivos.
    final summary = '${result.totalSkipped} audios afuera (sistema ${result.skipped[MusicSkip.system]}, '  // l10n-ignore (registro)
        'voz ${result.skipped[MusicSkip.voice]}, carpeta oculta ${result.skipped[MusicSkip.hiddenFolder]})';  // l10n-ignore (registro)
    if (result.totalSkipped > 0 && summary != _lastSummary) debugPrint('=== BIBLIOTECA: $summary ===');
    _lastSummary = summary;
    final entries = <ScanEntry>[];
    for (final i in result.kept) {
      final song = songs[i];
      // Formatos que Kiji reproduce (lo demás se saltea sin avisos).
      final ext = song.fileExtension.toLowerCase();
      if (!localAudioExtensions.contains('.$ext')) {
        debugPrint('=== BIBLIOTECA: se saltea un formato que no se lee (.$ext) ===');
        continue;
      }
      entries.add(
        ScanEntry(
          id: 'local-${song.id}',
          path: song.data,
          sizeBytes: song.size,
          // El MediaStore da segundos.
          modifiedMs: (song.dateModified ?? 0) * 1000,
          addedAtMs: song.dateAdded == null ? null : song.dateAdded! * 1000,
          title: song.title,
          artist: song.artist,
          album: song.album,
          genre: song.genre,
          track: song.track,
          durationMs: song.duration,
        ),
      );
    }
    final tracks = await _store.scan(entries: entries, force: force, exclusions: exclusions);
    return [...tracks]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
}
