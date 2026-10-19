import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/appearance_provider.dart';
import '../../providers/shell_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/nocturne/glass.dart';
import '../../l10n/l10n.dart';

String _home(AppLocalizations t) => t.navHome;
String _search(AppLocalizations t) => t.navSearch;
String _library(AppLocalizations t) => t.navLibrary;

class ShellDestination {
  const ShellDestination(this.tab, this._label, this.icon);

  final ShellTab tab;
  final String Function(AppLocalizations t) _label;

  /// El nombre de la pestaña en el idioma de la app (Tarea T5).
  String labelOf(BuildContext context) => _label(tr(context));
  final IconData icon;

  static const all = [
    ShellDestination(ShellTab.home, _home, Icons.home_rounded),
    ShellDestination(ShellTab.search, _search, Icons.search_rounded),
    ShellDestination(ShellTab.library, _library, Icons.library_music_rounded),
  ];
}

/// Barra inferior flotante en forma de píldora (§7, celular): la pestaña
/// activa muestra ícono + texto sobre el degradado; las otras, solo el ícono
/// en gris. El degradado se desliza de una pestaña a otra (Tarea Z6).
class PillNavBar extends ConsumerWidget {
  const PillNavBar({super.key});

  static const _labelStyle = TextStyle(color: KijiColors.onAccent, fontWeight: FontWeight.w700);
  static const _iconOnly = 16 + 22 + 16.0;

  /// Ancho de cada pestaña: la activa lleva también el texto.
  static double widthOf(BuildContext context, ShellDestination d, {required bool selected}) {
    if (!selected) return _iconOnly;
    final painter = TextPainter(
      text: TextSpan(text: d.labelOf(context), style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return 18 + 22 + 8 + painter.width + 18 + 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(shellTabProvider);
    final duration = reduceMotion(context, ref) ? Duration.zero : KijiMotion.normal;
    final widths = [
      for (final d in ShellDestination.all) widthOf(context, d, selected: d.tab == current),
    ];
    final index = ShellDestination.all.indexWhere((d) => d.tab == current);
    final left = widths.take(index).fold(0.0, (a, b) => a + b);

    return Glass(
      radius: KijiRadii.pill,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 48,
        width: widths.fold<double>(0, (a, b) => a + b),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeOutCubic,
              left: left,
              width: widths[index],
              top: 0,
              bottom: 0,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: KijiColors.accentGradient,
                  borderRadius: BorderRadius.all(Radius.circular(KijiRadii.pill)),
                ),
              ),
            ),
            Row(
              children: [
                for (final (i, destination) in ShellDestination.all.indexed)
                  _PillItem(
                    destination: destination,
                    selected: destination.tab == current,
                    width: widths[i],
                    duration: duration,
                    onTap: () => ref.read(shellTabProvider.notifier).state = destination.tab,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const _PillItem({
    required this.destination,
    required this.selected,
    required this.width,
    required this.duration,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final double width;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: destination.labelOf(context),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          width: width,
          height: 48,
          // Mientras cambia el ancho, lo que no entra se recorta (sin error de desborde).
          child: UnconstrainedBox(
            clipBehavior: Clip.hardEdge,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  destination.icon,
                  color: selected ? KijiColors.onAccent : KijiColors.muted,
                  size: 22,
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Text(destination.labelOf(context), style: PillNavBar._labelStyle),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
