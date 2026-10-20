import 'package:kiji_player/l10n/l10n.dart';

// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../playback/SleepTimer.kt (temporizador por
// minutos y "al terminar la canción").

/// Cómo termina el temporizador.
enum SleepTimerMode {
  minutes,
  endOfTrack,
  endOfQueue,

  /// Al terminar una canción elegida de la cola.
  untilTrack,

  /// En un segundo exacto de la canción que suena.
  atPosition;

  String get label => switch (this) {
    SleepTimerMode.minutes => tx.enUnosMinutos,
    SleepTimerMode.endOfTrack => tx.alTerminarEstaCancion,
    SleepTimerMode.endOfQueue => tx.alTerminarLaCola,
    SleepTimerMode.untilTrack => tx.hastaUnaCancionDeLaCola,
    SleepTimerMode.atPosition => tx.enUnMomentoExacto,
  };

  /// Para el botón del reproductor cuando todavía no se sabe cuánto falta.
  String get shortLabel => switch (this) {
    SleepTimerMode.minutes => tx.minutos,
    SleepTimerMode.endOfTrack => tx.estaCancion,
    SleepTimerMode.endOfQueue => tx.finDeLaCola,
    SleepTimerMode.untilTrack => tx.hastaCancion,
    SleepTimerMode.atPosition => tx.momentoExacto,
  };
}

/// Lógica pura del temporizador (sin reproductor ni relojes reales).
abstract final class SleepTimerLogic {
  /// El volumen baja de a poco durante los últimos 30 segundos.
  static const fadeDuration = Duration(seconds: 30);

  /// Opciones rápidas de "en X minutos".
  static const minuteOptions = [5, 10, 15, 30, 45, 60, 90];

  /// "En X minutos" con número a elección.
  static const minMinutes = 1;
  static const maxMinutes = 600;

  /// Cuánto falta para pausar, o null si todavía no se puede saber (por
  /// ejemplo, "al terminar la cola" mientras no suena la última canción, o
  /// "hasta una canción" mientras no suena esa).
  static Duration? remaining({
    required SleepTimerMode mode,
    required DateTime now,
    DateTime? endsAt,
    required Duration position,
    required Duration duration,
    required bool isLastInQueue,
    String? currentTrackId,
    String? targetTrackId,
    Duration? targetPosition,
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
      case SleepTimerMode.untilTrack:
        return currentTrackId != null && currentTrackId == targetTrackId ? _trackLeft(position, duration) : null;
      case SleepTimerMode.atPosition:
        if (targetPosition == null) return null;
        final left = targetPosition - position;
        return left.isNegative ? Duration.zero : left;
    }
  }

  /// Si el temporizador ya no tiene sentido y hay que apagarlo, el motivo
  /// para avisar al usuario; si no, null.
  static String? cancelReason({
    required SleepTimerMode mode,
    required List<String> queueIds,
    String? currentTrackId,
    String? targetTrackId,
    String? targetTitle,
  }) {
    switch (mode) {
      case SleepTimerMode.untilTrack:
        if (targetTrackId != null && !queueIds.contains(targetTrackId)) {
          return tx.seQuitoDeLaColaEl(targetTitle ?? tx.laCancion);
        }
        return null;
      case SleepTimerMode.atPosition:
        if (targetTrackId != null && currentTrackId != targetTrackId) {
          return tx.cambioLaCancionElTemporizadorDe;
        }
        return null;
      case SleepTimerMode.minutes:
      case SleepTimerMode.endOfTrack:
      case SleepTimerMode.endOfQueue:
        return null;
    }
  }

  static Duration? _trackLeft(Duration position, Duration duration) {
    if (duration <= Duration.zero) return null; // todavía no se sabe cuánto dura
    final left = duration - position;
    return left.isNegative ? Duration.zero : left;
  }

  /// Ventana del desvanecimiento: 30 s, o lo que falte si es menos cuando
  /// se conoce el final ("o menos si falta poco"). Así nunca hay un salto
  /// brusco de volumen.
  static Duration fadeWindowFor(Duration remaining) => remaining < fadeDuration ? remaining : fadeDuration;

  /// Factor de volumen (0..1) para [remaining]: 1 hasta que empieza la
  /// ventana de desvanecimiento, y de ahí baja en línea recta hasta 0.
  static double fadeFactor(Duration? remaining, {Duration window = fadeDuration}) {
    if (remaining == null || remaining >= window) return 1;
    if (remaining <= Duration.zero || window <= Duration.zero) return 0;
    return remaining.inMilliseconds / window.inMilliseconds;
  }

  /// Hay que pausar ya. Para canciones se pausa un instante antes del final,
  /// así no llega a arrancar la siguiente.
  static bool shouldStop(SleepTimerMode mode, Duration? remaining) {
    if (remaining == null) return false;
    final margin = switch (mode) {
      SleepTimerMode.minutes || SleepTimerMode.atPosition => Duration.zero,
      _ => const Duration(milliseconds: 400),
    };
    return remaining <= margin;
  }

  /// El momento elegido ya pasó en la canción (con 1 s de margen: elegir
  /// "ahora mismo" no cuenta como pasado).
  static bool alreadyPassed(Duration target, Duration position) => target + const Duration(seconds: 1) < position;

  /// Momento por defecto de "en un momento exacto": 1 minuto antes del final
  /// (o el principio, si la canción dura menos de un minuto).
  static Duration defaultTargetPosition(Duration duration) {
    final target = duration - const Duration(minutes: 1);
    return target.isNegative ? Duration.zero : target;
  }

  /// Valor inicial del selector: 1 minuto antes del final; si eso ya pasó,
  /// 5 segundos después de donde va (sin pasarse del final).
  static Duration defaultDialogPosition(Duration duration, Duration position) {
    final target = defaultTargetPosition(duration);
    if (!alreadyPassed(target, position)) return target;
    final soon = position + const Duration(seconds: 5);
    return soon > duration ? duration : soon;
  }

  /// "12:05" o "1:02:05" para mostrar cuánto falta.
  static String format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
