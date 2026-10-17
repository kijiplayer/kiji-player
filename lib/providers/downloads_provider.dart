import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/downloads/data/download_service.dart';
import '../features/downloads/data/downloads_repository.dart';
import '../features/downloads/data/storage_info_impl.dart';
import '../features/downloads/domain/download_settings.dart';
import '../features/downloads/domain/downloaded_track.dart';
import '../features/downloads/domain/storage_info.dart';
import '../models/track.dart';

final downloadsRepositoryProvider = Provider<DownloadsRepository>((ref) => DownloadsRepository());

final storageInfoProvider = Provider<StorageInfo>((ref) => createStorageInfo());

final downloadServiceProvider = Provider<DownloadService>(
  (ref) => DownloadService(ref.watch(downloadsRepositoryProvider)),
);

enum ActiveDownloadStatus { queued, downloading, failed }

/// Una descarga que todavía no terminó (en cola, bajando o con error).
class ActiveDownload {
  const ActiveDownload({
    required this.track,
    required this.status,
    this.estimate,
    this.received = 0,
    this.total,
    this.errorMessage,
  });

  final Track track;
  final ActiveDownloadStatus status;
  final DownloadEstimate? estimate;
  final int received;
  final int? total;

  /// Mensaje simple para el usuario, sin detalles técnicos.
  final String? errorMessage;

  double? get progress => total == null || total == 0 ? null : received / total!;

  ActiveDownload copyWith({
    ActiveDownloadStatus? status,
    DownloadEstimate? estimate,
    int? received,
    int? total,
    String? errorMessage,
  }) =>
      ActiveDownload(
        track: track,
        status: status ?? this.status,
        estimate: estimate ?? this.estimate,
        received: received ?? this.received,
        total: total ?? this.total,
        errorMessage: errorMessage,
      );
}

class DownloadsState {
  const DownloadsState({
    this.completed = const {},
    this.active = const {},
    this.settings = const DownloadSettings(),
    this.loaded = false,
    this.directoryPath,
  });

  /// Descargas terminadas, por `videoId`.
  final Map<String, DownloadedTrack> completed;

  /// Descargas en curso, por `videoId`.
  final Map<String, ActiveDownload> active;
  final DownloadSettings settings;
  final bool loaded;

  /// Carpeta de descargas (para mostrar las portadas guardadas).
  final String? directoryPath;

  int get usedBytes => completed.values.fold(0, (sum, track) => sum + track.sizeBytes);

  DownloadsState copyWith({
    Map<String, DownloadedTrack>? completed,
    Map<String, ActiveDownload>? active,
    DownloadSettings? settings,
    bool? loaded,
    String? directoryPath,
  }) =>
      DownloadsState(
        completed: completed ?? this.completed,
        active: active ?? this.active,
        settings: settings ?? this.settings,
        loaded: loaded ?? this.loaded,
        directoryPath: directoryPath ?? this.directoryPath,
      );
}

/// Resultado de revisar una descarga antes de empezarla. La UI lo muestra
/// en el diálogo de confirmación.
class DownloadCheck {
  const DownloadCheck({
    this.estimate,
    this.freeBytes,
    this.blockedReason,
    this.waitingForWifi = false,
  });

  final DownloadEstimate? estimate;

  /// Espacio libre en el disco, o null si la plataforma no lo informa.
  final int? freeBytes;

  /// Si no, por qué no se puede descargar (texto para el usuario).
  final String? blockedReason;

  /// Bloqueada solo porque no hay WiFi y el usuario eligió "solo con WiFi".
  final bool waitingForWifi;

  bool get canDownload => blockedReason == null && estimate != null;
}

class DownloadsNotifier extends Notifier<DownloadsState> {
  /// Cuántas descargas corren a la vez.
  static const _maxParallel = 2;

  final Map<String, CancelToken> _cancelTokens = {};

  DownloadsRepository get _repository => ref.read(downloadsRepositoryProvider);
  DownloadService get _service => ref.read(downloadServiceProvider);

  @override
  DownloadsState build() {
    unawaited(Future.microtask(_load));
    return const DownloadsState();
  }

  Future<void> _load() async {
    try {
      final completed = await _repository.all();
      final settings = await _repository.loadSettings();
      final directory = await _repository.directory();
      state = state.copyWith(
        completed: Map.of(completed),
        settings: settings,
        loaded: true,
        directoryPath: directory.path,
      );
    } catch (error) {
      debugPrint('=== DESCARGAS: no se pudo leer el índice: $error ===');
      state = state.copyWith(loaded: true);
    }
  }

  Future<bool> _onWifiOrEthernet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);
    } catch (error) {
      debugPrint('=== DESCARGAS: no se pudo saber el tipo de conexión: $error ===');
      // Sin datos para decidir: no bloqueamos.
      return true;
    }
  }

  /// Revisa todo antes de descargar: si YouTube da audio, cuánto ocupa,
  /// cuánto espacio queda, el límite elegido y la opción "solo con WiFi".
  Future<DownloadCheck> check(Track track) async {
    final videoId = track.youtubeVideoId;
    if (videoId == null) {
      return const DownloadCheck(blockedReason: 'Solo se pueden descargar canciones de YouTube.');
    }
    if (state.settings.wifiOnly && !await _onWifiOrEthernet()) {
      return const DownloadCheck(
        blockedReason: 'Estás sin WiFi y elegiste descargar solo con WiFi. '
            'Podés cambiarlo en Biblioteca → Descargadas.',
        waitingForWifi: true,
      );
    }

    final DownloadEstimate? estimate;
    try {
      estimate = await _service.estimate(videoId);
    } catch (error) {
      debugPrint('=== DESCARGAS: falló la estimación de $videoId: $error ===');
      return const DownloadCheck(blockedReason: 'No se pudo conectar con YouTube. Probá de nuevo.');
    }
    if (estimate == null) {
      return const DownloadCheck(blockedReason: 'YouTube no ofrece audio para esta canción.');
    }

    final freeBytes = await ref
        .read(storageInfoProvider)
        .freeBytes((await _repository.directory()).path);
    final size = estimate.sizeBytes;

    String? blocked;
    if (size != null && freeBytes != null && size > freeBytes) {
      blocked = 'No hay espacio suficiente en el dispositivo.';
    }
    final limit = state.settings.limitBytes;
    if (size != null && limit != null && state.usedBytes + size > limit) {
      blocked = 'Superaría el límite de espacio para descargas que elegiste. '
          'Podés cambiarlo o borrar descargas en Biblioteca → Descargadas.';
    }
    return DownloadCheck(estimate: estimate, freeBytes: freeBytes, blockedReason: blocked);
  }

  /// Pone [track] en la cola de descargas (con la estimación ya hecha).
  void start(Track track, DownloadEstimate estimate) {
    final videoId = track.youtubeVideoId;
    if (videoId == null || state.completed.containsKey(videoId)) return;
    state = state.copyWith(active: {
      ...state.active,
      videoId: ActiveDownload(
        track: track,
        status: ActiveDownloadStatus.queued,
        estimate: estimate,
        total: estimate.sizeBytes,
      ),
    });
    _pump();
  }

  /// Arranca descargas en cola mientras haya lugar.
  void _pump() {
    final running =
        state.active.values.where((d) => d.status == ActiveDownloadStatus.downloading).length;
    if (running >= _maxParallel) return;
    final next = state.active.entries
        .where((e) => e.value.status == ActiveDownloadStatus.queued)
        .firstOrNull;
    if (next == null) return;
    unawaited(_run(next.key));
    _pump();
  }

  void _updateActive(String videoId, ActiveDownload Function(ActiveDownload) change) {
    final current = state.active[videoId];
    if (current == null) return;
    state = state.copyWith(active: {...state.active, videoId: change(current)});
  }

  Future<void> _run(String videoId) async {
    final token = CancelToken();
    _cancelTokens[videoId] = token;
    _updateActive(videoId, (d) => d.copyWith(status: ActiveDownloadStatus.downloading));

    var download = state.active[videoId]!;
    try {
      var estimate = download.estimate ?? await _service.estimate(videoId);
      if (estimate == null) throw const ExpiredUrlException();

      (String, int) result;
      try {
        result = await _download(videoId, estimate, token);
      } on ExpiredUrlException {
        // La URL vence en unas horas: se pide otra y se sigue desde el .part.
        debugPrint('=== DESCARGAS: URL vencida para $videoId, se resuelve de nuevo ===');
        estimate = await _service.estimate(videoId);
        if (estimate == null) rethrow;
        result = await _download(videoId, estimate, token);
      }

      download = state.active[videoId] ?? download;
      final thumbnail = await _service.downloadThumbnail(videoId, download.track.thumbnailUrl);
      final track = download.track;
      final entry = DownloadedTrack(
        videoId: videoId,
        title: track.title,
        artist: track.artist,
        coverColor: track.coverColor,
        album: track.album,
        durationMs: track.durationMs,
        fileName: result.$1,
        sizeBytes: result.$2,
        downloadedAt: DateTime.now(),
        thumbnailFileName: thumbnail,
      );
      await _repository.add(entry);
      debugPrint('=== DESCARGAS: "${track.title}" lista (${result.$2} bytes) ===');
      state = state.copyWith(
        completed: {...state.completed, videoId: entry},
        active: Map.of(state.active)..remove(videoId),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return; // cancel() ya limpió el estado
      debugPrint('=== DESCARGAS: falló $videoId: $error ===');
      _fail(videoId, 'Se cortó la conexión. Tocá para reintentar: sigue desde donde quedó.');
    } catch (error) {
      debugPrint('=== DESCARGAS: falló $videoId: $error ===');
      _fail(videoId, 'No se pudo descargar. Tocá para reintentar.');
    } finally {
      _cancelTokens.remove(videoId);
      _pump();
    }
  }

  Future<(String, int)> _download(String videoId, DownloadEstimate estimate, CancelToken token) {
    return _service.download(
      videoId,
      estimate,
      cancelToken: token,
      onProgress: (received, total) => _updateActive(
        videoId,
        (d) => d.copyWith(received: received, total: total),
      ),
    );
  }

  void _fail(String videoId, String message) {
    // La estimación se descarta: al reintentar se pide una URL nueva.
    final current = state.active[videoId];
    if (current == null) return;
    state = state.copyWith(active: {
      ...state.active,
      videoId: ActiveDownload(
        track: current.track,
        status: ActiveDownloadStatus.failed,
        received: current.received,
        total: current.total,
        errorMessage: message,
      ),
    });
  }

  /// Reintenta una descarga fallida, sin perder lo que ya se bajó.
  void retry(String videoId) {
    _updateActive(videoId, (d) => d.copyWith(status: ActiveDownloadStatus.queued));
    _pump();
  }

  /// Cancela y borra lo que se había bajado (no queda espacio ocupado a escondidas).
  Future<void> cancel(String videoId) async {
    _cancelTokens.remove(videoId)?.cancel();
    final download = state.active[videoId];
    state = state.copyWith(active: Map.of(state.active)..remove(videoId));
    if (download != null) await _deletePartials(videoId);
    _pump();
  }

  /// Frena una descarga sin borrar lo bajado: al volver a empezarla sigue
  /// desde el `.part` (Tarea Z7, pausar la descarga de una playlist).
  void pause(String videoId) {
    _cancelTokens.remove(videoId)?.cancel();
    state = state.copyWith(active: Map.of(state.active)..remove(videoId));
    _pump();
  }

  Future<void> _deletePartials(String videoId) async {
    try {
      final dir = await _repository.directory();
      await for (final entity in dir.list()) {
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('$videoId.') && name.endsWith('.part')) {
          await entity.delete();
        }
      }
    } catch (error) {
      debugPrint('=== DESCARGAS: no se pudo borrar el parcial de $videoId: $error ===');
    }
  }

  Future<void> delete(String videoId) async {
    await _repository.remove(videoId);
    state = state.copyWith(completed: Map.of(state.completed)..remove(videoId));
  }

  Future<void> deleteAll() async {
    for (final videoId in [...state.completed.keys]) {
      await _repository.remove(videoId);
    }
    state = state.copyWith(completed: const {});
  }

  Future<void> setWifiOnly(bool value) => _saveSettings(state.settings.copyWith(wifiOnly: value));

  Future<void> setLimit(int? bytes) =>
      _saveSettings(state.settings.copyWith(limitBytes: () => bytes));

  Future<void> _saveSettings(DownloadSettings settings) async {
    state = state.copyWith(settings: settings);
    await _repository.saveSettings(settings);
  }
}

final downloadsProvider =
    NotifierProvider<DownloadsNotifier, DownloadsState>(DownloadsNotifier.new);
