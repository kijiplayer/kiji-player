import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';

/// Bytes por segundo que se suponen para estimar el tamaño antes de
/// resolver cada canción (audio de YouTube de unos 128 kbps).
const estimatedBytesPerSecond = 16000;

/// Lo que falta para bajar una playlist entera, antes de empezar.
class PlaylistDownloadPlan {
  const PlaylistDownloadPlan({
    required this.toDownload,
    required this.alreadyDownloaded,
    required this.notFromYouTube,
    required this.estimatedBytes,
  });

  final List<Track> toDownload;
  final int alreadyDownloaded;
  final int notFromYouTube;

  /// Estimado por duración (sin pedirle nada a YouTube).
  final int estimatedBytes;
}

/// Arma el plan: saltea las ya descargadas, las que no son de YouTube y las
/// repetidas.
PlaylistDownloadPlan planPlaylistDownload(List<Track> tracks, Set<String> downloaded) {
  final seen = <String>{};
  final todo = <Track>[];
  var already = 0, notYouTube = 0, bytes = 0;
  for (final track in tracks) {
    final id = track.youtubeVideoId;
    if (id == null) {
      notYouTube++;
    } else if (downloaded.contains(id)) {
      already++;
    } else if (seen.add(id)) {
      todo.add(track);
      final seconds = track.durationMs > 0 ? track.durationMs ~/ 1000 : 240;
      bytes += seconds * estimatedBytesPerSecond;
    }
  }
  return PlaylistDownloadPlan(
    toDownload: todo,
    alreadyDownloaded: already,
    notFromYouTube: notYouTube,
    estimatedBytes: bytes,
  );
}

/// Progreso de la descarga de una playlist.
@immutable
class PlaylistDownloadState {
  const PlaylistDownloadState({
    required this.total,
    this.done = 0,
    this.failed = 0,
    this.paused = false,
    this.message,
    this.receivedBytes = 0,
  });

  final int total;
  final int done;
  final int failed;
  final bool paused;

  /// Por qué se pausó sola (sin WiFi, sin espacio…), para el usuario.
  final String? message;

  /// Bytes de las que están bajando ahora (para la barra).
  final int receivedBytes;

  bool get finished => done + failed >= total;
  double get progress => total == 0 ? 1 : (done + failed) / total;

  PlaylistDownloadState copyWith({
    int? done,
    int? failed,
    bool? paused,
    String? Function()? message,
    int? receivedBytes,
  }) =>
      PlaylistDownloadState(
        total: total,
        done: done ?? this.done,
        failed: failed ?? this.failed,
        paused: paused ?? this.paused,
        message: message == null ? this.message : message(),
        receivedBytes: receivedBytes ?? this.receivedBytes,
      );
}

/// Descarga de playlists enteras como una cola (Tarea Z7): de a dos canciones,
/// salteando las ya bajadas, respetando "solo con WiFi" y el espacio. Se puede
/// pausar (sin perder lo bajado) y cancelar.
class PlaylistDownloadsNotifier extends Notifier<Map<String, PlaylistDownloadState>> {
  static const _parallel = 2;

  final _pending = <String, List<Track>>{};
  final _inFlight = <String, Set<String>>{};
  final _feeding = <String>{};

  DownloadsNotifier get _downloads => ref.read(downloadsProvider.notifier);

  @override
  Map<String, PlaylistDownloadState> build() {
    ref.listen<DownloadsState>(downloadsProvider, (_, next) => _onDownloads(next));
    return const {};
  }

  /// Empieza a bajar [plan] para la playlist [playlistId].
  void start(String playlistId, PlaylistDownloadPlan plan) {
    if (plan.toDownload.isEmpty) return;
    _pending[playlistId] = [...plan.toDownload];
    _inFlight[playlistId] = {};
    state = {...state, playlistId: PlaylistDownloadState(total: plan.toDownload.length)};
    debugPrint('=== DESCARGAS: playlist en cola (${plan.toDownload.length} canciones) ===');
    unawaited(_feed(playlistId));
  }

  /// Frena sin borrar lo bajado: lo que estaba bajando sigue desde donde quedó.
  void pause(String playlistId) {
    final current = state[playlistId];
    if (current == null) return;
    final flying = [...?_inFlight[playlistId]];
    final tracks = [
      for (final id in flying) ?ref.read(downloadsProvider).active[id]?.track,
    ];
    // Primero se sacan de "en curso", para que el listener no las cuente como canceladas.
    _inFlight[playlistId]?.clear();
    state = {...state, playlistId: current.copyWith(paused: true, receivedBytes: 0)};
    _pending[playlistId] = [...tracks, ...?_pending[playlistId]];
    for (final id in flying) {
      _downloads.pause(id);
    }
  }

  void resume(String playlistId) {
    final current = state[playlistId];
    if (current == null) return;
    state = {...state, playlistId: current.copyWith(paused: false, message: () => null)};
    unawaited(_feed(playlistId));
  }

  /// Corta todo y borra lo que estaba a medio bajar (lo terminado queda).
  Future<void> cancel(String playlistId) async {
    final flying = [...?_inFlight[playlistId]];
    _pending.remove(playlistId);
    _inFlight.remove(playlistId);
    state = Map.of(state)..remove(playlistId);
    for (final id in flying) {
      await _downloads.cancel(id);
    }
  }

  /// Saca la tarjeta de una descarga terminada.
  void dismiss(String playlistId) {
    if (state[playlistId]?.finished ?? false) state = Map.of(state)..remove(playlistId);
  }

  void _onDownloads(DownloadsState downloads) {
    var changed = false;
    final next = Map.of(state);
    for (final entry in _inFlight.entries) {
      final current = next[entry.key];
      if (current == null) continue;
      var done = current.done, failed = current.failed;
      for (final id in [...entry.value]) {
        if (downloads.completed.containsKey(id)) {
          entry.value.remove(id);
          done++;
        } else if (downloads.active[id]?.status == ActiveDownloadStatus.failed) {
          // Queda en Descargadas para reintentar a mano; la cola sigue.
          entry.value.remove(id);
          failed++;
        } else if (!downloads.active.containsKey(id)) {
          // La cancelaron desde Descargadas.
          entry.value.remove(id);
          failed++;
        }
      }
      final received = entry.value.fold(0, (sum, id) => sum + (downloads.active[id]?.received ?? 0));
      if (done != current.done || failed != current.failed || received != current.receivedBytes) {
        next[entry.key] = current.copyWith(done: done, failed: failed, receivedBytes: received);
        changed = true;
        if (done != current.done || failed != current.failed) {
          scheduleMicrotask(() => _feed(entry.key));
        }
      }
    }
    if (changed) state = next;
  }

  Future<void> _feed(String playlistId) async {
    if (!_feeding.add(playlistId)) return;
    try {
      while (true) {
        final current = state[playlistId];
        final pending = _pending[playlistId];
        final flying = _inFlight[playlistId];
        if (current == null || pending == null || flying == null || current.paused) return;
        if (pending.isEmpty || flying.length >= _parallel) return;
        final track = pending.removeAt(0);
        final id = track.youtubeVideoId!;
        if (ref.read(downloadsProvider).completed.containsKey(id)) {
          state = {...state, playlistId: current.copyWith(done: current.done + 1)};
          continue;
        }
        final check = await _downloads.check(track);
        final now = state[playlistId];
        if (now == null) return; // cancelada mientras se revisaba
        if (check.waitingForWifi || (check.blockedReason != null && check.estimate != null)) {
          // Sin WiFi (con "solo con WiFi"), sin espacio o sobre el límite: se pausa y avisa.
          pending.insert(0, track);
          state = {...state, playlistId: now.copyWith(paused: true, message: () => check.blockedReason)};
          debugPrint('=== DESCARGAS: playlist en pausa: ${check.blockedReason} ===');
          return;
        }
        if (!check.canDownload) {
          state = {...state, playlistId: now.copyWith(failed: now.failed + 1)};
          continue;
        }
        flying.add(id);
        _downloads.start(track, check.estimate!);
      }
    } finally {
      _feeding.remove(playlistId);
    }
  }
}

final playlistDownloadsProvider =
    NotifierProvider<PlaylistDownloadsNotifier, Map<String, PlaylistDownloadState>>(PlaylistDownloadsNotifier.new);
