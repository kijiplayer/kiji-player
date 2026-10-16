import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../features/playback_memory/data/playback_memory_store.dart';
import '../features/playback_memory/domain/playback_snapshot.dart';
import '../features/yt_music/data/ytm_client.dart';
import '../features/yt_music/domain/subtitle_parser.dart';
import '../models/track.dart';
import 'downloads_provider.dart';

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

  /// Pista actual, o null si todavía no se eligió ninguna (app recién
  /// instalada o sin guardado).
  final Track? track;
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

  factory PlaybackState.initial() {
    return const PlaybackState(
      track: null,
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
      shuffleEnabled: false,
      isInitialized: false,
      queue: [],
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

/// Avisos cortos para el usuario (sin detalles técnicos). La pantalla
/// principal los muestra como SnackBar y los limpia.
final playbackNoticeProvider = StateProvider<String?>((ref) => null);

class PlaybackNotifier extends Notifier<PlaybackState> {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final _random = Random();
  late final _memory = PlaybackMemoryStore();
  late final _ytClient = YtMusicClient();
  Timer? _saveTimer;
  AppLifecycleListener? _lifecycleListener;

  /// Se incrementa en cada carga: si el usuario elige otra canción mientras
  /// una carga anterior sigue en curso, la anterior se descarta.
  int _loadToken = 0;
  bool _wasPlaying = false;

  @override
  PlaybackState build() {
    _player = AudioPlayer();
    ref.onDispose(_dispose);

    _listenToPlayer();

    // Guardado periódico mientras suena y al pasar a segundo plano.
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (state.isPlaying) unawaited(_saveState());
    });
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (lifecycle) {
        if (lifecycle == AppLifecycleState.hidden ||
            lifecycle == AppLifecycleState.paused ||
            lifecycle == AppLifecycleState.detached) {
          unawaited(_saveState());
        }
      },
    );

    // IMPORTANTE: no tocamos `state` de forma síncrona dentro de build():
    // Riverpod todavía no guardó el estado inicial y revienta con
    // "Bad state: Tried to read the state of an uninitialized provider".
    // El microtask lo difiere hasta después de que build() retorne.
    unawaited(Future.microtask(_restoreState));

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

          // Guardar al pausar (solo en la transición, no en cada evento).
          if (_wasPlaying && !playerState.playing) unawaited(_saveState());
          _wasPlaying = playerState.playing;

          if (playerState.processingState == ProcessingState.completed) {
            unawaited(_handleTrackCompleted());
          }
        }),
      )
      ..add(
        player.positionStream.listen((_) {
          // Sin fuente cargada (p. ej. YouTube restaurado sin red), el
          // reproductor informa 0: conservamos la posición restaurada.
          // Leemos `player.position` y no el valor del evento: un evento
          // emitido durante la carga (con 0) puede llegar tarde y pisar la
          // posición restaurada.
          if (state.isInitialized) {
            state = state.copyWith(position: player.position);
          }
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

  /// Carga [track] (índice [index] de la cola) en el reproductor. Usa
  /// `setFilePath` para audio local y `setUrl` para streaming remoto. Si es
  /// de YouTube y no tiene URL (vienen así del guardado), la resuelve de
  /// nuevo con su `videoId`. Devuelve false si no se pudo cargar.
  Future<bool> _loadTrack(
    Track track,
    int index, {
    bool autoPlay = true,
    Duration initialPosition = Duration.zero,
  }) async {
    final token = ++_loadToken;
    state = state.copyWith(
      track: track,
      currentIndex: index,
      isInitialized: false,
      position: initialPosition,
      duration: Duration(milliseconds: track.durationMs),
    );

    try {
      var playable = track;
      final videoId = track.youtubeVideoId;

      // Si está descargada, suena desde el disco (funciona en modo avión).
      final downloaded =
          videoId == null ? null : await ref.read(downloadsRepositoryProvider).fileFor(videoId);
      if (token != _loadToken) return false;

      if (downloaded != null) {
        debugPrint('=== REPRODUCCION: "${track.title}" desde la descarga ===');
        await _audioPlayer.setFilePath(downloaded.path, initialPosition: initialPosition);
      } else {
        if (videoId != null && track.audioUrl.isEmpty) {
          final url = await _ytClient.getAudioStreamUrl(videoId);
          if (token != _loadToken) return false;
          if (url == null) {
            debugPrint('=== REPRODUCCION: sin URL de audio para $videoId ===');
            return false;
          }
          playable = track.copyWith(audioUrl: url);
          // Solo en memoria: al guardar, la URL se descarta (vence en horas).
          final queue = [...state.queue];
          if (index < queue.length && queue[index].id == track.id) {
            queue[index] = playable;
            state = state.copyWith(queue: queue, track: playable);
          }
        }

        if (playable.source == TrackSource.local) {
          await _audioPlayer.setFilePath(playable.audioUrl, initialPosition: initialPosition);
        } else {
          await _audioPlayer.setUrl(playable.audioUrl, initialPosition: initialPosition);
        }
      }
      if (token != _loadToken) return false;

      state = state.copyWith(isInitialized: true, position: _audioPlayer.position);
      debugPrint('=== REPRODUCCION: "${playable.title}" cargada en '
          '${_audioPlayer.position.inSeconds} s ===');
      unawaited(_saveState());
      if (autoPlay) await _audioPlayer.play();
      return true;
    } catch (error, stackTrace) {
      debugPrint('=== ERROR AL CARGAR "${track.title}" ===');
      debugPrint('$error');
      debugPrint('$stackTrace');
      if (token == _loadToken) {
        state = state.copyWith(isInitialized: false);
        // Que la UI no siga mostrando "Reproduciendo" sobre una carga fallida.
        await _audioPlayer.pause();
      }
      return false;
    }
  }

  /// Reproduce una única pista suelta, convirtiéndola en una cola de un
  /// solo elemento.
  Future<void> playTrack(Track track) async {
    state = state.copyWith(queue: [track], currentIndex: 0);
    await _loadTrack(track, 0);
  }

  /// Reproduce [tracks] como cola completa, empezando en [startIndex].
  /// Esto es lo que usa la Biblioteca al tocar una canción: toda la lista
  /// visible se vuelve la cola, para que Siguiente/Anterior tengan sentido.
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final index = startIndex.clamp(0, tracks.length - 1);
    state = state.copyWith(queue: tracks, currentIndex: index);
    await _loadTrack(tracks[index], index);
  }

  Future<void> _playAtIndex(int index) async {
    final queue = state.queue;
    if (index < 0 || index >= queue.length) return;

    // Archivo local borrado desde que se armó la cola: avisar y pasar a la
    // siguiente que exista, en vez de quedar trabado en un error.
    if (!await _isAvailable(queue[index])) {
      final missing = queue[index];
      final next = await _nextAvailableIndex(queue, index);
      if (next == null) {
        _notify('Las canciones de esta cola ya no están en el dispositivo.');
        await _audioPlayer.pause();
        return;
      }
      _notify('«${missing.title}» ya no está en el dispositivo. Pasamos a la siguiente.');
      index = next;
    }
    await _loadTrack(queue[index], index);
  }

  // ---------------------------------------------------------------------
  // Memoria de reproducción
  // ---------------------------------------------------------------------

  Future<void> _saveState() async {
    final queue = state.queue;
    if (queue.isEmpty) return;
    final position = state.isInitialized ? _audioPlayer.position : state.position;
    await _memory.save(
      PlaybackSnapshot(
        queue: queue,
        currentIndex: state.currentIndex,
        positionMs: position.inMilliseconds,
        repeatMode: state.repeatMode.name,
        shuffleEnabled: state.shuffleEnabled,
      ),
    );
  }

  /// Recupera la cola guardada y deja la canción EN PAUSA en su posición
  /// (Cero Sorpresas: nunca reproducir sola al abrir).
  Future<void> _restoreState() async {
    final snapshot = await _memory.load();
    if (snapshot == null) {
      debugPrint('=== MEMORIA: nada guardado, se arranca vacío ===');
      return;
    }
    // Si el usuario ya eligió algo mientras leíamos el disco, no lo pisamos.
    if (state.queue.isNotEmpty) return;

    // Colas guardadas antes del arreglo del artista ("Canción • Daft Punk").
    final queue = [
      for (final track in snapshot.queue)
        track.source == TrackSource.youtube
            ? track.copyWith(artist: cleanArtistText(track.artist))
            : track,
    ];
    var index = snapshot.currentIndex;
    var position = Duration(milliseconds: snapshot.positionMs);

    // Local: si el archivo ya no existe, saltar a la siguiente que exista.
    if (!await _isAvailable(queue[index])) {
      final missing = queue[index];
      final next = await _nextAvailableIndex(queue, index);
      if (next == null) {
        debugPrint('=== MEMORIA: ningún archivo de la cola existe ===');
        _notify('Las canciones de tu última cola ya no están en el dispositivo.');
        return;
      }
      _notify('«${missing.title}» ya no está en el dispositivo. Pasamos a la siguiente.');
      index = next;
      position = Duration.zero;
    }
    if (state.queue.isNotEmpty) return;

    state = state.copyWith(
      queue: queue,
      currentIndex: index,
      repeatMode: PlaybackRepeatMode.values.asNameMap()[snapshot.repeatMode] ??
          PlaybackRepeatMode.off,
      shuffleEnabled: snapshot.shuffleEnabled,
    );
    debugPrint('=== MEMORIA: restaurada "${queue[index].title}" en ${position.inSeconds} s ===');
    await _loadTrack(queue[index], index, autoPlay: false, initialPosition: position);
  }

  Future<bool> _isAvailable(Track track) async {
    if (track.source != TrackSource.local) return true;
    return File(track.audioUrl).exists();
  }

  Future<int?> _nextAvailableIndex(List<Track> queue, int from) async {
    for (var step = 1; step < queue.length; step++) {
      final candidate = (from + step) % queue.length;
      if (await _isAvailable(queue[candidate])) return candidate;
    }
    return null;
  }

  void _notify(String message) {
    ref.read(playbackNoticeProvider.notifier).state = message;
  }

  Future<void> _dispose() async {
    _saveTimer?.cancel();
    _lifecycleListener?.dispose();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player?.dispose();
    _player = null;
  }

  // ---------------------------------------------------------------------
  // Controles
  // ---------------------------------------------------------------------

  Future<void> togglePlayPause() async {
    final track = state.track;
    if (track == null) return;

    final player = _audioPlayer;
    if (player.playing) {
      await player.pause();
    } else if (!state.isInitialized) {
      // Pista restaurada que no se pudo cargar al abrir (p. ej. YouTube sin
      // red): reintentar ahora, desde la posición guardada.
      await _loadTrack(track, state.currentIndex, initialPosition: state.position);
    } else {
      await player.play();
    }
  }

  void toggleShuffle() {
    state = state.copyWith(shuffleEnabled: !state.shuffleEnabled);
    unawaited(_saveState());
  }

  void toggleRepeatMode() {
    final next = switch (state.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
    unawaited(_saveState());
  }

  Future<void> seekToProgress(double progress) async {
    final duration = state.duration;
    if (duration.inMilliseconds <= 0 || !state.isInitialized) return;

    final position = Duration(
      milliseconds: (duration.inMilliseconds * progress.clamp(0.0, 1.0)).round(),
    );
    await _audioPlayer.seek(position);
  }

  /// Va a la pista anterior de la cola. Si ya pasaron 3 segundos o más de
  /// la canción actual, reinicia la canción en vez de saltar (comportamiento
  /// estándar de la mayoría de los reproductores).
  Future<void> previousTrack() async {
    if (state.queue.isEmpty) return;
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
