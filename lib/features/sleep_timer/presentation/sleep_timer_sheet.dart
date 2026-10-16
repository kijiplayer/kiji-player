import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../domain/sleep_timer_logic.dart';
import '../sleep_timer_provider.dart';

/// Hoja del temporizador: elegir cómo termina, o ver cuál está activo,
/// cuánto falta y apagarlo.
Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const SafeArea(child: _SleepTimerSheet()),
  );
}

/// Texto corto del botón Temporizador: cuánto falta o, si todavía no se
/// sabe, qué modo está activo.
String sleepTimerButtonLabel(SleepTimerState? timer) {
  if (timer == null) return 'Temporizador';
  final remaining = timer.remaining;
  return remaining == null ? timer.mode.shortLabel : SleepTimerLogic.format(remaining);
}

class _SleepTimerSheet extends ConsumerStatefulWidget {
  const _SleepTimerSheet();

  @override
  ConsumerState<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends ConsumerState<_SleepTimerSheet> {
  final _minutes = TextEditingController();

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  int? get _customMinutes {
    final value = int.tryParse(_minutes.text.trim());
    if (value == null || value < SleepTimerLogic.minMinutes || value > SleepTimerLogic.maxMinutes) {
      return null;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(sleepTimerProvider);
    final notifier = ref.read(sleepTimerProvider.notifier);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Temporizador', style: KijiText.title(size: 22)),
          const SizedBox(height: 4),
          const Text(
            'La música baja de a poco durante los últimos 30 segundos (o menos, si falta poco) '
            'y queda en pausa.',
            style: TextStyle(color: KijiColors.muted),
          ),
          const SizedBox(height: 16),
          if (timer != null) ..._active(timer, notifier) else ..._choices(notifier),
        ],
      ),
    );
  }

  List<Widget> _active(SleepTimerState timer, SleepTimerNotifier notifier) {
    final detail = switch (timer.mode) {
      SleepTimerMode.untilTrack => 'Al terminar «${timer.targetTitle}»',
      SleepTimerMode.atPosition =>
        'En el ${SleepTimerLogic.format(timer.targetPosition ?? Duration.zero)} de «${timer.targetTitle}»',
      _ => timer.mode.label,
    };
    return [
      Text('ACTIVO', style: KijiText.mono(size: 11)),
      const SizedBox(height: 4),
      Text(detail, style: KijiText.title(size: 16, weight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(
        timer.remaining == null
            ? 'Esperando esa canción'
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
    ];
  }

  List<Widget> _choices(SleepTimerNotifier notifier) {
    final playback = ref.watch(playbackProvider);
    return [
      Text('EN UNOS MINUTOS', style: KijiText.mono(size: 11)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final minutes in SleepTimerLogic.minuteOptions)
            ActionChip(
              label: Text(minutes < 60
                  ? '$minutes min'
                  : '${minutes ~/ 60} h${minutes % 60 == 0 ? '' : ' ${minutes % 60}'}'),
              onPressed: () {
                notifier.start(SleepTimerMode.minutes, minutes: minutes);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Otro número de minutos',
                helperText: 'De 1 a 600',
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _customMinutes == null
                ? null
                : () {
                    notifier.start(SleepTimerMode.minutes, minutes: _customMinutes!);
                    Navigator.pop(context);
                  },
            child: const Text('Iniciar'),
          ),
        ],
      ),
      const SizedBox(height: 8),
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
        subtitle: const Text('Para "hasta una canción", elegila en la Cola (menú ⋮ → luna).'),
        onTap: () {
          notifier.start(SleepTimerMode.endOfQueue);
          Navigator.pop(context);
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.timer_outlined, color: KijiColors.cyan),
        title: Text(SleepTimerMode.atPosition.label),
        subtitle: const Text('Elegí el segundo de la canción que suena'),
        enabled: playback.track != null && playback.duration > Duration.zero,
        onTap: () async {
          final position = await showExactMomentDialog(context, playback.duration, playback.position);
          if (position == null) return;
          notifier.startAtPosition(position);
          if (mounted) Navigator.pop(context);
        },
      ),
    ];
  }
}

/// Selector simple de mm:ss dentro de la canción (Tarea H2). Por defecto, 1
/// minuto antes del final.
Future<Duration?> showExactMomentDialog(BuildContext context, Duration duration, Duration position) {
  var selected = SleepTimerLogic.defaultTargetPosition(duration);
  if (selected < position) selected = position;
  return showDialog<Duration>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void move(int seconds) => setState(() {
              final next = selected + Duration(seconds: seconds);
              selected = next < position ? position : (next > duration ? duration : next);
            });
        return AlertDialog(
          title: const Text('Pausar en este momento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SleepTimerLogic.format(selected),
                style: KijiText.mono(size: 36, color: KijiColors.cyan, weight: FontWeight.w600),
              ),
              Text('de ${SleepTimerLogic.format(duration)}', style: KijiText.mono(size: 12)),
              Slider(
                value: selected.inSeconds.toDouble(),
                min: position.inSeconds.toDouble(),
                max: duration.inSeconds.toDouble(),
                onChanged: (value) => setState(() => selected = Duration(seconds: value.round())),
                semanticFormatterCallback: (value) =>
                    SleepTimerLogic.format(Duration(seconds: value.round())),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(onPressed: () => move(-5), child: const Text('−5 s')),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: () => move(5), child: const Text('+5 s')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Listo')),
          ],
        );
      },
    ),
  );
}
