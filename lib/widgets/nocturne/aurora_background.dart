import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/kiji_tokens.dart';

/// Fondo "aurora": manchas de luz con los colores de la portada que se mueven muy despacio (una
/// vuelta cada uno o dos minutos). Elegante y quieto a la vista; no distrae.
///
/// Se dibuja a baja resolución (es luz difusa: no se nota) y se estira con filtrado: en pantalla es
/// una sola imagen por cuadro. Pintarla a tamaño completo costaba ~10 ms por cuadro en el Motorola.
/// - Modo normal: 3 manchas, ~110 px de ancho, ~30 imágenes por segundo. Liviano.
/// - Modo alto rendimiento ([KijiEffects.rich]): 4 manchas con desenfoque real, partículas de luz
///   (a resolución completa), colores más intensos y cada cuadro de la pantalla (120 Hz si la
///   pantalla lo permite).
/// - "Reducir animaciones" o [moving] en false: queda quieto (se dibuja una vez).
/// - Con Kiji en segundo plano o la ventana oculta, no dibuja.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    required this.colors,
    this.moving = true,
    this.intensity = 1,
    this.fadeOut = false,
  });

  /// Dos o tres colores (los de la portada). Al cambiar, pasan de unos a otros en ~1 s.
  final List<Color> colors;
  final bool moving;

  /// 0..1: qué tan visible es (el reproductor, 1; el Inicio, menos).
  final double intensity;

  /// Se desvanece hasta el color del fondo abajo (una franja, como en el Inicio). Va pintado en la
  /// misma imagen: un ShaderMask encima costaba una capa más en cada cuadro.
  final bool fadeOut;

  /// Ancho (px) al que se dibuja la aurora antes de estirarla.
  @visibleForTesting
  static double renderWidth({required bool rich}) => rich ? 200 : 110;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late final AppLifecycleListener _lifecycle;

  /// Segundos de "tiempo de aurora": avanza solo mientras se mueve (al pausar no salta).
  final _time = ValueNotifier<double>(_seed);
  static final _seed = Random().nextDouble() * 600;
  Duration _lastTick = Duration.zero;
  Duration _lastPaint = Duration.zero;
  bool _visible = true;

  /// La aurora ya dibujada a baja resolución, y el tamaño en pantalla para el que se dibujó.
  ui.Image? _image;
  Size _size = Size.zero;

  /// Con qué modo y tema se dibujó (si cambian, se vuelve a dibujar aunque esté quieta).
  (bool, Color, double)? _drawnWith;
  final _version = ValueNotifier<int>(0);

  late List<Color> _from = _normalized(widget.colors);
  late List<Color> _to = _from;
  double _blend = 1;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _visible = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
        _sync();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AuroraBackground old) {
    super.didUpdateWidget(old);
    final next = _normalized(widget.colors);
    if (!_sameColors(next, _to)) {
      _from = _current();
      _to = next;
      _blend = KijiEffects.still(context) ? 1 : 0;
    }
    _sync();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker.dispose();
    _time.dispose();
    _version.dispose();
    _image?.dispose();
    super.dispose();
  }

  bool get _shouldRun =>
      KijiLook.nocturne && _visible && (widget.moving || _blend < 1) && !KijiEffects.still(context);

  void _sync() {
    if (_shouldRun && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _lastPaint = Duration.zero;
      _ticker.start();
    } else if (!_shouldRun && _ticker.isActive) {
      _ticker.stop();
      if (_blend < 1) _blend = 1;
      if (KijiLook.nocturne) _render(); // Un último cuadro con los colores finales.
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_blend < 1) _blend = min(1, _blend + dt / 1.1);
    if (widget.moving) _time.value += dt;
    // La aurora se mueve tan despacio que ~30 imágenes por segundo alcanzan, también en alto
    // rendimiento (redibujarla a cada cuadro bajaba a ~50 fps en la PC). Las partículas, sí a
    // cada cuadro.
    if (elapsed - _lastPaint >= const Duration(milliseconds: 33) || _blend < 1) {
      _lastPaint = elapsed;
      _render();
    } else if (KijiEffects.rich && widget.moving) {
      _version.value++;
    }
    if (!widget.moving && _blend >= 1) _ticker.stop();
  }

  List<Color> _current() => [
    for (var i = 0; i < 3; i++) Color.lerp(_from[i], _to[i], Curves.easeInOut.transform(_blend))!,
  ];

  static List<Color> _normalized(List<Color> colors) {
    final base = colors.isEmpty ? [KijiColors.violet, KijiColors.cyan] : colors;
    return [for (var i = 0; i < 3; i++) base[i % base.length]];
  }

  static bool _sameColors(List<Color> a, List<Color> b) =>
      a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

  void _render() {
    if (_size.isEmpty || !mounted) return;
    final rich = KijiEffects.rich;
    final scale = AuroraBackground.renderWidth(rich: rich) / _size.width;
    final small = Size((_size.width * scale).ceilToDouble(), max(8, (_size.height * scale).ceilToDouble()));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Alto rendimiento: desenfoque real, que funde las manchas como luz.
    if (rich) {
      canvas.saveLayer(
        Offset.zero & small,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4, tileMode: TileMode.clamp),
      );
    }
    _AuroraPainter.paintAurora(
      canvas,
      small,
      t: _time.value,
      palette: _current(),
      rich: rich,
      light: KijiColors.palette.isLight,
      intensity: widget.intensity,
      background: KijiColors.background,
      fadeOut: widget.fadeOut,
    );
    if (rich) canvas.restore();
    final picture = recorder.endRecording();
    final image = picture.toImageSync(small.width.toInt(), small.height.toInt());
    picture.dispose();
    _image?.dispose();
    _image = image;
    _drawnWith = (rich, KijiColors.background, widget.intensity);
    _version.value++;
  }

  @override
  Widget build(BuildContext context) {
    // Grafito y Papel no tienen aurora: queda el fondo liso del estilo.
    if (KijiLook.flat) {
      _sync();
      return const SizedBox.expand();
    }
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (size != _size ||
              _image == null ||
              _drawnWith != (KijiEffects.rich, KijiColors.background, widget.intensity)) {
            _size = size;
            _render();
          }
          return CustomPaint(
            painter: _AuroraPainter(
              image: () => _image,
              version: _version,
              time: _time,
              rich: KijiEffects.rich,
              palette: _current,
              light: KijiColors.palette.isLight,
              intensity: widget.intensity,
              background: KijiColors.background,
              fadeOut: widget.fadeOut,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.image,
    required ValueNotifier<int> version,
    required this.time,
    required this.rich,
    required this.palette,
    required this.light,
    required this.intensity,
    required this.background,
    required this.fadeOut,
  }) : super(repaint: version);

  final ui.Image? Function() image;
  final ValueNotifier<double> time;
  final bool rich;
  final List<Color> Function() palette;
  final bool light;
  final double intensity;
  final Color background;
  final bool fadeOut;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = image();
    if (frame == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
      return;
    }
    canvas.drawImageRect(
      frame,
      Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    if (rich) _particles(canvas, size, time.value, palette(), light, intensity, fadeOut);
  }

  /// Recorridos de cada mancha: velocidades muy bajas (rad/s) y fases distintas.
  static const _paths = [
    (sx: 0.051, sy: 0.037, px: 0.0, py: 1.3, ax: 0.32, ay: 0.20, cy: 0.28, r: 0.62),
    (sx: 0.043, sy: 0.059, px: 2.1, py: 0.4, ax: 0.36, ay: 0.24, cy: 0.42, r: 0.55),
    (sx: 0.067, sy: 0.031, px: 4.2, py: 2.6, ax: 0.30, ay: 0.22, cy: 0.62, r: 0.50),
    (sx: 0.029, sy: 0.047, px: 1.1, py: 3.7, ax: 0.40, ay: 0.18, cy: 0.18, r: 0.42),
  ];

  /// La aurora en sí (manchas y velo), en [canvas] de [size].
  static void paintAurora(
    Canvas canvas,
    Size size, {
    required double t,
    required List<Color> palette,
    required bool rich,
    required bool light,
    required double intensity,
    required Color background,
    bool fadeOut = false,
  }) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final side = size.longestSide;
    final strength = (light ? 0.30 : 0.46) * intensity * (rich ? 1.15 : 1);
    final count = rich ? 4 : 3;
    for (var i = 0; i < count; i++) {
      final p = _paths[i];
      final color = _vivid(palette[i % palette.length], rich, light);
      final center = Offset(
        size.width * (0.5 + p.ax * sin(t * p.sx + p.px)),
        size.height * (p.cy + p.ay * cos(t * p.sy + p.py)),
      );
      // Respira apenas: ±8 % de tamaño.
      final radius = side * p.r * (1 + 0.08 * sin(t * (p.sx + p.sy) + i));
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..blendMode = light ? BlendMode.multiply : BlendMode.screen
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: strength),
              color.withValues(alpha: strength * 0.35),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(rect),
      );
    }
    // Abajo, un velo del color del fondo: los textos y botones se leen siempre bien.
    final veil = Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.65);
    canvas.drawRect(
      veil,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            background.withValues(alpha: 0),
            background.withValues(alpha: fadeOut ? 1 : 0.7),
          ],
        ).createShader(veil),
    );
  }

  /// Partículas de luz que suben muy despacio (solo en alto rendimiento).
  static void _particles(
    Canvas canvas,
    Size size,
    double t,
    List<Color> palette,
    bool light,
    double intensity,
    bool fadeOut,
  ) {
    // Sin MaskFilter: 28 desenfoques por cuadro a 120 Hz se notaban. Un halo tenue alrededor de
    // cada punto da el mismo brillo suave.
    final paint = Paint();
    for (var i = 0; i < 28; i++) {
      final seed = i * 12.9898;
      final x = (sin(seed) * 43758.5453).abs() % 1;
      final speed = 0.004 + (cos(seed) * 0.5 + 0.5) * 0.006;
      final y = 1 - ((t * speed + x * 3.7) % 1);
      final twinkle = 0.5 + 0.5 * sin(t * 0.8 + seed);
      final alpha = (light ? 0.25 : 0.45) * twinkle * intensity * (fadeOut ? 1 - y : 1);
      final center = Offset(size.width * (x + 0.03 * sin(t * 0.2 + seed)), size.height * y);
      final radius = 1.2 + 1.6 * ((seed * 7) % 1);
      final color = palette[i % palette.length];
      canvas.drawCircle(center, radius * 2.4, paint..color = color.withValues(alpha: alpha * 0.25));
      canvas.drawCircle(center, radius, paint..color = color.withValues(alpha: alpha));
    }
  }

  /// Luz de color, nunca blanca: la luminosidad queda en un rango medio (si no, una carátula clara
  /// lava todo el fondo). En alto rendimiento, además, los colores más intensos.
  static Color _vivid(Color color, bool rich, bool light) {
    final hsl = HSLColor.fromColor(color);
    final lightness = light ? hsl.lightness.clamp(0.45, 0.75) : hsl.lightness.clamp(0.3, 0.6);
    final saturation = rich ? min(1.0, hsl.saturation * 1.3) : hsl.saturation;
    return hsl.withSaturation(saturation).withLightness(lightness).toColor();
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.rich != rich || old.intensity != intensity;
}
