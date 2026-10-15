import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';

/// Nombrado "PlaybackRepeatMode" (no "RepeatMode" a secas) porque Flutter
/// ya expone su propio `RepeatMode` en material.dart (usado por animaciones
/// repetitivas) — usar el mismo nombre genera un import ambiguo.
enum PlaybackRepeatMode { off, all, one }

class PlaybackState {
  const PlaybackState({
    required this.track,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.shuffleEnabled,
    required this.isInitialized,
    required this.queue,
    required this.currentIndex,
    required this.repeatMode,
  });

  final Track track;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool shuffleEnabled;
  final bool isInitialized;

  /// Lista de pistas de la cola actual (por ejemplo, toda la Biblioteca
  /// visible al momento de tocar una canción).
  final List<Track> queue;

  /// Índice de [track] dentro de [queue].
  final int currentIndex;
  final PlaybackRepeatMode repeatMode;

  factory PlaybackState.initial({Track track = Track.demo}) {
    return PlaybackState(
      track: track,
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
      shuffleEnabled: false,
      isInitialized: false,
      queue: [track],
      currentIndex: 0,
      repeatMode: PlaybackRepeatMode.off,
    );
  }

  double get progress =>
      duration.inMilliseconds == 0 ? 0 : position.inMilliseconds / duration.inMilliseconds;

  PlaybackState copyWith({
    Track? track,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? shuffleEnabled,
    bool? isInitialized,
    List<Track>? queue,
    int? currentIndex,
    PlaybackRepeatMode? repeatMode,
  }) {
    return PlaybackState(
      track: track ?? this.track,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      isInitialized: isInitialized ?? this.isInitialized,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }

  String get statusLabel => isPlaying ? 'Reproduciendo' : 'En pausa';
}

class PlaybackNotifier extends Notifier<PlaybackState> {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final _random = Random();

  @override
  PlaybackState build() {
    _player = AudioPlayer();
    ref.onDispose(_dispose);

    _listenToPlayer();

    // IMPORTANTE: no llamamos playTrack() directo acá. Dentro de build(),
    // Riverpod todavía no terminó de guardar el `state` inicial que estamos
    // a punto de retornar — si playTrack() intenta LEER `state` (lo hace
    // vía copyWith) de forma síncrona en este punto, revienta con
    // "Bad state: Tried to read the state of an uninitialized provider".
    // Un microtask lo difiere justo hasta después de que build() retorne,
    // momento en el que el estado ya existe y es seguro tocarlo.
    unawaited(Future.microtask(() => playTrack(Track.demo)));

    return PlaybackState.initial();
  }

  AudioPlayer get _audioPlayer {
    final player = _player;
    if (player == null) {
      throw StateError('AudioPlayer no disponible');
    }
    return player;
  }

  void _listenToPlayer() {
    final player = _audioPlayer;

    _subscriptions
      ..add(
        player.playerStateStream.listen((playerState) {
          state = state.copyWith(isPlaying: playerState.playing);

          if (playerState.processingState == ProcessingState.completed) {
            unawaited(_handleTrackCompleted());
          }
        }),
      )
      ..add(
        player.positionStream.listen((position) {
          state = state.copyWith(position: position);
        }),
      )
      ..add(
        player.durationStream.listen((duration) {
          if (duration != null) {
            state = state.copyWith(duration: duration);
          }
        }),
      );
  }

  Future<void> _handleTrackCompleted() async {
    if (state.repeatMode == PlaybackRepeatMode.one) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      return;
    }
    await nextTrack();
  }

  /// Carga y reproduce [track] de verdad. Usa `setFilePath` para audio
  /// local y `setUrl` para streaming remoto.
  Future<void> _loadAndPlay(Track track) async {
    try {
      state = state.copyWith(isInitialized: false);

      if (track.source == TrackSource.local) {
        await _audioPlayer.setFilePath(track.audioUrl);
      } else {
        await _audioPlayer.setUrl(track.audioUrl);
      }

      state = state.copyWith(track: track, isInitialized: true);
      await _audioPlayer.play();
    } catch (error, stackTrace) {
      debugPrint('=== ERROR AL REPRODUCIR "${track.title}" ===');
      debugPrint('$error');
      debugPrint('$stackTrace');
      state = state.copyWith(isInitialized: false);
    }
  }

  /// Reproduce una única pista suelta (por ejemplo, la demo inicial),
  /// convirtiéndola en una cola de un solo elemento.
  Future<void> playTrack(Track track) async {
    state = state.copyWith(queue: [track], currentIndex: 0);
    await _loadAndPlay(track);
  }

  /// Reproduce [tracks] como cola completa, empezando en [startIndex].
  /// Esto es lo que usa la Biblioteca al tocar una canción: toda la lista
  /// visible se vuelve la cola, para que Siguiente/Anterior tengan sentido.
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final index = startIndex.clamp(0, tracks.length - 1);
    state = state.copyWith(queue: tracks, currentIndex: index);
    await _loadAndPlay(tracks[index]);
  }

  Future<void> _playAtIndex(int index) async {
    final queue = state.queue;
    if (index < 0 || index >= queue.length) return;
    state = state.copyWith(currentIndex: index);
    await _loadAndPlay(queue[index]);
  }

  Future<void> _dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player?.dispose();
    _player = null;
  }

  Future<void> togglePlayPause() async {
    final player = _audioPlayer;
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  void toggleShuffle() {
    state = state.copyWith(shuffleEnabled: !state.shuffleEnabled);
  }

  void toggleRepeatMode() {
    final next = switch (state.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
  }

  Future<void> seekToProgress(double progress) async {
    final duration = state.duration;
    if (duration.inMilliseconds <= 0) return;

    final position = Duration(
      milliseconds: (duration.inMilliseconds * progress.clamp(0.0, 1.0)).round(),
    );
    await _audioPlayer.seek(position);
  }

  /// Va a la pista anterior de la cola. Si ya pasaron 3 segundos o más de
  /// la canción actual, reinicia la canción en vez de saltar (comportamiento
  /// estándar de la mayoría de los reproductores).
  Future<void> previousTrack() async {
    if (state.position.inSeconds >= 3 || state.queue.length <= 1) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    final previousIndex = state.currentIndex - 1;
    if (previousIndex >= 0) {
      await _playAtIndex(previousIndex);
    } else if (state.repeatMode != PlaybackRepeatMode.off) {
      await _playAtIndex(state.queue.length - 1);
    } else {
      await _audioPlayer.seek(Duration.zero);
    }
  }

  /// Avanza a la siguiente pista de la cola. Respeta Aleatorio (elige una
  /// pista al azar distinta de la actual) y Repetir (al llegar al final,
  /// vuelve al principio si Repetir está activo; si no, se detiene).
  Future<void> nextTrack() async {
    final queue = state.queue;
    if (queue.isEmpty) return;

    if (queue.length == 1) {
      if (state.repeatMode == PlaybackRepeatMode.off) {
        await _audioPlayer.pause();
        await _audioPlayer.seek(Duration.zero);
      } else {
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
      }
      return;
    }

    if (state.shuffleEnabled) {
      int candidate;
      do {
        candidate = _random.nextInt(queue.length);
      } while (candidate == state.currentIndex);
      await _playAtIndex(candidate);
      return;
    }

    final next = state.currentIndex + 1;
    if (next < queue.length) {
      await _playAtIndex(next);
      return;
    }

    // Llegamos al final de la cola.
    if (state.repeatMode == PlaybackRepeatMode.off) {
      await _audioPlayer.pause();
      await _audioPlayer.seek(Duration.zero);
    } else {
      await _playAtIndex(0);
    }
  }
}

final playbackProvider =
    NotifierProvider<PlaybackNotifier, PlaybackState>(PlaybackNotifier.new);
