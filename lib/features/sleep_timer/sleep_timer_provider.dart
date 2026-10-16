import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/track.dart';
import '../../providers/playback_provider.dart';
import 'domain/sleep_timer_logic.dart';

/// Temporizador activo: cómo termina y cuánto falta.
class SleepTimerState {
  const SleepTimerState({
    required this.mode,
    this.endsAt,
    this.remaining,
    this.targetTrackId,
    this.targetTitle,
    this.targetPosition,
    this.fadeWindow,
  });

  final SleepTimerMode mode;

  /// Solo en el modo "en X minutos".
  final DateTime? endsAt;

  /// null mientras no se sabe (por ejemplo, "al terminar la cola" antes de
  /// la última canción).
  final Duration? remaining;

  /// "Hasta esta canción" y "momento exacto": la canción elegida.
  final String? targetTrackId;
  final String? targetTitle;

  /// "Momento exacto": el segundo de la canción en el que se pausa.
  final Duration? targetPosition;

  /// Ventana del desvanecimiento (30 s o menos si faltaba poco). Se fija la
  /// primera vez que se sabe cuánto falta.
  final Duration? fadeWindow;

  SleepTimerState copyWith({Duration? remaining, Duration? fadeWindow}) => SleepTimerState(
        mode: mode,
        endsAt: endsAt,
        remaining: remaining,
        targetTrackId: targetTrackId,
        targetTitle: targetTitle,
        targetPosition: targetPosition,
        fadeWindow: fadeWindow ?? this.fadeWindow,
      );
}

/// Temporizador de apagado (Tareas H y H2). null = apagado.
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
    final clamped = minutes.clamp(SleepTimerLogic.minMinutes, SleepTimerLogic.maxMinutes);
    _begin(SleepTimerState(
      mode: mode,
      endsAt: mode == SleepTimerMode.minutes ? clock().add(Duration(minutes: clamped)) : null,
    ));
  }

  /// "Pausar al terminar esta" (Tarea H2): [track] tiene que estar en la cola.
  void startUntilTrack(Track track) => _begin(SleepTimerState(
        mode: SleepTimerMode.untilTrack,
        targetTrackId: track.id,
        targetTitle: track.title,
      ));

  /// "En un momento exacto" de la canción que suena (Tarea H2).
  void startAtPosition(Duration position) {
    final track = ref.read(playbackProvider).track;
    if (track == null) return;
    _begin(SleepTimerState(
      mode: SleepTimerMode.atPosition,
      targetTrackId: track.id,
      targetTitle: track.title,
      targetPosition: position,
    ));
  }

  void _begin(SleepTimerState timer) {
    _ticker?.cancel();
    state = timer;
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
    final player = ref.read(playbackProvider.notifier);

    final reason = SleepTimerLogic.cancelReason(
      mode: timer.mode,
      queueIds: [for (final t in playback.queue) t.id],
      currentTrackId: playback.track?.id,
      targetTrackId: timer.targetTrackId,
      targetTitle: timer.targetTitle,
    );
    if (reason != null) {
      await cancel();
      ref.read(playbackNoticeProvider.notifier).state = PlaybackNotice(reason);
      return;
    }

    final remaining = SleepTimerLogic.remaining(
      mode: timer.mode,
      now: clock(),
      endsAt: timer.endsAt,
      position: playback.position,
      duration: playback.duration,
      isLastInQueue: playback.queue.isEmpty || playback.currentIndex >= playback.queue.length - 1,
      currentTrackId: playback.track?.id,
      targetTrackId: timer.targetTrackId,
      targetPosition: timer.targetPosition,
    );
    final window = timer.fadeWindow ??
        (remaining == null ? null : SleepTimerLogic.fadeWindowFor(remaining));
    state = timer.copyWith(remaining: remaining, fadeWindow: window);

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
    if (playback.isPlaying) {
      await player.setFadeFactor(
        SleepTimerLogic.fadeFactor(remaining, window: window ?? SleepTimerLogic.fadeDuration),
      );
    }
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerNotifier, SleepTimerState?>(SleepTimerNotifier.new);
