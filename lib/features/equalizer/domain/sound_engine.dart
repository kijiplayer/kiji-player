import 'package:kiji_player/l10n/l10n.dart';

/// Las bandas reales del ecualizador del dispositivo.
class EqBands {
  const EqBands({required this.centers, required this.minDb, required this.maxDb});
  final List<double> centers;
  final double minDb;
  final double maxDb;
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
