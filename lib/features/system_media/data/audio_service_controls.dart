// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../playback/MusicService.kt y
// MediaLibrarySessionCallback.kt (sesión multimedia, notificación y botones del sistema).

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../models/track.dart';
import '../domain/system_media_controls.dart';
import 'cover_art.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Android / iOS / macOS: notificación, pantalla de bloqueo y auriculares
/// mediante `audio_service`. El reproductor sigue siendo `PlaybackNotifier`;
/// esto solo traduce en las dos direcciones.
class AudioServiceControls implements SystemMediaControls {
  AudioServiceControls._(this._handler);

  final _KijiAudioHandler _handler;
  bool _askedNotificationPermission = false;

  static Future<AudioServiceControls> init() async {
    final handler = await AudioService.init(
      builder: _KijiAudioHandler.new,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'io.github.kijiplayer.kiji.playback',
        androidNotificationChannelName: tx.reproduccion2,
        androidNotificationChannelDescription: tx.controlesDeLaMusicaQueEsta,
        // El logo de Kiji en blanco (res/drawable/ic_stat_kiji.xml); el de la app sale como un círculo.
        androidNotificationIcon: 'drawable/ic_stat_kiji',
        // En pausa, la notificación se puede descartar deslizándola.
        androidStopForegroundOnPause: true,
      ),
    );
    return AudioServiceControls._(handler);
  }

  @override
  void attach(MediaCommands commands) => _handler.commands = commands;

  @override
  Future<void> showTrack(Track track, {Duration? duration}) async {
    _handler.mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: duration ?? (track.durationMs > 0 ? Duration(milliseconds: track.durationMs) : null),
        artUri: await coverArtFor(track),
      ),
    );
  }

  @override
  void updatePlayback({
    required bool playing,
    required MediaProcessing processing,
    required Duration position,
    required Duration bufferedPosition,
  }) {
    if (playing) _askNotificationPermissionOnce();
    _handler.playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (processing) {
          MediaProcessing.idle => AudioProcessingState.idle,
          MediaProcessing.loading => AudioProcessingState.loading,
          MediaProcessing.buffering => AudioProcessingState.buffering,
          MediaProcessing.ready => AudioProcessingState.ready,
          MediaProcessing.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
      ),
    );
  }

  /// Android 13+ pide permiso para mostrar notificaciones. Se pregunta la
  /// primera vez que el usuario reproduce algo, que es cuando tiene sentido.
  /// Si lo niega, la música igual sigue en segundo plano.
  void _askNotificationPermissionOnce() {
    if (_askedNotificationPermission || defaultTargetPlatform != TargetPlatform.android) return;
    _askedNotificationPermission = true;
    Permission.notification.request().then(
      (status) => debugPrint('=== CONTROLES: permiso de notificaciones: $status ==='),
      onError: (Object error) => debugPrint('=== CONTROLES: no se pudo pedir el permiso de notificaciones: $error ==='),
    );
  }
}

class _KijiAudioHandler extends BaseAudioHandler with SeekHandler {
  MediaCommands? commands;

  Future<void> _run(Future<void> Function()? command, String name) async {
    if (command == null) {
      debugPrint('=== CONTROLES: "$name" antes de conectar el reproductor ===');
      return;
    }
    await command();
  }

  @override
  Future<void> play() => _run(commands?.play, 'play');

  @override
  Future<void> pause() => _run(commands?.pause, 'pause');

  @override
  Future<void> skipToNext() => _run(commands?.next, 'siguiente');

  @override
  Future<void> skipToPrevious() => _run(commands?.previous, 'anterior');

  @override
  Future<void> seek(Duration position) async {
    final seek = commands?.seek;
    if (seek != null) await seek(position);
  }

  @override
  Future<void> stop() => _run(commands?.stop, 'stop');
}
