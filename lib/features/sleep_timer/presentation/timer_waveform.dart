import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/waveform_progress.dart';
import '../domain/sleep_timer_logic.dart';
import '../sleep_timer_provider.dart';

/// Fracción de la canción donde va la luna del temporizador, o null.
double? sleepMarkerFraction(SleepTimerState? timer, PlaybackState playback) {
  final target = timer?.targetPosition;
  if (timer == null || timer.mode != SleepTimerMode.atPosition || target == null) return null;
  if (playback.track?.id != timer.targetTrackId || playback.duration <= Duration.zero) return null;
  return target.inMilliseconds / playback.duration.inMilliseconds;
}

/// La onda del reproductor, conectada al temporizador (Tarea Z2): muestra la
/// luna donde se va a pausar y, en el modo "Marcar en la onda", tocarla elige
/// ese momento en vez de saltar.
class TimerWaveform extends ConsumerWidget {
  const TimerWaveform({super.key, this.height = 44, this.barWidth = 3});

  final double height;
  final double barWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final timer = ref.watch(sleepTimerProvider);
    final marking = ref.watch(sleepTimerMarkingProvider);
    final track = playback.track;
    if (track == null) return SizedBox(height: height);

    final wave = WaveformProgress(
      seed: track.id,
      progress: playback.progress,
      height: height,
      barWidth: barWidth,
      marker: sleepMarkerFraction(timer, playback),
      onSeek: marking
          ? (fraction) {
              final target = Duration(milliseconds: (playback.duration.inMilliseconds * fraction).round());
              ref.read(sleepTimerProvider.notifier).startAtPosition(target);
              ref.read(playbackNoticeProvider.notifier).state = PlaybackNotice(
                'La música se va a pausar en el ${SleepTimerLogic.format(target)}'
                '${SleepTimerLogic.alreadyPassed(target, playback.position) ? ' (cuando vuelva ahí)' : ''}.',
              );
            }
          : ref.read(playbackProvider.notifier).seekToProgress,
    );
    if (!marking) return wave;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.bedtime_outlined, size: 16, color: KijiColors.cyan),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Tocá la onda donde querés que se pause', style: TextStyle(color: KijiColors.cyan)),
            ),
            TextButton(
              onPressed: () => ref.read(sleepTimerMarkingProvider.notifier).state = false,
              child: const Text('Cancelar'),
            ),
          ],
        ),
        wave,
      ],
    );
  }
}
