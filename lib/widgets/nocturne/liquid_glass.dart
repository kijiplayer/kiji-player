import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as lgr;

import '../../theme/kiji_tokens.dart';
import 'real_glass.dart';

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

/// La superficie del vidrio líquido. [child] va encima. Al apretarlo "se hunde" (y vuelve con un
/// rebote suave); con "reducir animaciones", quieto.
class LiquidGlass extends StatefulWidget {
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
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> with SingleTickerProviderStateMixin {
  late final _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
    reverseDuration: const Duration(milliseconds: 260),
  );
  Offset? _down;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _release() {
    _down = null;
    // También si recién empezaba a hundirse (si no, quedaba hundido).
    if (_press.value > 0 || _press.isAnimating) unawaited(_press.reverse());
  }

  @override
  Widget build(BuildContext context) {
    // Papel es papel (no vidrio): siempre la superficie de siempre.
    if (KijiLook.style == KijiStyle.paper) return _classic(context);
    return ValueListenableBuilder<bool>(
      valueListenable: RealGlass.active,
      builder: (context, real, _) => real ? _real(context) : _classic(context),
    );
  }

  /// Al apretar se hunde; si el dedo se mueve (está deslizando), vuelve enseguida.
  Widget _pressable({required bool still, required Widget child}) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: still
        ? null
        : (event) {
            _down = event.position;
            unawaited(_press.forward());
          },
    onPointerMove: (event) {
      final down = _down;
      if (down != null && (event.position - down).distance > 10) _release();
    },
    onPointerUp: (_) => _release(),
    onPointerCancel: (_) => _release(),
    child: child,
  );

  /// Vidrio real (0.9): transparente, con refracción de verdad en el borde, filo de luz y un poco
  /// de arcoíris; el tinte del estilo encima. Las tarjetas comparten una sola copia del fondo por
  /// cuadro (`BackdropGroup` de la app); lo flotante (barra, mini-reproductor, hojas) toma la suya,
  /// para refractar lo que pasa por debajo.
  Widget _real(BuildContext context) {
    final still = KijiEffects.still(context);
    final floating = widget.kind == GlassKind.floating;
    final palette = KijiColors.palette;
    final graphite = KijiLook.style == KijiStyle.graphite;
    // El mismo tinte del vidrio de siempre (Nocturne: el acento; Grafito: un velo frío).
    var tint = graphite
        ? const Color(0x1FF2F4F8)
        : Color.lerp(palette.violet.withValues(alpha: 0.11), palette.cyan.withValues(alpha: 0.07), 0.5)!;
    if (widget.fill case final fill?) tint = Color.alphaBlend(fill, tint);
    // Lo flotante pasa por encima de contenido que se mueve: una base del fondo, para que se lea.
    if (floating) tint = Color.alphaBlend(tint, palette.background.withValues(alpha: 0.45));
    final radius = widget.borderRadius.topLeft.x;
    final glass = lgr.LiquidGlass.withOwnLayer(
      shape: lgr.LiquidRoundedSuperellipse(borderRadius: radius),
      useBackdropGroup: !floating,
      settings: lgr.LiquidGlassSettings(
        refractionHeight: math.min(18, radius + 6),
        refractionAmount: 44,
        refractionFitsShape: true,
        frost: floating ? 12 : 7,
        dispersion: 0.5,
        highlight: 1,
      ),
      appearance: lgr.LiquidGlassAppearance(tint: tint),
      shadows: [
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, graphite ? 0.30 : 0.24),
          offset: Offset(0, floating ? 6 : 4),
          blurRadius: floating ? 16 : 12,
        ),
      ],
      child: widget.child,
    );
    final vertical = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    final horizontal = Scrollable.maybeOf(context, axis: Axis.horizontal)?.position;
    final rimmed = _RealGlassRim(
      borderRadius: widget.borderRadius,
      edge: RenderLiquidGlass.glassLook(KijiLook.style, palette).edge,
      border: widget.border,
      still: still,
      repaint: Listenable.merge([?vertical, ?horizontal]),
      child: glass,
    );
    return _pressable(
      still: still,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          final press = still ? 0.0 : _press.value.clamp(0.0, 1.2);
          return press == 0 ? child! : Transform.scale(scale: 1 - 0.022 * press, child: child);
        },
        child: rimmed,
      ),
    );
  }

  /// El vidrio de siempre (0.8.3): el fondo ya desenfocado, sin copias de la pantalla.
  Widget _classic(BuildContext context) {
    final backdrop = GlassBackdrop.maybeOf(context);
    final vertical = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    final horizontal = Scrollable.maybeOf(context, axis: Axis.horizontal)?.position;
    final still = KijiEffects.still(context);
    return _pressable(
      still: still,
      child: _LiquidGlassBox(
        borderRadius: widget.borderRadius,
        kind: widget.kind,
        style: KijiLook.style,
        palette: KijiColors.palette,
        fill: widget.fill,
        border: widget.border,
        still: still,
        backdrop: backdrop,
        press: _press,
        repaint: Listenable.merge([?backdrop, ?vertical, ?horizontal, _press]),
        child: widget.child,
      ),
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
    required this.press,
    required this.repaint,
    super.child,
  });

  final ValueListenable<double> press;
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
    press: press,
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
      ..press = press
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
    required this._press,
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

  /// Cuánto está hundido ahora (para las pruebas): 0 suelto, 1 apretado.
  @visibleForTesting
  double get debugPress => _still ? 0 : _press.value;

  /// 0 suelto, 1 apretado: el vidrio "se hunde" (se achica apenas y se oscurece).
  ValueListenable<double> _press;
  set press(ValueListenable<double> value) {
    if (identical(value, _press)) return;
    _press = value;
    markNeedsPaint();
  }

  ({List<Color> tint, List<Color> edge, Color spec, Color shadow, double shadowAlpha}) get _look =>
      glassLook(_style, _palette);

  /// Los colores del vidrio según el estilo (y el acento, en Nocturne).
  static ({List<Color> tint, List<Color> edge, Color spec, Color shadow, double shadowAlpha}) glassLook(
    KijiStyle style,
    KijiPalette palette,
  ) {
    switch (style) {
      case KijiStyle.nocturne:
        // El vidrio toma el acento: violeta → cian de fábrica, o el que se haya elegido.
        return (
          tint: [palette.violet.withValues(alpha: 0.11), palette.cyan.withValues(alpha: 0.07)],
          edge: [
            const Color(0xCCFFFFFF),
            palette.violet.withValues(alpha: 0.55),
            palette.cyan.withValues(alpha: 0.45),
            const Color(0x1FFFFFFF),
          ],
          spec: const Color(0x30FFFFFF),
          shadow: const Color(0xFF000000),
          shadowAlpha: 0.28,
        );
      case KijiStyle.graphite:
        // Vidrio ahumado de museo: frío, sin color, con un filo blanco nítido.
        return (
          // Vidrio esmerilado: un velo blanco frío apenas (antes, un 44 % de negro: panel oscuro).
          tint: [const Color(0x1FF2F4F8), const Color(0x0FDDE2EA)],
          edge: [const Color(0xE6FFFFFF), const Color(0x24FFFFFF), const Color(0x0FFFFFFF), const Color(0x52FFFFFF)],
          spec: const Color(0x1FFFFFFF),
          shadow: const Color(0xFF000000),
          shadowAlpha: 0.34,
        );
      case KijiStyle.paper:
        // Papel translúcido cálido, con el borde de tinta y terracota.
        return (
          tint: [const Color(0xF8FFFFFF), const Color(0xF2FCFAF5)],
          edge: [const Color(0x8CB4462B), const Color(0x2E1C1A17), const Color(0x14B4462B), const Color(0x592A241D)],
          spec: const Color(0x8CFFFFFF),
          shadow: const Color(0xFF5A3A22),
          shadowAlpha: 0.14,
        );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final look = _look;
    final floating = _kind == GlassKind.floating;
    final paper = _style == KijiStyle.paper;
    final global = localToGlobal(Offset.zero) & size;
    // Dónde está en la pantalla (0 arriba, 1 abajo): mueve el reflejo y el borde de luz al deslizar.
    final screen = _screenHeight;
    final t = _still || screen <= 0 ? 0.3 : (global.center.dy / screen).clamp(0.0, 1.0);
    final press = _still ? 0.0 : _press.value.clamp(0.0, 1.2);

    canvas.save();
    if (press > 0) {
      // Se hunde: un poco más chico desde el centro.
      final center = (offset & size).center;
      final scale = 1 - 0.022 * press;
      canvas
        ..translate(center.dx, center.dy)
        ..scale(scale)
        ..translate(-center.dx, -center.dy);
    }
    final rect = offset & size;
    final rrect = _borderRadius.toRRect(rect);

    // Profundidad: sombra suave debajo (al hundirse, más corta). Impeller la dibuja sin capas.
    canvas.drawRRect(
      rrect.shift(Offset(0, (floating ? 7 : 5) * (1 - 0.6 * press))),
      Paint()
        ..color = look.shadow.withValues(alpha: look.shadowAlpha * (floating ? 1.2 : 1) * (1 - 0.4 * press))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, floating ? 16 : 12),
    );

    canvas.save();
    canvas.clipRRect(rrect);
    if (floating) {
      // Encima de contenido que se mueve: primero el fondo del estilo, casi opaco.
      canvas.drawRect(rect, Paint()..color = _palette.background.withValues(alpha: paper || _style == KijiStyle.graphite ? 0.98 : 0.97));
    }
    // Lo de detrás, ya desenfocado (sin desenfocar nada en este cuadro).
    final layers = _backdrop?.layers ?? const <GlassLayer>[];
    const layerAlpha = 1.0;
    for (final layer in layers) {
      _drawLayer(canvas, layer, global, offset, global, layerAlpha);
    }

    // Refracción en los bordes: el fondo, un poco ampliado (como una lente), en un anillo fino.
    // Se rellena el anillo directo (drawDRRect con la imagen como sombreador): sin recortes con
    // caminos, que en Impeller cuestan.
    final rim = (size.shortestSide * 0.16).clamp(6.0, 14.0);
    final inner = rrect.deflate(rim);
    if (layers.isNotEmpty) {
      // La lente: lo que hay detrás del centro del vidrio, estirado hasta el borde.
      const zoom = 1.09;
      for (final layer in layers) {
        final sx = layer.image.width / layer.rect.width;
        final sy = layer.image.height / layer.rect.height;
        // Píxel de la imagen → punto global → punto ampliado desde el centro del vidrio → lienzo.
        final c = global.center;
        final matrix = Matrix4.identity()
          ..translateByDouble(offset.dx - global.left + c.dx * (1 - zoom), offset.dy - global.top + c.dy * (1 - zoom), 0, 1)
          ..scaleByDouble(zoom, zoom, 1, 1)
          ..translateByDouble(layer.rect.left, layer.rect.top, 0, 1)
          ..scaleByDouble(1 / sx, 1 / sy, 1, 1);
        canvas.drawDRRect(
          rrect,
          inner,
          Paint()
            ..shader = ImageShader(layer.image, TileMode.clamp, TileMode.clamp, matrix.storage, filterQuality: FilterQuality.medium)
            ..color = const Color.fromRGBO(0, 0, 0, layerAlpha * 0.9),
        );
      }
    }
    // El tinte del estilo (y del acento) y la profundidad (luz arriba, sombra abajo; al hundirse,
    // más sombra), en una sola pasada.
    final shade = Color.fromRGBO(0, 0, 0, (paper ? 0.03 : 0.05) + 0.1 * press);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
          Color.alphaBlend(Color.fromRGBO(255, 255, 255, paper ? 0.18 : 0.06), look.tint.first),
          Color.lerp(look.tint.first, look.tint.last, 0.5)!,
          Color.alphaBlend(shade, look.tint.last),
        ], const [0, 0.42, 1]),
    );
    if (_fill case final fill?) canvas.drawRect(rect, Paint()..color = fill);

    // Brillo especular: un punto de luz suave que sigue el deslizamiento (solo en su zona).
    final spot = Offset(rect.left + rect.width * (0.18 + 0.64 * (1 - t)), rect.top + rect.height * 0.12);
    final spotRadius = math.max(rect.width, rect.height) * 0.55;
    canvas.drawRect(
      Rect.fromCircle(center: spot, radius: spotRadius).intersect(rect),
      Paint()
        ..shader = ui.Gradient.radial(spot, spotRadius, [
          look.spec.withValues(alpha: look.spec.a * (1 - 0.5 * press)),
          look.spec.withValues(alpha: 0),
        ]),
    );
    // Y una franja diagonal que cruza el vidrio al deslizar (solo donde está).
    final band = rect.width * 0.7;
    final startX = rect.left - band + (rect.width + band) * (1 - t);
    final bandRect = Rect.fromLTRB(startX - band * 0.6, rect.top, startX + band * 1.6, rect.bottom).intersect(rect);
    if (!bandRect.isEmpty && bandRect.width > 0) {
      canvas.drawRect(
        bandRect,
        Paint()
          ..shader = ui.Gradient.linear(Offset(startX, rect.top), Offset(startX + band, rect.top + band * 0.55), [
            look.spec.withValues(alpha: 0),
            look.spec.withValues(alpha: look.spec.a * 0.55),
            look.spec.withValues(alpha: 0),
          ], const [0, 0.5, 1]),
      );
    }
    canvas.restore();

    paintGlassRim(canvas, rect, rrect, edge: look.edge, t: t, border: _border, paper: paper);
    canvas.restore();
    // El contenido, hundido igual que el vidrio (con su propia transformación: al pintarlo, el
    // lienzo puede cambiar, así que no se toca el de arriba).
    if (press > 0) {
      // pushTransform toma la matriz relativa a [offset]: el centro es el del vidrio, en local.
      final center = size.center(Offset.zero);
      final scale = 1 - 0.022 * press;
      final matrix = Matrix4.identity()
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);
      context.pushTransform(needsCompositing, offset, matrix, super.paint);
      return;
    }
    super.paint(context, offset);
  }

  /// Dibuja la parte de [layer] que cae en [source] (coordenadas globales) sobre el vidrio, que está
  /// en [global] (y en [offset] dentro del lienzo).
  void _drawLayer(Canvas canvas, GlassLayer layer, Rect source, Offset offset, Rect global, double alpha) {
    final hit = source.intersect(layer.rect);
    if (hit.isEmpty || hit.width <= 0 || hit.height <= 0) return;
    final sx = layer.image.width / layer.rect.width;
    final sy = layer.image.height / layer.rect.height;
    final src = Rect.fromLTWH((hit.left - layer.rect.left) * sx, (hit.top - layer.rect.top) * sy, hit.width * sx, hit.height * sy);
    // Dónde va: la parte de [source] que se ve, estirada sobre el vidrio.
    final fx = global.width / source.width;
    final fy = global.height / source.height;
    final dst = Rect.fromLTWH(
      offset.dx + (hit.left - source.left) * fx,
      offset.dy + (hit.top - source.top) * fy,
      hit.width * fx,
      hit.height * fy,
    );
    canvas.drawImageRect(
      layer.image,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, alpha),
    );
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

/// El borde de luz del vidrio (el mismo en el de siempre y en el real): el ángulo de la luz gira
/// con la posición en la pantalla ([t]: 0 arriba, 1 abajo) y un filo interior arriba.
void paintGlassRim(
  Canvas canvas,
  Rect rect,
  RRect rrect, {
  required List<Color> edge,
  required double t,
  Color? border,
  bool paper = false,
}) {
  final angle = -math.pi * 0.75 + math.pi * 0.5 * t;
  final radius = rect.longestSide / 2;
  final dir = Offset(math.cos(angle), math.sin(angle)) * radius;
  canvas.drawRRect(
    rrect.deflate(0.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = paper ? 1 : 1.2
      ..shader = border != null
          ? null
          : ui.Gradient.linear(rect.center + dir, rect.center - dir, edge, const [0, 0.35, 0.7, 1])
      ..color = border ?? const Color(0xFFFFFFFF),
  );
  if (!paper) {
    canvas.drawRRect(
      rrect.deflate(1.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(rect.topCenter, rect.center, [const Color(0x29FFFFFF), const Color(0x00FFFFFF)]),
    );
  }
}

/// Encima del vidrio real: el mismo borde de luz del vidrio de siempre (el diseño no cambia).
class _RealGlassRim extends SingleChildRenderObjectWidget {
  const _RealGlassRim({
    required this.borderRadius,
    required this.edge,
    required this.border,
    required this.still,
    required this.repaint,
    super.child,
  });

  final BorderRadius borderRadius;
  final List<Color> edge;
  final Color? border;
  final bool still;
  final Listenable repaint;

  @override
  _RenderRealGlassRim createRenderObject(BuildContext context) =>
      _RenderRealGlassRim(borderRadius, edge, border, still, repaint);

  @override
  void updateRenderObject(BuildContext context, _RenderRealGlassRim renderObject) {
    renderObject
      ..borderRadius = borderRadius
      ..edge = edge
      ..border = border
      ..still = still
      ..repaint = repaint;
  }
}

class _RenderRealGlassRim extends RenderProxyBox {
  _RenderRealGlassRim(this._borderRadius, this._edge, this._border, this._still, this._repaint);

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius v) {
    if (v == _borderRadius) return;
    _borderRadius = v;
    markNeedsPaint();
  }

  List<Color> _edge;
  set edge(List<Color> v) {
    if (listEquals(v, _edge)) return;
    _edge = v;
    markNeedsPaint();
  }

  Color? _border;
  set border(Color? v) {
    if (v == _border) return;
    _border = v;
    markNeedsPaint();
  }

  bool _still;
  set still(bool v) {
    if (v == _still) return;
    _still = v;
    markNeedsPaint();
  }

  Listenable _repaint;
  set repaint(Listenable v) {
    if (identical(v, _repaint)) return;
    if (attached) {
      _repaint.removeListener(markNeedsPaint);
      v.addListener(markNeedsPaint);
    }
    _repaint = v;
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

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final screen = views.isEmpty ? 0.0 : views.first.physicalSize.height / views.first.devicePixelRatio;
    final global = localToGlobal(Offset.zero) & size;
    final t = _still || screen <= 0 ? 0.3 : (global.center.dy / screen).clamp(0.0, 1.0);
    final rect = offset & size;
    paintGlassRim(context.canvas, rect, _borderRadius.toRRect(rect), edge: _edge, t: t, border: _border);
  }
}

