import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/kiji_tokens.dart';

/// Alturas (0..1) de las barras de la onda para [seed] (el id de la canción).
/// Son siempre las mismas para la misma canción, sin analizar el audio:
/// es una firma visual, no un espectro real.
List<double> waveformBars(String seed, int count) {
  final random = Random(seed.hashCode);
  final bars = <double>[];
  var previous = 0.5;
  for (var i = 0; i < count; i++) {
    // Suavizado: cada barra se parece a la anterior, como una onda.
    final target = 0.2 + random.nextDouble() * 0.8;
    previous = previous * 0.45 + target * 0.55;
    // Las puntas (inicio y final) más bajas, como un fade.
    final edge = min(1.0, min(i, count - 1 - i) / 4 + 0.35);
    bars.add((previous * edge).clamp(0.12, 1.0));
  }
  return bars;
}

/// Barra de progreso como **forma de onda** (§7): barras finas; lo
/// reproducido en violeta → cian y lo que falta en blanco 16 %. Se toca o se
/// arrastra para buscar. Con [marker], una luna sobre la onda marca dónde se
/// va a pausar (temporizador "momento exacto", Tarea Z2).
class WaveformProgress extends StatefulWidget {
  const WaveformProgress({
    super.key,
    required this.seed,
    required this.progress,
    required this.onSeek,
    this.height = 44,
    this.barWidth = 3,
    this.gap = 2,
    this.marker,
    this.alive = false,
    this.animateIn = false,
  });

  final String seed;
  final double progress;
  final ValueChanged<double> onSeek;
  final double height;
  final double barWidth;
  final double gap;

  /// Fracción (0..1) donde va la luna, o null.
  final double? marker;

  /// Las barras se mueven suave (mientras suena, sin "Reducir animaciones").
  final bool alive;

  /// Se dibuja de izquierda a derecha al aparecer (Tarea Z6).
  final bool animateIn;

  @override
  State<WaveformProgress> createState() => _WaveformProgressState();
}

class _WaveformProgressState extends State<WaveformProgress> with TickerProviderStateMixin {
  double? _drag;
  late final AnimationController _reveal =
      AnimationController(vsync: this, duration: KijiMotion.waveReveal, value: widget.animateIn ? 0 : 1);
  late final AnimationController _live = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.animateIn) _reveal.forward();
    if (widget.alive) _live.repeat();
  }

  @override
  void didUpdateWidget(WaveformProgress old) {
    super.didUpdateWidget(old);
    if (old.seed != widget.seed && widget.animateIn) _reveal.forward(from: 0);
    if (widget.alive && !_live.isAnimating) {
      _live.repeat();
    } else if (!widget.alive && _live.isAnimating) {
      _live.stop();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _live.dispose();
    super.dispose();
  }

  double _fraction(Offset local, double width) => (local.dx / width).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = max(8, (width / (widget.barWidth + widget.gap)).floor());
        final bars = waveformBars(widget.seed, count);
        final progress = (_drag ?? widget.progress).clamp(0.0, 1.0);

        return Semantics(
          slider: true,
          label: 'Progreso de la canción',
          value: '${(progress * 100).round()} %',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => widget.onSeek(_fraction(details.localPosition, width)),
            onHorizontalDragStart: (details) =>
                setState(() => _drag = _fraction(details.localPosition, width)),
            onHorizontalDragUpdate: (details) =>
                setState(() => _drag = _fraction(details.localPosition, width)),
            onHorizontalDragEnd: (_) {
              final value = _drag;
              setState(() => _drag = null);
              if (value != null) widget.onSeek(value);
            },
            child: SizedBox(
              height: widget.height,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_reveal, _live]),
                      builder: (context, _) => CustomPaint(
                        painter: _WaveformPainter(
                          bars: bars,
                          progress: progress,
                          barWidth: widget.barWidth,
                          gap: widget.gap,
                          marker: widget.marker,
                          reveal: Curves.easeOutCubic.transform(_reveal.value),
                          phase: widget.alive ? _live.value : null,
                        ),
                      ),
                    ),
                  ),
                  if (widget.marker != null)
                    Positioned(
                      left: (widget.marker!.clamp(0.0, 1.0) * width) - 9,
                      top: -16,
                      child: const Icon(
                        Icons.bedtime_rounded,
                        key: Key('waveform-moon'),
                        size: 18,
                        color: KijiColors.cyan,
                        semanticLabel: 'Pausa del temporizador',
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.barWidth,
    required this.gap,
    this.marker,
    this.reveal = 1,
    this.phase,
  });

  final List<double> bars;

  /// Cuánto de la onda ya se dibujó (0..1, de izquierda a derecha).
  final double reveal;

  /// Fase (0..1) del movimiento suave de las barras, o null si están quietas.
  final double? phase;
  final double? marker;
  final double progress;
  final double barWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final played = Paint()
      ..shader = KijiColors.accentGradient.createShader(Offset.zero & size);
    final rest = Paint()..color = KijiColors.waveRest;
    final step = size.width / bars.length;
    final radius = Radius.circular(barWidth / 2);

    final visible = (bars.length * reveal).ceil();
    for (var i = 0; i < visible; i++) {
      final wobble = phase == null ? 1.0 : 0.88 + 0.12 * sin(2 * pi * (phase! + i / 14));
      final h = max(barWidth, bars[i] * wobble * size.height);
      final x = i * step + (step - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, (size.height - h) / 2, barWidth, h),
        radius,
      );
      canvas.drawRRect(rect, (i + 0.5) / bars.length <= progress ? played : rest);
    }
    final mark = marker;
    if (mark != null) {
      // Línea fina debajo de la luna.
      final x = mark.clamp(0.0, 1.0) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = KijiColors.cyan
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.bars != bars ||
      old.barWidth != barWidth ||
      old.marker != marker ||
      old.reveal != reveal ||
      old.phase != phase;
}
