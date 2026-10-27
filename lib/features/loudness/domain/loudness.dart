import 'dart:math';
import 'dart:typed_data';

/// Volumen de una canción a lo largo del tiempo, sacado del archivo (nunca del micrófono): un
/// valor cada [stepMs] ms, de 0 a 255 (de −60 dB a 0 dB de pico). Lo usa la onda del reproductor
/// en el modo alto rendimiento.
class Loudness {
  Loudness(this.levels, {this.stepMs = defaultStepMs}) : _normalized = _normalize(levels);

  static const defaultStepMs = 40;

  final Uint8List levels;
  final int stepMs;
  final Float32List _normalized;

  /// Volumen (0..1) en [time], relativo a la propia canción: 0 en sus partes suaves y 1 en las
  /// más fuertes. Interpola entre valores y sostiene un poco los golpes (sube rápido, baja en
  /// ~120 ms), para que se vea fluido a 120 Hz.
  double at(Duration time) {
    if (_normalized.isEmpty) return 0;
    final position = time.inMicroseconds / 1000 / stepMs;
    var level = 0.0;
    for (var k = 0; k < 4; k++) {
      level = max(level, _sample(position - k) * (1 - 0.22 * k));
    }
    return level;
  }

  double _sample(double position) {
    if (position < 0 || position > _normalized.length - 1) return 0;
    final i = position.floor();
    final next = min(i + 1, _normalized.length - 1);
    final t = position - i;
    return _normalized[i] * (1 - t) + _normalized[next] * t;
  }

  /// Entre el percentil 10 y el 98 de la canción, con curva para que se noten los golpes.
  static Float32List _normalize(Uint8List levels) {
    final out = Float32List(levels.length);
    if (levels.isEmpty) return out;
    final sorted = Uint8List.fromList(levels)..sort();
    final low = sorted[(sorted.length * 0.10).floor()];
    final high = sorted[min(sorted.length - 1, (sorted.length * 0.98).floor())];
    final range = max(1, high - low);
    for (var i = 0; i < levels.length; i++) {
      final v = ((levels[i] - low) / range).clamp(0.0, 1.0);
      out[i] = pow(v, 1.6).toDouble();
    }
    return out;
  }
}

/// Envolvente de [samples] (PCM de 16 bits, mono): RMS cada [stepMs] ms pasado a 0..255
/// (de −60 dBFS a 0 dBFS).
Uint8List envelopeFromPcm16(Int16List samples, int sampleRate, {int stepMs = Loudness.defaultStepMs}) {
  final window = max(1, sampleRate * stepMs ~/ 1000);
  final count = samples.length ~/ window;
  final out = Uint8List(count);
  for (var w = 0; w < count; w++) {
    var sum = 0.0;
    final start = w * window;
    for (var i = start; i < start + window; i++) {
      final s = samples[i] / 32768;
      sum += s * s;
    }
    out[w] = levelByte(sqrt(sum / window));
  }
  return out;
}

/// RMS (0..1) a 0..255, de −60 dBFS a 0 dBFS.
int levelByte(double rms) {
  if (rms <= 0) return 0;
  final db = 20 * log(rms) / ln10;
  return (((db + 60) / 60).clamp(0.0, 1.0) * 255).round();
}

/// Altura (0..1) de la barra [index] en vivo: cerca de la posición ([playhead], en barras) salta
/// con el volumen; lejos queda como siempre ([base]). Con volumen bajo casi no se mueve.
double liveBarHeight({required double base, required int index, required double playhead, required double level}) {
  final d = (index - playhead) / 5;
  final weight = exp(-d * d);
  return (base * (1 - 0.45 * weight) + weight * (0.18 + 0.82 * level)).clamp(0.08, 1.0);
}
