import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shell_provider.dart';
import '../theme/kiji_tokens.dart';

/// Da a [builder] un ScrollController que sube al principio cuando se vuelve a tocar la pestaña
/// [tab] estando en ella (como en todas las apps). Con "reducir animaciones", salta sin animar.
class ScrollToTopOnReselect extends ConsumerStatefulWidget {
  const ScrollToTopOnReselect({super.key, required this.tab, required this.builder});

  final ShellTab tab;
  final Widget Function(BuildContext context, ScrollController controller) builder;

  @override
  ConsumerState<ScrollToTopOnReselect> createState() => _ScrollToTopOnReselectState();
}

class _ScrollToTopOnReselectState extends ConsumerState<ScrollToTopOnReselect> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toTop() {
    if (!_controller.hasClients || _controller.offset <= 0) return;
    if (KijiEffects.still(context)) {
      _controller.jumpTo(0);
    } else {
      _controller.animateTo(0, duration: KijiMotion.normal, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(shellTabReselectProvider(widget.tab), (_, _) => _toTop());
    return widget.builder(context, _controller);
  }
}
