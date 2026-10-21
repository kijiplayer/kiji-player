import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../utils/duration_formatter.dart';
import '../data/moments_store.dart';
import '../domain/moment.dart';
import 'moments_screen.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// El tramo que se está repitiendo (null: ninguno).
final momentLoopProvider = StateProvider<Moment?>((ref) => null);

/// Qué hacer con la posición mientras se repite un tramo: volver al principio al llegar al final, o
/// dejar de repetir si cambió la canción.
enum LoopAction { none, seekToStart, stop }

LoopAction loopActionFor(Moment? loop, String? trackId, Duration position) {
  final end = loop?.end;
  if (loop == null || end == null) return LoopAction.none;
  if (trackId != loop.track.id) return LoopAction.stop;
  return position >= end ? LoopAction.seekToStart : LoopAction.none;
}

/// Engancha la repetición de tramos al reproductor (se llama una vez, desde la app).
void watchMomentLoop(WidgetRef ref) {
  ref.listenManual(playbackProvider.select((p) => (p.track?.id, p.position)), (_, now) {
    final loop = ref.read(momentLoopProvider);
    switch (loopActionFor(loop, now.$1, now.$2)) {
      case LoopAction.seekToStart:
        ref.read(playbackProvider.notifier).seekTo(loop!.position);
      case LoopAction.stop:
        ref.read(momentLoopProvider.notifier).state = null;
      case LoopAction.none:
        break;
    }
  });
}

/// Los Momentos de la canción que suena, sobre la onda del reproductor: un punto es una marca
/// pequeña y un tramo, un segmento resaltado. Tocar una marca salta ahí; mantener presionado un
/// tramo lo repite.
class MomentMarks extends ConsumerWidget {
  const MomentMarks({super.key});

  static const height = 18.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playbackProvider.select((p) => p.track));
    final duration = ref.watch(playbackProvider.select((p) => p.duration));
    final moments = [
      for (final m in ref.watch(momentsProvider))
        if (m.track.id == track?.id) m,
    ];
    final loop = ref.watch(momentLoopProvider);
    if (track == null || moments.isEmpty || duration <= Duration.zero) return const SizedBox(height: 6);
    final total = duration.inMilliseconds;
    double fraction(Duration d) => (d.inMilliseconds / total).clamp(0.0, 1.0);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final m in moments)
                if (m.isInterval)
                  Positioned(
                    left: fraction(m.position) * width,
                    width: ((fraction(m.end!) - fraction(m.position)) * width).clamp(8.0, width),
                    top: 5,
                    height: 8,
                    child: Semantics(
                      button: true,
                      label: tx.tramoDeA(formatDuration(m.position), formatDuration(m.end!)),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => playMoment(ref, m),
                        onLongPress: () => toggleMomentLoop(context, ref, m),
                        child: Container(
                          decoration: BoxDecoration(
                            color: KijiColors.cyan.withValues(alpha: loop?.id == m.id ? 0.95 : 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: fraction(m.position) * width - 12,
                    top: -3,
                    width: 24,
                    height: 24,
                    child: Semantics(
                      button: true,
                      label: tx.momentoEn(formatDuration(m.position)),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => playMoment(ref, m),
                        child: Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: KijiColors.violet,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// Resaltado de los tramos sobre la onda (no recibe toques: la onda sigue sirviendo para buscar).
class MomentIntervalsHighlight extends ConsumerWidget {
  const MomentIntervalsHighlight({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackId = ref.watch(playbackProvider.select((p) => p.track?.id));
    final duration = ref.watch(playbackProvider.select((p) => p.duration));
    final intervals = [
      for (final m in ref.watch(momentsProvider))
        if (m.track.id == trackId && m.isInterval) m,
    ];
    if (intervals.isEmpty || duration <= Duration.zero) return const SizedBox.shrink();
    final total = duration.inMilliseconds;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            for (final m in intervals)
              Positioned(
                left: m.position.inMilliseconds / total * constraints.maxWidth,
                width: (m.end! - m.position).inMilliseconds / total * constraints.maxWidth,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: KijiColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Repitiendo 1:12–1:40 ✕" debajo de la onda, mientras se repite un tramo.
class MomentLoopChip extends ConsumerWidget {
  const MomentLoopChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loop = ref.watch(momentLoopProvider);
    if (loop == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InputChip(
        avatar: Icon(Icons.repeat_one_rounded, size: 18, color: KijiColors.cyan),
        label: Text(tx.repitiendo(formatDuration(loop.position), formatDuration(loop.end!))),
        onDeleted: () => ref.read(momentLoopProvider.notifier).state = null,
        deleteButtonTooltipMessage: tx.dejarDeRepetir,
      ),
    );
  }
}

/// Repetir o dejar de repetir un tramo.
void toggleMomentLoop(BuildContext context, WidgetRef ref, Moment moment) {
  final loop = ref.read(momentLoopProvider.notifier);
  if (loop.state?.id == moment.id) {
    loop.state = null;
    return;
  }
  loop.state = moment;
  playMoment(ref, moment);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(tx.repitiendoDeA(formatDuration(moment.position), formatDuration(moment.end!))),
        persist: false,
      ),
    );
}

/// "Momento": guardar este segundo o un tramo (con dos tiradores), y repetir el tramo si se quiere.
Future<void> showNewMomentSheet(BuildContext context, WidgetRef ref) {
  final playback = ref.read(playbackProvider);
  if (playback.track == null || playback.duration <= Duration.zero) {
    saveCurrentMoment(context, ref);
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _NewMomentSheet(position: playback.position, duration: playback.duration),
  );
}

class _NewMomentSheet extends ConsumerStatefulWidget {
  const _NewMomentSheet({required this.position, required this.duration});

  final Duration position;
  final Duration duration;

  @override
  ConsumerState<_NewMomentSheet> createState() => _NewMomentSheetState();
}

class _NewMomentSheetState extends ConsumerState<_NewMomentSheet> {
  bool _interval = false;
  bool _repeat = false;
  late RangeValues _range = () {
    final total = widget.duration.inSeconds.toDouble();
    final now = widget.position.inSeconds.toDouble();
    return RangeValues((now - 10).clamp(0, total), (now + 20).clamp(0, total));
  }();

  void _save() {
    final track = ref.read(playbackProvider).track;
    if (track == null) return;
    final notifier = ref.read(momentsProvider.notifier);
    final moment = _interval
        ? notifier.add(
            track,
            Duration(seconds: _range.start.round()),
            end: Duration(seconds: _range.end.round()),
          )
        : notifier.add(track, widget.position);
    Navigator.of(context).pop();
    if (moment.isInterval && _repeat) {
      toggleMomentLoop(context, ref, moment);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            moment.isInterval
                ? tx.tramoGuardado(formatDuration(moment.position), formatDuration(moment.end!))
                : tx.momentoGuardadoEn(formatDuration(moment.position)),
          ),
          persist: false,
          action: SnackBarAction(label: tx.ver, onPressed: () => MomentsScreen.open(context)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inSeconds.toDouble();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tx.guardarUnMomento, style: KijiText.title(size: 20)),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.place_outlined),
                  label: Text(tx.esteSegundo(formatDuration(widget.position))),
                ),
                ButtonSegment(value: true, icon: const Icon(Icons.straighten_rounded), label: Text(tx.unTramo)),
              ],
              selected: {_interval},
              onSelectionChanged: (v) => setState(() => _interval = v.first),
            ),
            if (_interval) ...[
              const SizedBox(height: 16),
              Text(
                tx.deA(
                  formatDuration(Duration(seconds: _range.start.round())),
                  formatDuration(Duration(seconds: _range.end.round())),
                ),
                textAlign: TextAlign.center,
                style: KijiText.mono(size: 15, color: KijiColors.cyan),
              ),
              RangeSlider(
                values: _range,
                min: 0,
                max: total,
                divisions: total > 0 ? total.round() : null,
                labels: RangeLabels(
                  formatDuration(Duration(seconds: _range.start.round())),
                  formatDuration(Duration(seconds: _range.end.round())),
                ),
                onChanged: (v) => setState(() => _range = v.end - v.start < 2 ? _range : v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tx.repetirEsteTramo),
                subtitle: Text(tx.vuelveAlPrincipioDelTramoAl),
                value: _repeat,
                onChanged: (v) => setState(() => _repeat = v),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(icon: const Icon(Icons.bookmark_add_rounded), label: Text(tx.guardar), onPressed: _save),
          ],
        ),
      ),
    );
  }
}
