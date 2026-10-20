import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/track.dart';
import '../../providers/playback_provider.dart';
import 'domain/sleep_timer_logic.dart';

import 'package:kiji_player/l10n/l10n.dart';

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
    this.waitingForTarget = false,
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

  /// "Momento exacto" elegido en un punto que ya pasó: espera a
  /// que la canción vuelva antes de ese punto (si se vuelve atrás o se
  /// repite) y recién ahí cuenta. Así nunca pausa de golpe.
  final bool waitingForTarget;

  SleepTimerState copyWith({Duration? remaining, Duration? fadeWindow, bool? waitingForTarget}) => SleepTimerState(
    mode: mode,
    endsAt: endsAt,
    remaining: remaining,
    targetTrackId: targetTrackId,
    targetTitle: targetTitle,
    targetPosition: targetPosition,
    fadeWindow: fadeWindow ?? this.fadeWindow,
    waitingForTarget: waitingForTarget ?? this.waitingForTarget,
  );
}

/// Temporizador de apagado. null = apagado.
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
    _begin(
      SleepTimerState(
        mode: mode,
        endsAt: mode == SleepTimerMode.minutes ? clock().add(Duration(minutes: clamped)) : null,
      ),
    );
  }

  /// "Pausar al terminar esta": [track] tiene que estar en la cola.
  void startUntilTrack(Track track) =>
      _begin(SleepTimerState(mode: SleepTimerMode.untilTrack, targetTrackId: track.id, targetTitle: track.title));

  /// "En un momento exacto" de la canción que suena.
  /// Cualquier punto de 0:00 al final; si ya pasó, espera a que
  /// la canción vuelva a ese punto.
  void startAtPosition(Duration position) {
    final playback = ref.read(playbackProvider);
    final track = playback.track;
    if (track == null) return;
    ref.read(sleepTimerMarkingProvider.notifier).state = false;
    _begin(
      SleepTimerState(
        mode: SleepTimerMode.atPosition,
        targetTrackId: track.id,
        targetTitle: track.title,
        targetPosition: position,
        waitingForTarget: SleepTimerLogic.alreadyPassed(position, playback.position),
      ),
    );
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

    // Momento ya pasado: se arma cuando la canción vuelve antes de ese punto.
    var waiting = timer.waitingForTarget;
    if (waiting && timer.targetPosition != null && playback.position < timer.targetPosition!) {
      waiting = false;
    }
    final remaining = waiting
        ? null
        : SleepTimerLogic.remaining(
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
    final window = timer.fadeWindow ?? (remaining == null ? null : SleepTimerLogic.fadeWindowFor(remaining));
    state = timer.copyWith(remaining: remaining, fadeWindow: window, waitingForTarget: waiting);

    if (SleepTimerLogic.shouldStop(timer.mode, remaining)) {
      _ticker?.cancel();
      _ticker = null;
      state = null;
      final wasPlaying = playback.isPlaying;
      await player.pause();
      await player.setFadeFactor(1);
      if (wasPlaying) {
        ref.read(playbackNoticeProvider.notifier).state = PlaybackNotice(tx.temporizadorLaMusicaQuedoEnPausa);
      }
      return;
    }
    if (playback.isPlaying) {
      await player.setFadeFactor(SleepTimerLogic.fadeFactor(remaining, window: window ?? SleepTimerLogic.fadeDuration));
    }
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, SleepTimerState?>(SleepTimerNotifier.new);

/// "Marcar en la onda": mientras es true, tocar la onda del
/// reproductor elige el momento de la pausa en vez de saltar a ese punto.
final sleepTimerMarkingProvider = StateProvider<bool>((ref) => false);
