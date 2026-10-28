import 'dart:async';

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/kiji_tokens.dart';

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
  // Grafito: la hoja es de vidrio esmerilado (la dibuja [FrostedSheet], con su barrita).
  final frosted = KijiLook.museum && backgroundColor == null;
  final handle = showDragHandle ?? Theme.of(context).bottomSheetTheme.showDragHandle ?? false;
  final future = showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: frosted ? false : showDragHandle,
    backgroundColor: frosted ? Colors.transparent : backgroundColor,
    elevation: frosted ? 0 : null,
    barrierColor: barrierColor,
    constraints: constraints,
    useSafeArea: useSafeArea,
    transitionAnimationController: controller,
    builder: (sheet) {
      final child = builder(sheet);
      return SheetDragToDismiss(
        controller: controller,
        child: frosted ? FrostedSheet(handle: handle, child: child) : child,
      );
    },
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

/// Hoja de Grafito: vidrio esmerilado (ahumado + blanco 7 %) con borde de 1 px blanco 10 %.
/// El desenfoque de lo que queda detrás solo va con alto rendimiento; sin él, el ahumado alcanza
/// para que se lea.
class FrostedSheet extends StatelessWidget {
  const FrostedSheet({super.key, required this.handle, required this.child});

  final bool handle;
  final Widget child;

  static const _radius = BorderRadius.vertical(top: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: KijiMuseum.pane,
        borderRadius: _radius,
        border: Border.all(color: KijiColors.glassBorder),
      ),
      // Material propio: los ListTile de adentro pintan aquí su fondo y su efecto al tocar (si no,
      // quedan detrás del vidrio).
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // La barrita, como la de Material (32 × 4, 22 px arriba y abajo).
            if (handle)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KijiColors.muted.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Flexible(child: child),
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: _radius,
      child: KijiEffects.rich ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: body) : body,
    );
  }
}
