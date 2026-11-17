import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/kiji_tokens.dart';

/// "Liquid glass" (0.8.3): el vidrio de Kiji sin un desenfoque por tarjeta.
///
/// Antes cada vidrio desenfocaba en vivo lo que tenía detrás (`BackdropFilter`), en cada cuadro:
/// a 120 Hz, Inicio y Búsqueda no entraban en los 8,3 ms. Ahora cada pantalla con un fondo propio
/// (la foto, la aurora de Inicio) lo publica UNA vez ya desenfocado en un [GlassBackdrop], y cada
/// vidrio dibuja su recorte de esa imagen (lo mismo que se vería detrás, desenfocado), más el
/// tinte del estilo, un borde de luz fino, un reflejo que se corre al deslizar y una sombra suave.
/// Sin fondo publicado (un fondo liso), el vidrio deja ver el fondo liso: desenfocar un color liso
/// da el mismo color.

/// Una imagen ya desenfocada y dónde está en la pantalla (coordenadas globales, en px lógicos).
@immutable
class GlassLayer {
  const GlassLayer(this.image, this.rect);

  final ui.Image image;
  final Rect rect;
}

/// Lo que hay detrás de los vidrios de un subárbol, por capas (abajo la foto, encima la aurora).
class GlassBackdropController extends ChangeNotifier {
  final _layers = <String, GlassLayer>{};

  /// En orden: primero la de [order] más bajo.
  static const order = ['photo', 'aurora'];

  List<GlassLayer> get layers => [
    for (final key in order)
      ?_layers[key],
  ];

  bool get isEmpty => _layers.isEmpty;

  /// Pone (o cambia) la capa [key]. La imagen anterior la suelta quien la creó.
  void set(String key, GlassLayer layer) {
    _layers[key] = layer;
    notifyListeners();
  }

  void remove(String key) {
    if (_layers.remove(key) != null) notifyListeners();
  }
}

/// Reparte el [GlassBackdropController] a los vidrios de abajo.
/// Un InheritedWidget común (no InheritedNotifier): las capas cambian durante el build (la aurora
/// se dibuja ahí) y los vidrios solo tienen que repintar, no reconstruirse.
class GlassBackdrop extends InheritedWidget {
  const GlassBackdrop({super.key, required this.controller, required super.child});

  final GlassBackdropController controller;

  /// El del subárbol, sin suscribirse (los vidrios repintan por su cuenta).
  static GlassBackdropController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GlassBackdrop>()?.controller;

  @override
  bool updateShouldNotify(GlassBackdrop oldWidget) => !identical(controller, oldWidget.controller);
}

/// Crea (y suelta) el [GlassBackdropController] de una pantalla con fondo propio.
class GlassBackdropHost extends StatefulWidget {
  const GlassBackdropHost({super.key, required this.child});

  final Widget child;

  @override
  State<GlassBackdropHost> createState() => _GlassBackdropHostState();
}

class _GlassBackdropHostState extends State<GlassBackdropHost> {
  final _controller = GlassBackdropController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassBackdrop(controller: _controller, child: widget.child);
}

/// Cómo se ve un vidrio.
enum GlassKind {
  /// Tarjeta sobre el fondo: deja ver el fondo (ya desenfocado).
  card,

  /// Encima de contenido que se mueve (barra, mini-reproductor, hojas): con una base más opaca,
  /// para que lo de abajo nunca se cruce con lo de arriba.
  floating,
}

/// La superficie del vidrio líquido. [child] va encima.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    required this.borderRadius,
    this.kind = GlassKind.card,
    this.fill,
    this.border,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final GlassKind kind;

  /// El tinte (de fábrica, el del estilo).
  final Color? fill;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final backdrop = GlassBackdrop.maybeOf(context);
    final vertical = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    final horizontal = Scrollable.maybeOf(context, axis: Axis.horizontal)?.position;
    return _LiquidGlassBox(
      borderRadius: borderRadius,
      kind: kind,
      style: KijiLook.style,
      palette: KijiColors.palette,
      fill: fill,
      border: border,
      still: KijiEffects.still(context),
      backdrop: backdrop,
      repaint: Listenable.merge([?backdrop, ?vertical, ?horizontal]),
      child: child,
    );
  }
}

class _LiquidGlassBox extends SingleChildRenderObjectWidget {
  const _LiquidGlassBox({
    required this.borderRadius,
    required this.kind,
    required this.style,
    required this.palette,
    required this.fill,
    required this.border,
    required this.still,
    required this.backdrop,
    required this.repaint,
    super.child,
  });

  final BorderRadius borderRadius;
  final GlassKind kind;
  final KijiStyle style;
  final KijiPalette palette;
  final Color? fill;
  final Color? border;
  final bool still;
  final GlassBackdropController? backdrop;
  final Listenable repaint;

  @override
  RenderLiquidGlass createRenderObject(BuildContext context) => RenderLiquidGlass(
    borderRadius: borderRadius,
    kind: kind,
    style: style,
    palette: palette,
    fill: fill,
    border: border,
    still: still,
    backdrop: backdrop,
    repaint: repaint,
  );

  @override
  void updateRenderObject(BuildContext context, RenderLiquidGlass renderObject) {
    renderObject
      ..borderRadius = borderRadius
      ..kind = kind
      ..style = style
      ..palette = palette
      ..fill = fill
      ..border = border
      ..still = still
      ..backdrop = backdrop
      ..repaint = repaint;
  }
}

/// Dibuja el vidrio: sombra, recorte del fondo desenfocado, tinte, profundidad, reflejo y borde.
class RenderLiquidGlass extends RenderProxyBox {
  RenderLiquidGlass({
    required this._borderRadius,
    required this._kind,
    required this._style,
    required this._palette,
    required this._fill,
    required this._border,
    required this._still,
    required this._backdrop,
    required this._repaint,
  });

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  GlassKind _kind;
  set kind(GlassKind value) {
    if (value == _kind) return;
    _kind = value;
    markNeedsPaint();
  }

  KijiStyle _style;
  set style(KijiStyle value) {
    if (value == _style) return;
    _style = value;
    markNeedsPaint();
  }

  KijiPalette _palette;
  set palette(KijiPalette value) {
    if (identical(value, _palette)) return;
    _palette = value;
    markNeedsPaint();
  }

  Color? _fill;
  set fill(Color? value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsPaint();
  }

  Color? _border;
  set border(Color? value) {
    if (value == _border) return;
    _border = value;
    markNeedsPaint();
  }

  bool _still;
  set still(bool value) {
    if (value == _still) return;
    _still = value;
    markNeedsPaint();
  }

  GlassBackdropController? _backdrop;
  set backdrop(GlassBackdropController? value) {
    if (identical(value, _backdrop)) return;
    _backdrop = value;
    markNeedsPaint();
  }

  Listenable _repaint;
  set repaint(Listenable value) {
    if (identical(value, _repaint)) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  /// Papel: superficie sólida de papel (no es vidrio).
  bool get _paper => _style == KijiStyle.paper;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final rrect = _borderRadius.toRRect(rect);
    if (_paper) {
      canvas.drawRRect(rrect, Paint()..color = _fill ?? _palette.glassFill);
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _border ?? _palette.glassBorder,
      );
      super.paint(context, offset);
      return;
    }
    final museum = _style == KijiStyle.graphite;
    final floating = _kind == GlassKind.floating;

    // Profundidad: una sombra suave debajo (un rectángulo redondeado con blur: Impeller lo dibuja
    // sin capas, es barato).
    canvas.drawRRect(
      rrect.shift(Offset(0, floating ? 6 : 4)),
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, floating ? 0.32 : 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, floating ? 14 : 10),
    );

    canvas.save();
    canvas.clipRRect(rrect);
    // Lo de detrás, ya desenfocado: el recorte de cada capa publicada que cae bajo este vidrio.
    final global = localToGlobal(Offset.zero) & size;
    if (floating) {
      // Encima de contenido que se mueve: primero el fondo del estilo, casi opaco.
      canvas.drawRect(rect, Paint()..color = _palette.background.withValues(alpha: museum ? 0.9 : 0.86));
    }
    final layers = _backdrop?.layers ?? const <GlassLayer>[];
    for (final layer in layers) {
      final hit = global.intersect(layer.rect);
      if (hit.isEmpty || hit.width <= 0 || hit.height <= 0) continue;
      final sx = layer.image.width / layer.rect.width;
      final sy = layer.image.height / layer.rect.height;
      final src = Rect.fromLTWH(
        (hit.left - layer.rect.left) * sx,
        (hit.top - layer.rect.top) * sy,
        hit.width * sx,
        hit.height * sy,
      );
      final dst = hit.shift(offset - global.topLeft);
      canvas.drawImageRect(
        layer.image,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(0, 0, 0, floating ? 0.55 : 1),
      );
    }

    // El tinte del estilo.
    canvas.drawRect(rect, Paint()..color = _fill ?? (museum ? KijiMuseum.pane.withValues(alpha: 0.42) : _palette.glassFill));

    // Profundidad: arriba un poco de luz, abajo un poco de sombra (como un vidrio grueso).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
          Color.fromRGBO(255, 255, 255, museum ? 0.05 : 0.07),
          const Color.fromRGBO(255, 255, 255, 0),
          Color.fromRGBO(0, 0, 0, museum ? 0.14 : 0.1),
        ], const [0, 0.45, 1]),
    );

    // Reflejo: una franja diagonal de luz que se corre con la posición en la pantalla (al deslizar
    // se mueve, como la luz en un vidrio). Con "reducir animaciones", quieta.
    final screen = _screenHeight;
    final t = _still || screen <= 0 ? 0.3 : (global.center.dy / screen).clamp(0.0, 1.0);
    final band = rect.width * 0.9;
    final startX = rect.left - band + (rect.width + band) * (1 - t);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(startX, rect.top),
          Offset(startX + band, rect.top + band * 0.6),
          [
            const Color.fromRGBO(255, 255, 255, 0),
            Color.fromRGBO(255, 255, 255, museum ? 0.06 : 0.09),
            const Color.fromRGBO(255, 255, 255, 0),
          ],
          const [0, 0.5, 1],
        ),
    );
    canvas.restore();

    // Borde de luz fino: más brillante arriba a la izquierda, casi nada abajo a la derecha.
    final edge = _border;
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = edge != null
            ? null
            : ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
                Color.fromRGBO(255, 255, 255, museum ? 0.34 : 0.42),
                Color.fromRGBO(255, 255, 255, museum ? 0.08 : 0.1),
                Color.fromRGBO(255, 255, 255, museum ? 0.16 : 0.2),
              ], const [0, 0.55, 1])
        ..color = edge ?? const Color(0xFFFFFFFF),
    );
    super.paint(context, offset);
  }

  double get _screenHeight {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 0;
    final view = views.first;
    return view.physicalSize.height / view.devicePixelRatio;
  }

  /// La sombra sale un poco del vidrio: que no la recorte el límite de pintado.
  @override
  Rect get paintBounds => (Offset.zero & size).inflate(16);
}
