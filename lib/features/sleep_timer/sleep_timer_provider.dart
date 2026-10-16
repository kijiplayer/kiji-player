import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/playback_provider.dart';
import 'domain/sleep_timer_logic.dart';

/// Temporizador activo: cómo termina y cuánto falta.
class SleepTimerState {
  const SleepTimerState({required this.mode, this.endsAt, this.remaining});

  final SleepTimerMode mode;

  /// Solo en el modo "en X minutos".
  final DateTime? endsAt;

  /// null mientras no se sabe (por ejemplo, "al terminar la cola" antes de
  /// la última canción).
  final Duration? remaining;

  SleepTimerState withRemaining(Duration? value) =>
      SleepTimerState(mode: mode, endsAt: endsAt, remaining: value);
}

/// Temporizador de apagado (Tarea H). null = apagado.
class SleepTimerNotifier extends Notifier<SleepTimerState?> {
  Timer? _ticker;

  /// Reloj (reemplazable en tests).
  DateTime Function() clock = DateTime.now;

  static const _tick = Duration(milliseconds: 250);

  @override
  SleepTimerState? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  void start(SleepTimerMode mode, {int minutes = 30}) {
    _ticker?.cancel();
    state = SleepTimerState(
      mode: mode,
      endsAt: mode == SleepTimerMode.minutes ? clock().add(Duration(minutes: minutes)) : null,
    );
    _ticker = Timer.periodic(_tick, (_) => _check());
    _check();
  }

  /// Apagar el temporizador: la música sigue y el volumen vuelve a la normalidad.
  Future<void> cancel() async {
    _ticker?.cancel();
    _ticker = null;
    state = null;
    await ref.read(playbackProvider.notifier).setFadeFactor(1);
  }

  Future<void> _check() async {
    final timer = state;
    if (timer == null) return;
    final playback = ref.read(playbackProvider);
    final remaining = SleepTimerLogic.remaining(
      mode: timer.mode,
      now: clock(),
      endsAt: timer.endsAt,
      position: playback.position,
      duration: playback.duration,
      isLastInQueue: playback.queue.isEmpty || playback.currentIndex >= playback.queue.length - 1,
    );
    state = timer.withRemaining(remaining);

    final player = ref.read(playbackProvider.notifier);
    if (SleepTimerLogic.shouldStop(timer.mode, remaining)) {
      _ticker?.cancel();
      _ticker = null;
      state = null;
      final wasPlaying = playback.isPlaying;
      await player.pause();
      await player.setFadeFactor(1);
      if (wasPlaying) {
        ref.read(playbackNoticeProvider.notifier).state =
            const PlaybackNotice('Temporizador: la música quedó en pausa. Que descanses.');
      }
      return;
    }
    if (playback.isPlaying) await player.setFadeFactor(SleepTimerLogic.fadeFactor(remaining));
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerNotifier, SleepTimerState?>(SleepTimerNotifier.new);
