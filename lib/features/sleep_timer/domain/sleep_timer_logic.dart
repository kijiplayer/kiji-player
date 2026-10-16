// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../playback/SleepTimer.kt (temporizador por
// minutos y "al terminar la canción").

/// Cómo termina el temporizador.
enum SleepTimerMode {
  minutes('En unos minutos'),
  endOfTrack('Al terminar esta canción'),
  endOfQueue('Al terminar la cola');

  const SleepTimerMode(this.label);
  final String label;
}

/// Lógica pura del temporizador (sin reproductor ni relojes reales).
abstract final class SleepTimerLogic {
  /// El volumen baja de a poco durante los últimos 30 segundos.
  static const fadeDuration = Duration(seconds: 30);

  /// Opciones de "en X minutos".
  static const minuteOptions = [5, 10, 15, 30, 45, 60, 90];

  /// Cuánto falta para pausar, o null si todavía no se puede saber (por
  /// ejemplo, "al terminar la cola" mientras no suena la última canción).
  static Duration? remaining({
    required SleepTimerMode mode,
    required DateTime now,
    DateTime? endsAt,
    required Duration position,
    required Duration duration,
    required bool isLastInQueue,
  }) {
    switch (mode) {
      case SleepTimerMode.minutes:
        if (endsAt == null) return null;
        final left = endsAt.difference(now);
        return left.isNegative ? Duration.zero : left;
      case SleepTimerMode.endOfTrack:
        return _trackLeft(position, duration);
      case SleepTimerMode.endOfQueue:
        return isLastInQueue ? _trackLeft(position, duration) : null;
    }
  }

  static Duration? _trackLeft(Duration position, Duration duration) {
    if (duration <= Duration.zero) return null; // todavía no se sabe cuánto dura
    final left = duration - position;
    return left.isNegative ? Duration.zero : left;
  }

  /// Factor de volumen (0..1) para [remaining]: 1 hasta los últimos 30 s, y
  /// de ahí baja en línea recta hasta 0.
  static double fadeFactor(Duration? remaining) {
    if (remaining == null || remaining >= fadeDuration) return 1;
    if (remaining <= Duration.zero) return 0;
    return remaining.inMilliseconds / fadeDuration.inMilliseconds;
  }

  /// Hay que pausar ya. Para canciones se pausa un instante antes del final,
  /// así no llega a arrancar la siguiente.
  static bool shouldStop(SleepTimerMode mode, Duration? remaining) {
    if (remaining == null) return false;
    final margin =
        mode == SleepTimerMode.minutes ? Duration.zero : const Duration(milliseconds: 400);
    return remaining <= margin;
  }

  /// "12:05" o "1:02:05" para mostrar cuánto falta.
  static String format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
