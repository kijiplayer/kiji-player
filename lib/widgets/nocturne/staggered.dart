import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/appearance_provider.dart';
import '../../theme/kiji_tokens.dart';

/// Marca el momento en que apareció una lista: solo los ítems que se ven al
/// abrirla entran escalonados; los que llegan después al hacer scroll, no
/// esperan (Tarea Z6). Cambiar [generation] (por ejemplo, otra búsqueda)
/// vuelve a escalonar.
class StaggerScope extends StatefulWidget {
  const StaggerScope({super.key, this.generation, required this.child});

  final Object? generation;
  final Widget child;

  @override
  State<StaggerScope> createState() => _StaggerScopeState();
}

class _StaggerScopeState extends State<StaggerScope> {
  DateTime _start = DateTime.now();

  @override
  void didUpdateWidget(StaggerScope old) {
    super.didUpdateWidget(old);
    if (old.generation != widget.generation) _start = DateTime.now();
  }

  @override
  Widget build(BuildContext context) => _StaggerStart(start: _start, child: widget.child);
}

class _StaggerStart extends InheritedWidget {
  const _StaggerStart({required this.start, required super.child});
  final DateTime start;

  @override
  bool updateShouldNotify(_StaggerStart old) => old.start != start;
}

/// Un ítem que entra con fundido + subida, [index] × 40 ms después del
/// anterior. Con "Reducir animaciones" aparece directo.
class StaggeredEntrance extends ConsumerStatefulWidget {
  const StaggeredEntrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  ConsumerState<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends ConsumerState<StaggeredEntrance> with SingleTickerProviderStateMixin {
  // La demora va dentro de la misma animación (un Interval), sin Timer aparte.
  late final Duration _delay = KijiMotion.stagger * widget.index.clamp(0, 12);
  late final AnimationController _c = AnimationController(vsync: this, duration: _delay + KijiMotion.normal);
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    final start = context.dependOnInheritedWidgetOfExactType<_StaggerStart>()?.start;
    final late = start != null && DateTime.now().difference(start) > const Duration(milliseconds: 700);
    if (reduceMotion(context, ref) || late) {
      _c.value = 1;
      return;
    }
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = _delay.inMicroseconds / _c.duration!.inMicroseconds;
    final curve = CurvedAnimation(parent: _c, curve: Interval(start, 1, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// Envuelve cada widget de [children] en un [StaggeredEntrance] (los
/// separadores fijos también cuentan, así el ritmo es parejo).
List<Widget> staggered(List<Widget> children) => [
      for (final (i, child) in children.indexed) StaggeredEntrance(index: i, child: child),
    ];
