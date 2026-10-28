import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../models/track.dart';
import '../domain/system_media_controls.dart';
import 'cover_art.dart';

/// Windows: controles multimedia del sistema (SMTC). Son los de la ventanita de volumen, la
/// pantalla de bloqueo, las teclas multimedia del teclado y los auriculares Bluetooth, aunque
/// Kiji esté en la bandeja. La parte nativa está en `windows/runner/media_controls.cpp`.
class WindowsMediaControls implements SystemMediaControls {
  WindowsMediaControls._() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('kiji/media_controls');

  MediaCommands? _commands;
  Duration _duration = Duration.zero;
  bool? _lastPlaying;
  Duration _lastPosition = Duration.zero;
  DateTime _lastSent = DateTime(0);

  static Future<SystemMediaControls?> init() async {
    final controls = WindowsMediaControls._();
    final ok = await _channel.invokeMethod<bool>('enable', true);
    if (ok != true) {
      debugPrint('=== CONTROLES: Windows no ofrece controles multimedia ===');
      _channel.setMethodCallHandler(null);
      return null;
    }
    return controls;
  }

  Future<void> _onCall(MethodCall call) async {
    final commands = _commands;
    if (commands == null) return;
    switch (call.method) {
      case 'button':
        debugPrint('=== CONTROLES: botón de Windows: ${call.arguments} ===');
        await switch (call.arguments) {
          'play' => commands.play(),
          'pause' => commands.pause(),
          'next' => commands.next(),
          'previous' => commands.previous(),
          'stop' => commands.stop(),
          _ => Future<void>.value(),
        };
      case 'seek':
        await commands.seek(Duration(milliseconds: call.arguments as int));
    }
  }

  @override
  void attach(MediaCommands commands) => _commands = commands;

  @override
  Future<void> showTrack(Track track, {Duration? duration}) async {
    _duration = duration ?? Duration(milliseconds: track.durationMs);
    _lastPlaying = null;
    final art = await coverArtFor(track);
    try {
      await _channel.invokeMethod('track', {
        'title': track.title,
        'artist': track.artist,
        'album': track.album ?? '',
        'art': art == null ? '' : (art.isScheme('file') ? art.toFilePath() : art.toString()),
      });
    } catch (error) {
      debugPrint('=== CONTROLES: no se pudo mostrar la canción en Windows: $error ===');
    }
  }

  @override
  void updatePlayback({
    required bool playing,
    required MediaProcessing processing,
    required Duration position,
    required Duration bufferedPosition,
  }) {
    // Se avisa al cambiar play/pausa, al saltar a otro punto o cada 5 s: Windows calcula el resto.
    final now = DateTime.now();
    final expected = _lastPosition + (_lastPlaying == true ? now.difference(_lastSent) : Duration.zero);
    final jumped = (position - expected).abs() > const Duration(seconds: 2);
    if (playing == _lastPlaying && !jumped && now.difference(_lastSent) < const Duration(seconds: 5)) return;
    _lastPlaying = playing;
    _lastPosition = position;
    _lastSent = now;
    _channel.invokeMethod('playback', {
      'playing': playing,
      'position': position.inMilliseconds,
      'duration': _duration.inMilliseconds,
    }).catchError((Object error) {
      debugPrint('=== CONTROLES: no se pudo avisar a Windows: $error ===');
      return null;
    });
  }
}
