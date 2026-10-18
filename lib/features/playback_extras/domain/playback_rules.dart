// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: playback/crossfade/EqualPowerCurve.kt (curva de potencia
// constante) y app/.../playback/MusicService.kt (`onDeviceVolumeChanged` con
// PauseOnMute y `audioDeviceCallback` con ResumeOnBluetoothConnect). Código propio.

import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../models/track.dart';

/// Volumen (0 a 1) de la transición suave en [position]: baja los últimos
/// [seconds] de la canción y, si [fadeIn], sube los primeros. Usa la curva de
/// potencia constante (seno/coseno), que no deja un "pozo" en el medio.
/// En canciones cortas, la transición dura como mucho un cuarto de la canción.
double transitionGain({
  required Duration position,
  required Duration duration,
  required int seconds,
  bool fadeIn = false,
}) {
  if (seconds <= 0 || duration <= Duration.zero) return 1;
  final length = math.min(seconds * 1000, duration.inMilliseconds ~/ 4);
  if (length <= 0) return 1;
  var gain = 1.0;
  final remaining = duration.inMilliseconds - position.inMilliseconds;
  if (remaining < length) {
    gain = math.sin((remaining.clamp(0, length) / length) * math.pi / 2);
  }
  if (fadeIn && position.inMilliseconds < length) {
    gain = math.min(gain, math.sin((position.inMilliseconds.clamp(0, length) / length) * math.pi / 2));
  }
  return gain;
}

/// "Pausar al silenciar": pausa si el volumen llega a cero mientras suena y
/// sigue al subirlo, solo si la pausa la causó el silencio.
class MuteRule {
  bool _pausedByMute = false;
  bool get pausedByMute => _pausedByMute;

  /// Qué hacer con un nuevo volumen del sistema (0 a 1).
  MuteAction onVolume(double volume, {required bool isPlaying}) {
    if (volume <= 0) {
      if (isPlaying) {
        _pausedByMute = true;
        return MuteAction.pause;
      }
      return MuteAction.none;
    }
    if (_pausedByMute) {
      _pausedByMute = false;
      if (!isPlaying) return MuteAction.resume;
    }
    return MuteAction.none;
  }

  /// La persona tocó play o pausa: manda ella.
  void userTookControl() => _pausedByMute = false;
}

enum MuteAction { none, pause, resume }

/// "Retomar al conectar el Bluetooth" (decisión del proyecto, Tarea K2): como en
/// Echo, **siempre** que se conectan auriculares o un parlante Bluetooth y hay
/// una canción en pausa, sigue sonando. Se apaga en Configuración.
class BluetoothResumeRule {
  /// true si hay que seguir sonando.
  bool onConnected({required bool isPlaying, required bool hasTrack}) => hasTrack && !isPlaying;
}

/// Texto para compartir una canción. Las de YouTube llevan un enlace de
/// song.link (Odesli), que abre la canción en la app de música de quien lo
/// recibe (Spotify, Apple Music, YouTube Music…). Kiji no consulta a Odesli:
/// solo arma el enlace.
String shareTextFor(Track track) {
  final title = track.artist.trim().isEmpty ? track.title : '${track.title} — ${track.artist}';
  final videoId = track.youtubeVideoId;
  return videoId == null ? title : '$title\nhttps://song.link/y/$videoId';
}

/// "Ahorro de datos": calidad baja si está activo y no hay WiFi ni cable.
bool useLowQuality({required bool dataSaver, required List<ConnectivityResult> connection}) {
  if (!dataSaver) return false;
  const unmetered = {ConnectivityResult.wifi, ConnectivityResult.ethernet};
  return !connection.any(unmetered.contains);
}
