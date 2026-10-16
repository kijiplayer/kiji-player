import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../features/history/listening_history.dart';
import '../features/playback_memory/data/playback_memory_store.dart';
import '../features/playback_memory/domain/playback_snapshot.dart';
import '../features/queue/domain/queue_operations.dart';
import '../features/settings/data/settings_store.dart';
import '../features/stream_cache/data/stream_cache.dart';
import '../features/system_media/domain/system_media_controls.dart';
import '../features/yt_music/data/extractor_health.dart';
import '../features/yt_music/data/ytm_client.dart';
import '../features/yt_music/domain/subtitle_parser.dart';
import '../models/track.dart';
import 'downloads_provider.dart';
import 'system_media_provider.dart';

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
    this.volume = 1.0,
  });

  /// Volumen de Kiji, de 0 a 1 (independiente del volumen del sistema).
  final double volume;

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
    double? volume,
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
      volume: volume ?? this.volume,
    );
  }

  String get statusLabel => isPlaying ? 'Reproduciendo' : 'En pausa';
}

/// Avisos cortos para el usuario (sin detalles técnicos). La pantalla
/// principal los muestra como SnackBar y los limpia.
final playbackNoticeProvider = StateProvider<PlaybackNotice?>((ref) => null);

enum NoticeAction { openDownloads }

/// Aviso corto para el usuario, con una acción opcional.
class PlaybackNotice {
  const PlaybackNotice(this.message, {this.action});

  final String message;
  final NoticeAction? action;
}

/// Formas de abrir una URL de YouTube, de la preferida a la de respaldo.
enum _SourceMode { cached, withHeaders, plain }

/// Cómo terminó un intento de cargar una canción.
enum LoadResult { loaded, cancelled, offline, unplayable }

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

  /// Notificación, pantalla de bloqueo y auriculares (Tarea C).
  late SystemMediaControls _controls;

  /// La notificación aparece recién cuando el usuario reproduce algo en esta
  /// sesión: abrir la app con una canción restaurada en pausa no muestra nada
  /// (Cero Sorpresas).
  bool _shownInSystem = false;

  /// Caché de lo escuchado (Tarea D).
  late final _cache = StreamCache();

  /// Cliente de YouTube de la canción que suena (para reintentar con otro).
  String? _currentClient;
  Duration _lastPlayedPosition = Duration.zero;
  bool _recovering = false;
  int _consecutiveFailures = 0;

  /// Canciones pedidas con "Reproducir a continuación" que todavía no
  /// sonaron. Ganan sobre el aleatorio.
  final Set<String> _requestedNext = {};

  @override
  PlaybackState build() {
    _player = AudioPlayer();
    ref.onDispose(_dispose);

    _controls = ref.read(systemMediaControlsProvider)
      ..attach(MediaCommands(
        play: play,
        pause: pause,
        next: nextTrack,
        previous: previousTrack,
        seek: seekTo,
        stop: pause,
      ));

    _listenToPlayer();
    unawaited(ExtractorHealth.instance.load());

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
          _pushSystemState();
        }),
      )
      ..add(player.playbackEventStream.listen(
        (_) => _pushSystemState(),
        onError: (Object error) => unawaited(_onPlaybackError(error)),
      ))
      // just_audio 0.10 informa los errores de reproducción por acá (no
      // como error de playbackEventStream).
      ..add(player.errorStream.listen((error) => unawaited(_onPlaybackError(error))))
      ..add(
        player.positionStream.listen((_) {
          // Sin fuente cargada (p. ej. YouTube restaurado sin red), el
          // reproductor informa 0: conservamos la posición restaurada.
          // Leemos `player.position` y no el valor del evento: un evento
          // emitido durante la carga (con 0) puede llegar tarde y pisar la
          // posición restaurada.
          if (state.isInitialized) {
            state = state.copyWith(position: player.position);
            // Última posición real mientras suena: al "terminar", just_audio
            // informa la duración completa aunque el audio se haya cortado.
            if (player.processingState != ProcessingState.completed) {
              _lastPlayedPosition = player.position;
            }
          }
        }),
      )
      ..add(
        player.durationStream.listen((duration) {
          if (duration != null) {
            state = state.copyWith(duration: duration);
            final track = state.track;
            if (_shownInSystem && track != null) {
              unawaited(_controls.showTrack(track, duration: duration));
            }
          }
        }),
      );
  }

  /// Informa al sistema (notificación, pantalla de bloqueo) qué está pasando.
  void _pushSystemState() {
    final player = _player;
    final track = state.track;
    if (player == null || track == null) return;
    if (!_shownInSystem) {
      if (!player.playing) return;
      _shownInSystem = true;
      unawaited(_controls.showTrack(track, duration: player.duration));
    }
    _controls.updatePlayback(
      playing: player.playing,
      processing: switch (player.processingState) {
        ProcessingState.idle => MediaProcessing.idle,
        ProcessingState.loading => MediaProcessing.loading,
        ProcessingState.buffering => MediaProcessing.buffering,
        ProcessingState.ready => MediaProcessing.ready,
        ProcessingState.completed => MediaProcessing.completed,
      },
      position: player.position,
      bufferedPosition: player.bufferedPosition,
    );
  }

  Future<void> _handleTrackCompleted() async {
    // Si se corta la red, el proxy de la caché entrega el audio incompleto y
    // el reproductor lo da por terminado. Si "terminó" lejos del final real,
    // es un corte: lo maneja el Modo de Gracia (y no se pierde la posición).
    final duration = state.duration;
    final position = _lastPlayedPosition;
    if (_currentClient != null &&
        ((duration > Duration.zero && position < duration - const Duration(seconds: 5)) ||
            !await _isOnline())) {
      await _onPlaybackError('terminó antes de tiempo en ${position.inSeconds} s '
          'de ${duration.inSeconds} s',
          at: position);
      return;
    }

    if (state.repeatMode == PlaybackRepeatMode.one) {
      await _audioPlayer.seek(Duration.zero);
      _startPlaying();
      return;
    }
    await nextTrack();
  }

  /// Carga [track] (índice [index] de la cola) en el reproductor, en este
  /// orden: archivo local → descarga → caché de lo escuchado → streaming de
  /// YouTube (con reintento por cliente). No decide qué hacer si falla: eso
  /// lo hace [_loadOrRecover] con el Modo de Gracia.
  Future<LoadResult> _loadTrack(
    Track track,
    int index, {
    bool autoPlay = true,
    Duration initialPosition = Duration.zero,
    Set<String> skipClients = const {},
  }) async {
    final token = ++_loadToken;
    _requestedNext.remove(track.id);
    _currentClient = null;
    _lastPlayedPosition = initialPosition;
    state = state.copyWith(
      track: track,
      currentIndex: index,
      isInitialized: false,
      position: initialPosition,
      duration: Duration(milliseconds: track.durationMs),
    );
    if (_shownInSystem) unawaited(_controls.showTrack(track));

    try {
      final result = await _setSource(track, initialPosition, token, skipClients);
      if (token != _loadToken) return LoadResult.cancelled;
      if (result != LoadResult.loaded) {
        state = state.copyWith(isInitialized: false, position: initialPosition);
        // Que la UI no siga mostrando "Reproduciendo" sobre una carga fallida.
        await _audioPlayer.pause();
        return result;
      }

      _consecutiveFailures = 0;
      state = state.copyWith(isInitialized: true, position: _audioPlayer.position);
      debugPrint('=== REPRODUCCION: "${track.title}" cargada en '
          '${_audioPlayer.position.inSeconds} s ===');
      unawaited(_saveState());
      if (autoPlay) {
        _startPlaying();
        // Historial local (Inicio: "Escuchado recientemente", "Para vos").
        // Restaurar al abrir (autoPlay: false) no cuenta como escuchar.
        ref.read(listeningHistoryProvider.notifier).record(track);
      }
      return LoadResult.loaded;
    } catch (error, stackTrace) {
      if (token != _loadToken) return LoadResult.cancelled;
      debugPrint('=== ERROR AL CARGAR "${track.title}" ===');
      debugPrint('$error');
      debugPrint('$stackTrace');
      state = state.copyWith(isInitialized: false);
      await _audioPlayer.pause();
      return await _isOnline() ? LoadResult.unplayable : LoadResult.offline;
    }
  }

  Future<LoadResult> _setSource(
    Track track,
    Duration initialPosition,
    int token,
    Set<String> skipClients,
  ) async {
    final videoId = track.youtubeVideoId;
    if (videoId == null) {
      await _audioPlayer.setFilePath(track.audioUrl, initialPosition: initialPosition);
      return LoadResult.loaded;
    }

    // Descargada: suena desde el disco (funciona en modo avión).
    final downloaded = await ref.read(downloadsRepositoryProvider).fileFor(videoId);
    if (token != _loadToken) return LoadResult.cancelled;
    if (downloaded != null) {
      debugPrint('=== REPRODUCCION: "${track.title}" desde la descarga ===');
      await _audioPlayer.setFilePath(downloaded.path, initialPosition: initialPosition);
      return LoadResult.loaded;
    }

    // Ya sonó entera antes: está en la caché, no se vuelve a bajar.
    final cached = await _cache.completeFile(videoId);
    if (token != _loadToken) return LoadResult.cancelled;
    if (cached != null) {
      debugPrint('=== REPRODUCCION: "${track.title}" desde la caché ===');
      unawaited(_cache.touch(cached));
      await _audioPlayer.setFilePath(cached.path, initialPosition: initialPosition);
      return LoadResult.loaded;
    }

    // Sin red no tiene sentido probar los clientes (cada uno espera su
    // tiempo de conexión): el Modo de Gracia responde en el acto.
    if (!await _isOnline()) return LoadResult.offline;

    final tried = {...skipClients};
    while (true) {
      final stream = await _ytClient.resolveStream(videoId, skipClients: tried);
      if (token != _loadToken) return LoadResult.cancelled;
      if (stream == null) {
        final offline = _ytClient.lastResolveWasOffline || !await _isOnline();
        debugPrint('=== REPRODUCCION: sin audio para $videoId '
            '(${offline ? "sin conexión" : "clientes agotados"}) ===');
        return offline ? LoadResult.offline : LoadResult.unplayable;
      }

      // Primero con caché; si la caché falla, la misma URL sin caché; y por
      // último sin headers (sin el proxy interno de just_audio).
      for (final mode in _SourceMode.values) {
        try {
          final source = switch (mode) {
            _SourceMode.cached => await _cache.sourceFor(videoId, stream),
            _SourceMode.withHeaders =>
              AudioSource.uri(Uri.parse(stream.url), headers: {'User-Agent': stream.userAgent}),
            _SourceMode.plain => AudioSource.uri(Uri.parse(stream.url)),
          };
          if (source == null) continue; // ya se está guardando: probar sin caché
          await _audioPlayer.setAudioSource(source, initialPosition: initialPosition);
          if (token != _loadToken) return LoadResult.cancelled;
          _currentClient = stream.client;
          if (mode != _SourceMode.cached) {
            debugPrint('=== REPRODUCCION: "${track.title}" sin caché (${mode.name}) ===');
          }
          unawaited(_cache.evict(
            limitBytes: ref.read(settingsProvider).streamCacheLimitBytes,
            keepVideoId: videoId,
          ));
          return LoadResult.loaded;
        } on PlayerInterruptedException {
          return LoadResult.cancelled;
        } on PlayerException catch (error) {
          debugPrint('=== REPRODUCCION: [${stream.client}] modo ${mode.name} '
              'falló: ${error.code} ${error.message} ===');
        }
      }
      ExtractorHealth.instance.recordFailure(stream.client, 'El audio no se pudo abrir');
      tried.add(stream.client);
    }
  }

  /// Olvida la cola guardada (al apagar "Recordar la cola al cerrar").
  Future<void> forgetSavedQueue() => _memory.clear();

  /// Vacía la caché de lo escuchado (Configuración → Almacenamiento).
  Future<void> clearStreamCache() => _cache.clear();

  /// Arranca la música sin esperar: en just_audio, play() termina recién
  /// cuando la música se pausa, y quien llamó (la búsqueda, el botón de la
  /// notificación) quedaría "cargando" todo ese tiempo.
  void _startPlaying() {
    unawaited(_audioPlayer.play().catchError(
          (Object error) => debugPrint('=== REPRODUCCION: play() falló: $error ==='),
        ));
  }

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.every((r) => r == ConnectivityResult.none);
    } catch (error) {
      debugPrint('=== REPRODUCCION: no se pudo saber si hay conexión: $error ===');
      return true;
    }
  }

  /// Puede sonar sin internet: local que existe, descargada o en caché completa.
  Future<bool> _isAvailableOffline(Track track) async {
    final videoId = track.youtubeVideoId;
    if (videoId == null) return _isAvailable(track);
    return await ref.read(downloadsRepositoryProvider).fileFor(videoId) != null ||
        await _cache.completeFile(videoId) != null;
  }

  /// Carga y, si falla, aplica el Modo de Gracia.
  Future<void> _loadOrRecover(
    Track track,
    int index, {
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    final result = await _loadTrack(
      track,
      index,
      initialPosition: initialPosition,
      autoPlay: autoPlay,
    );
    if (result == LoadResult.offline || result == LoadResult.unplayable) {
      await _grace(track, index, result, initialPosition);
    }
  }

  /// Modo de Gracia (Tarea D): la música no se traba ni muestra errores
  /// técnicos. Sin conexión, sigue con lo que está guardado en el teléfono; si
  /// YouTube no deja reproducir una canción, pasa a la siguiente.
  Future<void> _grace(Track track, int index, LoadResult result, Duration position) async {
    final queue = state.queue;

    if (result == LoadResult.offline) {
      for (var step = 1; step < queue.length; step++) {
        final candidate = (index + step) % queue.length;
        if (await _isAvailableOffline(queue[candidate])) {
          _notify(PlaybackNotice(
            'Sin conexión. Seguimos con «${queue[candidate].title}», '
            'que está guardada en el teléfono.',
          ));
          await _loadOrRecover(queue[candidate], candidate);
          return;
        }
      }
      // Nada para escuchar sin red: queda en pausa en el mismo punto, y al
      // tocar play se reintenta desde ahí.
      await _audioPlayer.pause();
      state = state.copyWith(
        track: track,
        currentIndex: index,
        position: position,
        isInitialized: false,
      );
      _notify(const PlaybackNotice(
        'Sin conexión: la música quedó en pausa. Cuando vuelva internet, tocá play.',
        action: NoticeAction.openDownloads,
      ));
      return;
    }

    _consecutiveFailures++;
    final next = index + 1 < queue.length
        ? index + 1
        : (state.repeatMode == PlaybackRepeatMode.off ? null : 0);
    if (next == null || next == index || _consecutiveFailures >= 3) {
      _consecutiveFailures = 0;
      await _audioPlayer.pause();
      state = state.copyWith(position: position, isInitialized: false);
      _notify(const PlaybackNotice(
        'YouTube no está dejando reproducir ahora. Probá en un rato o escuchá tu música guardada.',
        action: NoticeAction.openDownloads,
      ));
      return;
    }
    _notify(PlaybackNotice('No se pudo reproducir «${track.title}». Pasamos a la siguiente.'));
    await _loadOrRecover(queue[next], next);
  }

  /// Error a mitad de canción (se cortó la red, la URL venció...).
  Future<void> _onPlaybackError(Object error, {Duration? at}) async {
    final track = state.track;
    // Durante una carga los errores los maneja el propio _setSource (prueba
    // otro modo u otro cliente); acá solo llegan los de una canción que ya
    // estaba sonando.
    if (track == null || _recovering || !state.isInitialized) {
      debugPrint('=== REPRODUCCION: error durante la carga (lo maneja la carga): $error ===');
      return;
    }
    _recovering = true;
    try {
      final position = at ?? _lastPlayedPosition;
      final index = state.currentIndex;
      debugPrint('=== REPRODUCCION: error a mitad de "${track.title}" en '
          '${position.inSeconds} s: $error ===');

      final client = _currentClient;
      if (client != null && await _isOnline()) {
        // Reintentar con el siguiente cliente.
        ExtractorHealth.instance.recordFailure(client, 'Se cortó durante la reproducción');
        final result = await _loadTrack(
          track,
          index,
          initialPosition: position,
          skipClients: {client},
        );
        if (result == LoadResult.loaded || result == LoadResult.cancelled) return;
        await _grace(track, index, result, position);
        return;
      }
      final online = await _isOnline();
      await _grace(track, index, online ? LoadResult.unplayable : LoadResult.offline, position);
    } finally {
      _recovering = false;
    }
  }

  /// Reproduce una única pista suelta, convirtiéndola en una cola de un
  /// solo elemento.
  Future<void> playTrack(Track track) async {
    _requestedNext.clear();
    state = state.copyWith(queue: [track], currentIndex: 0);
    await _loadOrRecover(track, 0);
  }

  /// Reproduce [tracks] como cola completa, empezando en [startIndex].
  /// Esto es lo que usa la Biblioteca al tocar una canción: toda la lista
  /// visible se vuelve la cola, para que Siguiente/Anterior tengan sentido.
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final index = startIndex.clamp(0, tracks.length - 1);
    _requestedNext.clear();
    state = state.copyWith(queue: tracks, currentIndex: index);
    await _loadOrRecover(tracks[index], index);
  }

  // ---------------------------------------------------------------------
  // Cola (Tarea E)
  // ---------------------------------------------------------------------

  QueueSnapshot get _queueSnapshot => QueueSnapshot(state.queue, state.currentIndex);

  void _applyQueue(QueueSnapshot queue) {
    state = state.copyWith(queue: queue.tracks, currentIndex: queue.currentIndex);
    unawaited(_saveState());
  }

  /// Reordena la cola (índices finales, ya ajustados).
  void moveInQueue(int from, int to) => _applyQueue(_queueSnapshot.move(from, to));

  /// Salta a la canción [index] de la cola.
  Future<void> playFromQueue(int index) => _playAtIndex(index);

  /// Quita la canción [index]. Devuelve lo necesario para deshacerlo.
  Future<RemovedFromQueue?> removeFromQueue(int index) async {
    if (index < 0 || index >= state.queue.length) return null;
    final removed = RemovedFromQueue(
      track: state.queue[index],
      index: index,
      wasCurrent: index == state.currentIndex,
      position: _audioPlayer.position,
      wasPlaying: _audioPlayer.playing,
    );
    final queue = _queueSnapshot.remove(index);

    if (queue.tracks.isEmpty) {
      // Cola vacía: se detiene y se olvida el guardado (si no, al reabrir
      // volvería la cola que el usuario acaba de vaciar).
      ++_loadToken;
      await _audioPlayer.stop();
      state = PlaybackState(
        track: null,
        isPlaying: false,
        position: Duration.zero,
        duration: Duration.zero,
        shuffleEnabled: state.shuffleEnabled,
        isInitialized: false,
        queue: const [],
        currentIndex: 0,
        repeatMode: state.repeatMode,
      );
      await _memory.clear();
      return removed;
    }

    _applyQueue(queue);
    if (removed.wasCurrent) {
      await _loadOrRecover(queue.current!, queue.currentIndex, autoPlay: removed.wasPlaying);
    }
    return removed;
  }

  /// Deshace [removeFromQueue]: la canción vuelve a su lugar y, si era la que
  /// sonaba, vuelve al mismo segundo.
  Future<void> undoRemove(RemovedFromQueue removed) async {
    if (state.queue.isEmpty) {
      state = state.copyWith(queue: [removed.track], currentIndex: 0);
      await _loadOrRecover(
        removed.track,
        0,
        initialPosition: removed.position,
        autoPlay: removed.wasPlaying,
      );
      return;
    }
    final queue = _queueSnapshot.insert(removed.index, removed.track, wasCurrent: removed.wasCurrent);
    _applyQueue(queue);
    if (removed.wasCurrent) {
      await _loadOrRecover(
        removed.track,
        queue.currentIndex,
        initialPosition: removed.position,
        autoPlay: removed.wasPlaying,
      );
    }
  }

  /// "Reproducir a continuación". Si no suena nada, la reproduce ya.
  Future<void> playNext(Track track) async {
    if (state.track == null) return playTrack(track);
    _applyQueue(_queueSnapshot.playNext(track));
    _requestedNext.add(track.id);
  }

  /// "Agregar a la cola" (al final). Si no suena nada, la reproduce ya.
  Future<void> addToQueue(Track track) async {
    if (state.track == null) return playTrack(track);
    _applyQueue(_queueSnapshot.addToEnd(track));
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
        _notify(PlaybackNotice('Las canciones de esta cola ya no están en el dispositivo.'));
        await _audioPlayer.pause();
        return;
      }
      _notify(PlaybackNotice('«${missing.title}» ya no está en el dispositivo. Pasamos a la siguiente.'));
      index = next;
    }
    await _loadOrRecover(queue[index], index);
  }

  // ---------------------------------------------------------------------
  // Memoria de reproducción
  // ---------------------------------------------------------------------

  Future<void> _saveState() async {
    final queue = state.queue;
    if (queue.isEmpty || !ref.read(settingsProvider).rememberQueue) return;
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
    // Configuración → "Recordar la cola al cerrar" (Tarea A, punto 5).
    final settings = await ref.read(settingsProvider.notifier).loaded;
    if (!settings.rememberQueue) {
      debugPrint('=== MEMORIA: "recordar la cola" está apagado, se arranca vacío ===');
      return;
    }
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
        _notify(PlaybackNotice('Las canciones de tu última cola ya no están en el dispositivo.'));
        return;
      }
      _notify(PlaybackNotice('«${missing.title}» ya no está en el dispositivo. Pasamos a la siguiente.'));
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

  void _notify(PlaybackNotice notice) {
    ref.read(playbackNoticeProvider.notifier).state = notice;
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
    if (_audioPlayer.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    final track = state.track;
    if (track == null) return;
    if (!state.isInitialized) {
      // Pista restaurada que no se pudo cargar al abrir (p. ej. YouTube sin
      // red): reintentar ahora, desde la posición guardada.
      await _loadOrRecover(track, state.currentIndex, initialPosition: state.position);
    } else {
      _startPlaying();
    }
  }

  Future<void> pause() => _audioPlayer.pause();

  Future<void> seekTo(Duration position) async {
    if (!state.isInitialized) return;
    await _audioPlayer.seek(position);
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

  /// Adelanta (o retrocede, si [offset] es negativo) dentro de la canción.
  Future<void> seekBy(Duration offset) async {
    if (!state.isInitialized) return;
    final target = _audioPlayer.position + offset;
    final duration = state.duration;
    await seekTo(target < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && target > duration ? duration : target));
  }

  /// Sube o baja el volumen de Kiji ([delta] entre -1 y 1).
  Future<void> changeVolume(double delta) async {
    final volume = (state.volume + delta).clamp(0.0, 1.0);
    state = state.copyWith(volume: volume);
    await _audioPlayer.setVolume(volume);
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
        _startPlaying();
      }
      return;
    }

    // "Reproducir a continuación" siempre se respeta, aun con aleatorio
    // (decisión del proyecto, igual que en Echo).
    final requested = _queueSnapshot.nextRequestedIndex(_requestedNext);
    if (requested != null) {
      await _playAtIndex(requested);
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

/// Lo que hace falta para deshacer "quitar de la cola".
class RemovedFromQueue {
  const RemovedFromQueue({
    required this.track,
    required this.index,
    required this.wasCurrent,
    required this.position,
    required this.wasPlaying,
  });

  final Track track;
  final int index;
  final bool wasCurrent;
  final Duration position;
  final bool wasPlaying;
}

final playbackProvider =
    NotifierProvider<PlaybackNotifier, PlaybackState>(PlaybackNotifier.new);
