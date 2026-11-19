import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Reglas del "deslizar hacia arriba para ver la letra" del reproductor.
///
/// El gesto de Android para salir de la app (deslizar desde el borde de abajo) también es un
/// deslizar hacia arriba. Para no confundirlos, se ignora todo arrastre que empieza en la zona de
/// gestos del sistema y se pide un recorrido y una velocidad claros.
class LyricsSwipeRule {
  const LyricsSwipeRule({
    this.minDistance = 120,
    this.minVelocity = 700,
    this.edgeMargin = 24,
  });

  /// Recorrido mínimo hacia arriba, en píxeles lógicos.
  final double minDistance;

  /// Velocidad mínima hacia arriba al soltar, en píxeles lógicos por segundo.
  final double minVelocity;

  /// Margen extra sobre la zona de gestos del sistema, por si el dedo cae justo en el borde.
  final double edgeMargin;

  /// ¿Puede empezar un deslizar-para-letra en [start] (coordenadas de pantalla)?
  bool startsOutsideSystemGestures({
    required Offset start,
    required Size screen,
    required EdgeInsets systemGestureInsets,
    required EdgeInsets viewPadding,
  }) {
    final bottomZone = _max(systemGestureInsets.bottom, viewPadding.bottom) + edgeMargin;
    if (start.dy >= screen.height - bottomZone) return false;
    if (systemGestureInsets.left > 0 && start.dx <= systemGestureInsets.left) return false;
    if (systemGestureInsets.right > 0 && start.dx >= screen.width - systemGestureInsets.right) {
      return false;
    }
    return true;
  }

  /// ¿El arrastre terminado alcanza para abrir la letra?
  bool accepts({required double upwardDistance, required double upwardVelocity}) =>
      upwardDistance >= minDistance && upwardVelocity >= minVelocity;

  /// ¿El arrastre hacia abajo alcanza para cerrar el reproductor? Un recorrido largo (aunque sea
  /// lento) o uno corto y rápido, como en cualquier reproductor.
  bool acceptsDown({required double downwardDistance, required double downwardVelocity}) =>
      downwardDistance >= minDistance * 1.5 || (downwardDistance >= minDistance / 2 && downwardVelocity >= minVelocity);

  static double _max(double a, double b) => a > b ? a : b;
}

/// Envuelve el reproductor y llama a [onSwipeUp] solo con un deslizar hacia arriba claro que no
/// empezó en la zona de gestos del sistema ni mientras Kiji se iba a segundo plano. Hacia abajo
/// ([onSwipeDown]) el reproductor sigue al dedo y, al soltar, se cierra o vuelve a su lugar.
class LyricsSwipeDetector extends StatefulWidget {
  const LyricsSwipeDetector({
    super.key,
    required this.onSwipeUp,
    required this.child,
    this.onSwipeDown,
    this.rule = const LyricsSwipeRule(),
  });

  final VoidCallback onSwipeUp;

  /// Deslizar hacia abajo: cerrar el reproductor.
  final VoidCallback? onSwipeDown;
  final Widget child;
  final LyricsSwipeRule rule;

  @override
  State<LyricsSwipeDetector> createState() => _LyricsSwipeDetectorState();
}

class _LyricsSwipeDetectorState extends State<LyricsSwipeDetector>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Offset? _start;
  Offset? _last;

  /// Cuánto bajó el reproductor siguiendo al dedo (y su vuelta a 0 si no se cierra).
  late final AnimationController _drag = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    upperBound: double.infinity,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drag.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si Kiji deja de estar al frente a mitad del gesto, ese gesto era del sistema.
    if (state != AppLifecycleState.resumed) _reset();
  }

  void _reset() {
    _start = null;
    _last = null;
  }

  void _onStart(DragStartDetails details) {
    final media = MediaQuery.of(context);
    final ok = widget.rule.startsOutsideSystemGestures(
      start: details.globalPosition,
      screen: media.size,
      systemGestureInsets: media.systemGestureInsets,
      viewPadding: media.viewPadding,
    );
    _start = ok ? details.globalPosition : null;
    _last = _start;
  }

  void _onUpdate(DragUpdateDetails details) {
    final start = _start;
    if (start == null) return;
    _last = details.globalPosition;
    if (widget.onSwipeDown != null) _drag.value = (details.globalPosition.dy - start.dy).clamp(0, double.infinity);
  }

  void _settleBack() {
    if (_drag.value > 0) _drag.animateTo(0, curve: Curves.easeOutCubic);
  }

  void _onEnd(DragEndDetails details) {
    final start = _start;
    final last = _last;
    _reset();
    if (start == null || last == null) return _settleBack();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return _settleBack();
    final velocity = details.primaryVelocity ?? 0;
    final down = widget.onSwipeDown;
    if (down != null && widget.rule.acceptsDown(downwardDistance: last.dy - start.dy, downwardVelocity: velocity)) {
      down();
      return;
    }
    _settleBack();
    final accepted = widget.rule.accepts(
      upwardDistance: start.dy - last.dy,
      upwardVelocity: -velocity,
    );
    if (accepted) widget.onSwipeUp();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: _onStart,
      onVerticalDragUpdate: _onUpdate,
      onVerticalDragEnd: _onEnd,
      onVerticalDragCancel: () {
        _reset();
        _settleBack();
      },
      child: widget.onSwipeDown == null
          ? widget.child
          : AnimatedBuilder(
              animation: _drag,
              builder: (context, child) =>
                  Transform.translate(offset: Offset(0, _drag.value), child: child),
              child: widget.child,
            ),
    );
  }
}
