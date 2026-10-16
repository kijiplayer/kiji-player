import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../domain/sleep_timer_logic.dart';
import '../sleep_timer_provider.dart';

/// Hoja del temporizador: elegir cómo termina, o ver cuánto falta y apagarlo.
Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const SafeArea(child: _SleepTimerSheet()),
  );
}

class _SleepTimerSheet extends ConsumerWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    final notifier = ref.read(sleepTimerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Temporizador', style: KijiText.title(size: 22)),
          const SizedBox(height: 4),
          const Text(
            'La música baja de a poco durante los últimos 30 segundos y queda en pausa.',
            style: TextStyle(color: KijiColors.muted),
          ),
          const SizedBox(height: 16),
          if (timer != null) ...[
            Text(timer.mode.label.toUpperCase(), style: KijiText.mono(size: 11)),
            const SizedBox(height: 6),
            Text(
              timer.remaining == null
                  ? 'Espera a la última canción'
                  : 'Faltan ${SleepTimerLogic.format(timer.remaining!)}',
              style: KijiText.mono(size: 28, color: KijiColors.cyan, weight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                notifier.cancel();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.timer_off_outlined),
              label: const Text('Apagar el temporizador'),
            ),
          ] else ...[
            Text('EN UNOS MINUTOS', style: KijiText.mono(size: 11)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in SleepTimerLogic.minuteOptions)
                  ActionChip(
                    label: Text(minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h${minutes % 60 == 0 ? '' : ' ${minutes % 60}'}'),
                    onPressed: () {
                      notifier.start(SleepTimerMode.minutes, minutes: minutes);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.music_note_outlined, color: KijiColors.cyan),
              title: Text(SleepTimerMode.endOfTrack.label),
              onTap: () {
                notifier.start(SleepTimerMode.endOfTrack);
                Navigator.pop(context);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.queue_music_rounded, color: KijiColors.cyan),
              title: Text(SleepTimerMode.endOfQueue.label),
              onTap: () {
                notifier.start(SleepTimerMode.endOfQueue);
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }
}
