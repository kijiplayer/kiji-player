import 'dart:async';

import 'package:flutter/material.dart';

/// Hoja que sube desde abajo, como [showModalBottomSheet], que además se cierra deslizando hacia
/// abajo desde cualquier parte: también sobre una lista, cuando la lista ya está arriba de todo.
/// El scroll de adentro sigue funcionando igual. Todas las hojas de Kiji se abren con esta.
Future<T?> showKijiSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  Color? backgroundColor,
  Color? barrierColor,
  BoxConstraints? constraints,
  bool useSafeArea = false,
}) {
  // Controlador propio: así el arrastre sobre la lista mueve la hoja igual que la barrita.
  final controller = BottomSheet.createAnimationController(Navigator.of(context));
  final future = showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    constraints: constraints,
    useSafeArea: useSafeArea,
    transitionAnimationController: controller,
    builder: (sheet) => SheetDragToDismiss(controller: controller, child: builder(sheet)),
  );
  // La ruta no libera un controlador ajeno: se libera cuando la hoja terminó de bajar.
  unawaited(
    future.whenComplete(() {
      void dispose() => WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
      if (controller.isDismissed) {
        dispose();
      } else {
        void onStatus(AnimationStatus status) {
          if (status != AnimationStatus.dismissed) return;
          controller.removeStatusListener(onStatus);
          dispose();
        }

        controller.addStatusListener(onStatus);
      }
    }),
  );
  return future;
}

/// Arrastre de la hoja desde cualquier parte de su contenido: lo que no es lista, y el "seguir
/// tirando hacia abajo" de una lista que ya está arriba de todo. Se cierra al bajarla un cuarto
/// (la de Material pide la mitad, y desde la mitad de una hoja alta el dedo llega antes al borde
/// de la pantalla) o con un deslizamiento rápido.
class SheetDragToDismiss extends StatefulWidget {
  const SheetDragToDismiss({super.key, required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  @override
  State<SheetDragToDismiss> createState() => _SheetDragToDismissState();
}

class _SheetDragToDismissState extends State<SheetDragToDismiss> {
  static const _flingVelocity = 400.0;
  static const _closeThreshold = 0.75;

  bool _dragging = false;

  double get _height => context.size?.height ?? 1;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final controller = widget.controller;
    if (n is OverscrollNotification && n.dragDetails != null && n.overscroll < 0) {
      // La lista ya está arriba y el dedo sigue bajando: baja la hoja.
      _dragging = true;
      controller.value += n.overscroll / _height;
    } else if (n is ScrollUpdateNotification && _dragging && n.dragDetails != null) {
      // Si vuelve a subir el dedo, la hoja sube primero.
      final delta = n.scrollDelta ?? 0;
      if (delta > 0 && controller.value < 1) controller.value += delta / _height;
    } else if (n is ScrollEndNotification && _dragging) {
      _dragging = false;
      _settle(n.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }
    return false;
  }

  void _settle(double velocity) {
    if (velocity > _flingVelocity || widget.controller.value < _closeThreshold) {
      Navigator.of(context).maybePop();
    } else if (velocity < -_flingVelocity || widget.controller.value < 1) {
      widget.controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Arrastre sobre lo que no es lista (títulos, botones, espacios). Una lista que se puede
    // desplazar se queda con el gesto y avisa por [_onScroll].
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (d) => widget.controller.value -= (d.primaryDelta ?? 0) / _height,
      onVerticalDragEnd: (d) => _settle(d.primaryVelocity ?? 0),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        // Física sin rebote (en todas las plataformas) para enterarse del "seguir tirando", y sin
        // el estiramiento de Android, que acá no tiene sentido: la que se mueve es la hoja.
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(physics: const ClampingScrollPhysics(), overscroll: false),
          child: widget.child,
        ),
      ),
    );
  }
}
