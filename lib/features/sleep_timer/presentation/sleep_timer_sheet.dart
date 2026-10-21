import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../domain/sleep_timer_logic.dart';
import '../sleep_timer_provider.dart';

import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

/// Hoja del temporizador: elegir cómo termina, o ver cuál está activo,
/// cuánto falta y apagarlo.
Future<void> showSleepTimerSheet(BuildContext context) {
  return showKijiSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const SafeArea(child: _SleepTimerSheet()),
  );
}

/// Texto corto del botón Temporizador: cuánto falta o, si todavía no se
/// sabe, qué modo está activo.
String sleepTimerButtonLabel(SleepTimerState? timer) {
  if (timer == null) return tx.temporizador;
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
          Text(tx.temporizador, style: KijiText.title(size: 22)),
          const SizedBox(height: 4),
          Text(tx.laMusicaBajaDeAPoco, style: TextStyle(color: KijiColors.muted)),
          const SizedBox(height: 16),
          if (timer != null) ..._active(timer, notifier) else ..._choices(notifier),
        ],
      ),
    );
  }

  List<Widget> _active(SleepTimerState timer, SleepTimerNotifier notifier) {
    final detail = switch (timer.mode) {
      SleepTimerMode.untilTrack => tx.alTerminar(timer.targetTitle),
      SleepTimerMode.atPosition => tx.enElDe(
        SleepTimerLogic.format(timer.targetPosition ?? Duration.zero),
        timer.targetTitle,
      ),
      _ => timer.mode.label,
    };
    return [
      Text(tx.activo, style: KijiText.mono(size: 11)),
      const SizedBox(height: 4),
      Text(detail, style: KijiText.title(size: 16, weight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(
        timer.waitingForTarget
            ? tx.yaPasoPausaCuandoVuelva
            : timer.remaining == null
            ? tx.esperandoEsaCancion
            : tx.faltan(SleepTimerLogic.format(timer.remaining!)),
        style: KijiText.mono(size: 28, color: KijiColors.cyan, weight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () {
          notifier.cancel();
          Navigator.pop(context);
        },
        icon: const Icon(Icons.timer_off_outlined),
        label: Text(tx.apagarElTemporizador),
      ),
    ];
  }

  List<Widget> _choices(SleepTimerNotifier notifier) {
    final playback = ref.watch(playbackProvider);
    return [
      Text(tx.enUnosMinutos2, style: KijiText.mono(size: 11)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final minutes in SleepTimerLogic.minuteOptions)
            ActionChip(
              label: Text(
                minutes < 60 ? tx.nMin(minutes) : '${minutes ~/ 60} h${minutes % 60 == 0 ? '' : ' ${minutes % 60}'}',
              ),
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
              decoration: InputDecoration(labelText: tx.otroNumeroDeMinutos, helperText: tx.de1A600),
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
            child: Text(tx.iniciar),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.music_note_outlined, color: KijiColors.cyan),
        title: Text(SleepTimerMode.endOfTrack.label),
        onTap: () {
          notifier.start(SleepTimerMode.endOfTrack);
          Navigator.pop(context);
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.queue_music_rounded, color: KijiColors.cyan),
        title: Text(SleepTimerMode.endOfQueue.label),
        subtitle: Text(tx.paraHastaUnaCancionEligelaEn),
        onTap: () {
          notifier.start(SleepTimerMode.endOfQueue);
          Navigator.pop(context);
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.timer_outlined, color: KijiColors.cyan),
        title: Text(SleepTimerMode.atPosition.label),
        subtitle: Text(tx.eligeElSegundoDeLaCancion),
        enabled: playback.track != null && playback.duration > Duration.zero,
        onTap: () async {
          final position = await showExactMomentDialog(context, playback.duration, playback.position);
          if (position == null) return;
          notifier.startAtPosition(position);
          if (mounted) Navigator.pop(context);
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.bedtime_outlined, color: KijiColors.cyan),
        title: Text(tx.marcarEnLaOnda),
        subtitle: Text(tx.tocaLaOndaDelReproductorDonde),
        enabled: playback.track != null && playback.duration > Duration.zero,
        onTap: () {
          ref.read(sleepTimerMarkingProvider.notifier).state = true;
          Navigator.pop(context);
        },
      ),
    ];
  }
}

/// Selector simple de mm:ss dentro de la canción: cualquier
/// punto de 0:00 al final. Por defecto, 1 minuto antes del final (o un poco
/// después de donde va, si eso ya pasó).
Future<Duration?> showExactMomentDialog(BuildContext context, Duration duration, Duration position) {
  var selected = SleepTimerLogic.defaultDialogPosition(duration, position);
  return showDialog<Duration>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void move(int seconds) => setState(() {
          final next = selected + Duration(seconds: seconds);
          selected = next < Duration.zero ? Duration.zero : (next > duration ? duration : next);
        });
        return AlertDialog(
          title: Text(tx.pausarEnEsteMomento),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SleepTimerLogic.format(selected),
                style: KijiText.mono(size: 36, color: KijiColors.cyan, weight: FontWeight.w600),
              ),
              Text(tx.deDuracion(SleepTimerLogic.format(duration)), style: KijiText.mono(size: 12)),
              Slider(
                value: selected.inSeconds.toDouble(),
                min: 0,
                max: duration.inSeconds.toDouble(),
                onChanged: (value) => setState(() => selected = Duration(seconds: value.round())),
                semanticFormatterCallback: (value) => SleepTimerLogic.format(Duration(seconds: value.round())),
              ),
              if (SleepTimerLogic.alreadyPassed(selected, position))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    tx.eseMomentoYaPasoLaMusica,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KijiColors.muted, fontSize: 12),
                  ),
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
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tx.cancelar)),
            FilledButton(onPressed: () => Navigator.pop(context, selected), child: Text(tx.listo)),
          ],
        );
      },
    ),
  );
}
