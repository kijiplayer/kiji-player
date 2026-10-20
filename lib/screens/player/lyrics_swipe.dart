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

  static double _max(double a, double b) => a > b ? a : b;
}

/// Envuelve el reproductor y llama a [onSwipeUp] solo con un deslizar hacia arriba claro que no
/// empezó en la zona de gestos del sistema ni mientras Kiji se iba a segundo plano.
class LyricsSwipeDetector extends StatefulWidget {
  const LyricsSwipeDetector({
    super.key,
    required this.onSwipeUp,
    required this.child,
    this.rule = const LyricsSwipeRule(),
  });

  final VoidCallback onSwipeUp;
  final Widget child;
  final LyricsSwipeRule rule;

  @override
  State<LyricsSwipeDetector> createState() => _LyricsSwipeDetectorState();
}

class _LyricsSwipeDetectorState extends State<LyricsSwipeDetector> with WidgetsBindingObserver {
  Offset? _start;
  Offset? _last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (_start != null) _last = details.globalPosition;
  }

  void _onEnd(DragEndDetails details) {
    final start = _start;
    final last = _last;
    _reset();
    if (start == null || last == null) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final accepted = widget.rule.accepts(
      upwardDistance: start.dy - last.dy,
      upwardVelocity: -(details.primaryVelocity ?? 0),
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
      onVerticalDragCancel: _reset,
      child: widget.child,
    );
  }
}
