import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/downloads/data/download_service.dart';
import '../features/downloads/data/downloads_repository.dart';
import '../features/downloads/data/storage_info_impl.dart';
import '../features/downloads/domain/download_settings.dart';
import '../features/downloads/domain/download_failure.dart';
import '../features/downloads/domain/downloaded_track.dart';
import '../features/extractor/data/alternatives.dart';
import '../features/extractor/data/engines.dart';
import '../features/extractor/data/stream_resolver.dart';
import '../features/extractor/data/ytdlp_engine.dart';
import '../features/yt_music/data/ytm_client.dart';
import '../features/downloads/domain/storage_info.dart';
import '../models/track.dart';

import 'package:kiji_player/l10n/l10n.dart';

final downloadsRepositoryProvider = Provider<DownloadsRepository>((ref) => DownloadsRepository());

final storageInfoProvider = Provider<StorageInfo>((ref) => createStorageInfo());

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final client = YtMusicClient();
  return DownloadService(
    ref.watch(downloadsRepositoryProvider),
    ytClient: client,
    resolver: StreamResolver(engines: [InnerTubeXEngine(), KijiEngine(client), ref.read(ytDlpEngineProvider)]),
  );
});

enum ActiveDownloadStatus { queued, downloading, failed }

/// Una descarga que todavía no terminó (en cola, bajando o con error).
class ActiveDownload {
  const ActiveDownload({
    required this.track,
    required this.status,
    this.estimate,
    this.received = 0,
    this.total,
    this.failure,
    this.sourceId,
    this.refusedPaths = const {},
    this.searching = false,
  });

  final Track track;
  final ActiveDownloadStatus status;
  final DownloadEstimate? estimate;
  final int received;
  final int? total;

  /// Por qué falló, en palabras simples.
  final DownloadFailure? failure;

  /// Otra versión de la canción que se baja en su lugar ("Buscar otra versión"); se guarda con
  /// el id original para que la playlist la vea descargada.
  final String? sourceId;

  /// Caminos con los que YouTube cortó esta descarga: al reintentar se saltean.
  final Set<String> refusedPaths;

  /// Buscando otra versión ahora mismo.
  final bool searching;

  /// Mensaje simple para el usuario, sin detalles técnicos.
  String? get errorMessage => failure?.message;

  double? get progress => total == null || total == 0 ? null : received / total!;

  ActiveDownload copyWith({
    ActiveDownloadStatus? status,
    DownloadEstimate? Function()? estimate,
    int? received,
    int? total,
    DownloadFailure? Function()? failure,
    String? Function()? sourceId,
    Set<String>? refusedPaths,
    bool? searching,
  }) => ActiveDownload(
    track: track,
    status: status ?? this.status,
    estimate: estimate == null ? this.estimate : estimate(),
    received: received ?? this.received,
    total: total ?? this.total,
    failure: failure == null ? this.failure : failure(),
    sourceId: sourceId == null ? this.sourceId : sourceId(),
    refusedPaths: refusedPaths ?? this.refusedPaths,
    searching: searching ?? this.searching,
  );

  /// Lo que se guarda de una descarga fallida (para verla al volver a abrir Kiji).
  Map<String, dynamic> toFailedJson() => {
    'track': track.toJson(),
    if (failure != null) 'failure': failure!.toJson(),
    if (sourceId != null) 'sourceId': sourceId,
  };

  static ActiveDownload fromFailedJson(Map<String, dynamic> json) => ActiveDownload(
    track: Track.fromJson(json['track'] as Map<String, dynamic>),
    status: ActiveDownloadStatus.failed,
    failure: json['failure'] is Map ? DownloadFailure.fromJson(json['failure'] as Map<String, dynamic>) : null,
    sourceId: json['sourceId'] as String?,
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
  }) => DownloadsState(
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
  const DownloadCheck({this.estimate, this.freeBytes, this.blockedReason, this.waitingForWifi = false, this.failure});

  final DownloadEstimate? estimate;

  /// YouTube no dio el audio: por qué (la descarga de playlists la deja en la lista de fallidas).
  final DownloadFailure? failure;

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
      final failed = await _repository.failed();
      state = state.copyWith(
        active: {
          for (final e in failed.entries)
            if (!completed.containsKey(e.key)) e.key: ActiveDownload.fromFailedJson(e.value),
          ...state.active,
        },
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
      return result.contains(ConnectivityResult.wifi) || result.contains(ConnectivityResult.ethernet);
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
      return DownloadCheck(blockedReason: tx.soloSePuedenDescargarCancionesDe);
    }
    if (state.settings.wifiOnly && !await _onWifiOrEthernet()) {
      return DownloadCheck(blockedReason: tx.estasSinWifiYElegisteDescargar, waitingForWifi: true);
    }

    final DownloadEstimate estimate;
    try {
      final outcome = await _service.estimate(await _sourceFor(videoId));
      if (outcome.estimate == null) {
        debugPrint('=== DESCARGAS: $videoId no se puede bajar: ${outcome.failure!.kind.name} ===');
        return DownloadCheck(blockedReason: outcome.failure!.message, failure: outcome.failure);
      }
      estimate = outcome.estimate!;
    } catch (error) {
      debugPrint('=== DESCARGAS: falló la estimación de $videoId: $error ===');
      final failure = DownloadFailure.fromError(error);
      return DownloadCheck(blockedReason: failure.message, failure: failure);
    }

    final freeBytes = await ref.read(storageInfoProvider).freeBytes((await _repository.directory()).path);
    final size = estimate.sizeBytes;

    String? blocked;
    if (size != null && freeBytes != null && size > freeBytes) {
      blocked = tx.noHayEspacioSuficienteEnEl;
    }
    final limit = state.settings.limitBytes;
    if (size != null && limit != null && state.usedBytes + size > limit) {
      blocked = tx.superariaElLimiteDeEspacioPara;
    }
    return DownloadCheck(estimate: estimate, freeBytes: freeBytes, blockedReason: blocked);
  }

  /// Pone [track] en la cola de descargas (con la estimación ya hecha).
  void start(Track track, DownloadEstimate estimate) {
    final videoId = track.youtubeVideoId;
    if (videoId == null || state.completed.containsKey(videoId)) return;
    final previous = state.active[videoId];
    state = state.copyWith(
      active: {
        ...state.active,
        videoId: ActiveDownload(
          track: track,
          status: ActiveDownloadStatus.queued,
          estimate: estimate,
          total: estimate.sizeBytes,
          sourceId: previous?.sourceId,
        ),
      },
    );
    _pump();
  }

  /// Deja [track] en la lista de fallidas con su motivo (la descarga de playlists, cuando
  /// YouTube no dio el audio ni para empezar). Así se ve cuáles fueron y se pueden reintentar.
  void recordFailure(Track track, DownloadFailure failure) {
    final videoId = track.youtubeVideoId;
    if (videoId == null || state.completed.containsKey(videoId)) return;
    final previous = state.active[videoId];
    state = state.copyWith(
      active: {
        ...state.active,
        videoId: ActiveDownload(
          track: track,
          status: ActiveDownloadStatus.failed,
          failure: failure,
          sourceId: previous?.sourceId,
        ),
      },
    );
    _saveFailed();
  }

  /// La versión que se baja en lugar de [videoId]: la elegida con "Buscar otra versión" o la
  /// que encontró la reproducción; si no, el mismo video.
  Future<String> _sourceFor(String videoId) async {
    final chosen = state.active[videoId]?.sourceId;
    if (chosen != null) return chosen;
    try {
      final known = await AlternativeFinder.of(_service.ytClient).known(videoId);
      return known.swap ?? videoId;
    } catch (error) {
      debugPrint('=== DESCARGAS: no se pudo leer las alternativas: ${error.runtimeType} ===');
      return videoId;
    }
  }

  /// Arranca descargas en cola mientras haya lugar.
  void _pump() {
    final running = state.active.values.where((d) => d.status == ActiveDownloadStatus.downloading).length;
    if (running >= _maxParallel) return;
    final next = state.active.entries.where((e) => e.value.status == ActiveDownloadStatus.queued).firstOrNull;
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
      final source = await _sourceFor(videoId);
      final refused = {...download.refusedPaths};
      var estimate = download.estimate;
      (String, int)? result;
      // Hasta 3 caminos: si YouTube corta la descarga (403/410), esa forma se anota y se
      // prueba otra; el .part sigue si el archivo es el mismo.
      for (var attempt = 0; attempt < 3 && result == null; attempt++) {
        if (estimate == null) {
          final outcome = await _service.estimate(source, skipPaths: refused);
          if (outcome.estimate == null) {
            _fail(videoId, outcome.failure!, refusedPaths: refused);
            return;
          }
          estimate = outcome.estimate!;
        }
        try {
          result = await _download(videoId, estimate, token);
        } on ExpiredUrlException {
          debugPrint('=== DESCARGAS: YouTube cortó $videoId por ${estimate.path}; se prueba otro camino ===');
          await _service.refused(estimate);
          if (estimate.path != null) refused.add(estimate.path!);
          estimate = null;
        }
      }
      if (result == null) {
        _fail(videoId, DownloadFailure.refusedMidway, refusedPaths: refused);
        return;
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
      _saveFailed();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return; // cancel() ya limpió el estado
      debugPrint('=== DESCARGAS: falló $videoId: ${error.type.name} ===');
      _fail(videoId, DownloadFailure.network);
    } catch (error) {
      debugPrint('=== DESCARGAS: falló $videoId: ${error.runtimeType} ===');
      _fail(videoId, DownloadFailure.fromError(error));
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
      onProgress: (received, total) => _updateActive(videoId, (d) => d.copyWith(received: received, total: total)),
    );
  }

  void _fail(String videoId, DownloadFailure failure, {Set<String>? refusedPaths}) {
    // La estimación se descarta: al reintentar se pide una URL nueva.
    final current = state.active[videoId];
    if (current == null) return;
    debugPrint('=== DESCARGAS: $videoId quedó con error: ${failure.kind.name} ===');
    state = state.copyWith(
      active: {
        ...state.active,
        videoId: ActiveDownload(
          track: current.track,
          status: ActiveDownloadStatus.failed,
          received: current.received,
          total: current.total,
          failure: failure,
          sourceId: current.sourceId,
          refusedPaths: refusedPaths ?? current.refusedPaths,
        ),
      },
    );
    _saveFailed();
  }

  /// Guarda las fallidas (para verlas y reintentarlas al volver a abrir Kiji).
  void _saveFailed() {
    final failed = {
      for (final e in state.active.entries)
        if (e.value.status == ActiveDownloadStatus.failed) e.key: e.value.toFailedJson(),
    };
    unawaited(
      _repository.saveFailed(failed).catchError((Object error) {
        debugPrint('=== DESCARGAS: no se pudo guardar la lista de fallidas: ${error.runtimeType} ===');
      }),
    );
  }

  /// Reintenta una descarga fallida, sin perder lo que ya se bajó. Pide el audio otra vez
  /// a todos los motores (salteando los caminos que cortaron esta descarga).
  void retry(String videoId) {
    _updateActive(videoId, (d) => d.copyWith(status: ActiveDownloadStatus.queued, estimate: () => null));
    _saveFailed();
    _pump();
  }

  /// "Reintentar las fallidas". Devuelve cuántas se reintentaron.
  int retryAll([Iterable<String>? videoIds]) {
    final ids = [
      for (final e in state.active.entries)
        if (e.value.status == ActiveDownloadStatus.failed && (videoIds == null || videoIds.contains(e.key))) e.key,
    ];
    for (final id in ids) {
      _updateActive(id, (d) => d.copyWith(status: ActiveDownloadStatus.queued, estimate: () => null));
    }
    _saveFailed();
    _pump();
    return ids.length;
  }

  /// "Buscar otra versión": busca la misma canción en YouTube Music (la versión
  /// "Canción", con la duración más parecida) y la baja en lugar de esta. Devuelve si encontró.
  Future<bool> searchAlternative(String videoId) async {
    final download = state.active[videoId];
    if (download == null) return false;
    _updateActive(videoId, (d) => d.copyWith(searching: true));
    String? alternative;
    try {
      alternative = await AlternativeFinder.of(_service.ytClient).find(download.track);
    } catch (error) {
      debugPrint('=== DESCARGAS: falló la búsqueda de otra versión: ${error.runtimeType} ===');
    }
    _updateActive(videoId, (d) => d.copyWith(searching: false));
    if (alternative == null || alternative == videoId || alternative == download.sourceId) {
      _fail(videoId, (download.failure ?? DownloadFailure.unknown).withoutAlternative());
      return false;
    }
    debugPrint('=== DESCARGAS: $videoId se baja con otra versión ($alternative) ===');
    AlternativeFinder.of(_service.ytClient).remember(videoId, alternative);
    await _deletePartials(videoId);
    _updateActive(
      videoId,
      (d) => d.copyWith(
        status: ActiveDownloadStatus.queued,
        sourceId: () => alternative,
        estimate: () => null,
        failure: () => null,
        refusedPaths: const {},
        received: 0,
      ),
    );
    _saveFailed();
    _pump();
    return true;
  }

  /// Cancela y borra lo que se había bajado (no queda espacio ocupado a escondidas).
  Future<void> cancel(String videoId) async {
    _cancelTokens.remove(videoId)?.cancel();
    final download = state.active[videoId];
    state = state.copyWith(active: Map.of(state.active)..remove(videoId));
    if (download != null) await _deletePartials(videoId);
    _saveFailed();
    _pump();
  }

  /// Frena una descarga sin borrar lo bajado: al volver a empezarla sigue
  /// desde el `.part` (pausar la descarga de una playlist).
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

  Future<void> setLimit(int? bytes) => _saveSettings(state.settings.copyWith(limitBytes: () => bytes));

  Future<void> _saveSettings(DownloadSettings settings) async {
    state = state.copyWith(settings: settings);
    await _repository.saveSettings(settings);
  }
}

final downloadsProvider = NotifierProvider<DownloadsNotifier, DownloadsState>(DownloadsNotifier.new);
