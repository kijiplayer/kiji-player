import 'dart:math' as math;

import 'package:kiji_player/l10n/l10n.dart';

/// Las bandas reales del ecualizador del dispositivo.
class EqBands {
  const EqBands({required this.centers, required this.minDb, required this.maxDb});
  final List<double> centers;
  final double minDb;
  final double maxDb;
}

/// Refuerzo de bajos al máximo, en dB (en la PC; en Android se usa la misma cuenta para el margen).
const maxBassDb = 10.0;

/// Cuánto pueden subir el ecualizador y los bajos sin bajar el volumen (la música ya trae algo de
/// margen). Lo que pase de esto se compensa (ver [headroomGain]).
const safeBoostDb = 3.0;

/// Margen de seguridad: el volumen (de 0 a 1) que evita que la música sature cuando el
/// ecualizador o el refuerzo de bajos suben mucho. Ni Windows (su libavfilter no trae limitador) ni
/// el ecualizador de Android cuidan eso. Se baja solo lo que pase de [safeBoostDb] en la banda que
/// más sube (con los bajos sumados en las graves): el cambio es parejo y casi no se nota.
double headroomGain({required List<double> centers, required List<double> gains, double bass = 0}) {
  final bassDb = bass.clamp(0, 1) * maxBassDb;
  var peak = gains.isEmpty ? bassDb : 0.0;
  for (var i = 0; i < gains.length && i < centers.length; i++) {
    final boost = gains[i] + (centers[i] <= 160 ? bassDb : 0);
    if (boost > peak) peak = boost;
  }
  final cut = peak - safeBoostDb;
  return cut <= 0 ? 1 : math.pow(10, -cut / 20).toDouble();
}

/// Reverb: pocos modos claros.
enum ReverbMode {
  off,
  room,
  stadium;

  String get label => switch (this) {
    ReverbMode.off => tx.reverbApagado,
    ReverbMode.room => tx.reverbSala,
    ReverbMode.stadium => tx.reverbEstadio,
  };
}

/// Qué efectos hay en este dispositivo. Los que no hay no se muestran.
class SoundCapabilities {
  const SoundCapabilities({this.bass = false, this.reverb = false});
  final bool bass;
  final bool reverb;
}

/// Lo que tiene que sonar ahora (ya resuelto el perfil y la salida).
class SoundMix {
  const SoundMix({required this.enabled, required this.gains, this.bass = 0, this.reverb = ReverbMode.off});

  /// El interruptor "Efectos": apagado, nada se aplica.
  final bool enabled;

  /// dB por banda (las de [SoundEngine.bands]).
  final List<double> gains;

  /// Refuerzo de bajos, 0–1.
  final double bass;
  final ReverbMode reverb;
}

/// Los efectos de sonido del sistema, detrás de una interfaz: en Android, los efectos de audio
/// del sistema (ecualizador, BassBoost, PresetReverb); en la PC, filtros de mpv.
abstract class SoundEngine {
  /// Hay ecualizador en este dispositivo.
  bool get isSupported;

  /// Las bandas; en Android se completa cuando el reproductor ya cargó algo. null sin ecualizador.
  Future<EqBands?> bands();

  Future<SoundCapabilities> capabilities();

  /// La sesión de audio del reproductor (solo Android: los efectos nativos se le enganchan).
  void setAudioSession(int? id) {}

  Future<void> apply(SoundMix mix);
}
