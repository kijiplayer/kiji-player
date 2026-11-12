import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/appearance_provider.dart';
import '../../../theme/kiji_tokens.dart';
import 'theater_effects.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// El escenario sobre la portada del reproductor:
///  - 🍅: tomates de varias formas que vuelan en arco, se estrellan (la portada se aplasta y rebota)
///    y dejan una mancha que queda pegada y escurre hasta que cambia la canción; el contador
///    "x2 ¡BUUU!", "x3 ¡FUERA!"; con el tercero, un telón rojo se cierra y se abre con la siguiente.
///  - 🌹: un reflector sobre la portada y pétalos (o rosas) que caen; con 5 rosas o más, ovación de
///    pie: "¡BRAVO!", confeti y la portada hace una reverencia.
/// Con "reducir animaciones", la versión simple: el contador o el "¡BRAVO!" aparecen y se van, y el
/// telón se funde en vez de correrse. Colores de [KijiColors] (los tres estilos).
class TheaterOverlay extends ConsumerStatefulWidget {
  const TheaterOverlay({super.key, required this.child, required this.trackId, this.radius = KijiRadii.cover});

  final Widget child;

  /// Al cambiar de canción, las manchas se limpian y el telón se abre.
  final String trackId;
  final double radius;

  @override
  ConsumerState<TheaterOverlay> createState() => _TheaterOverlayState();
}

class _Flyer {
  _Flyer(this.kind, this.start, this.target, this.born, this.spin, this.shape);
  final TheaterKind kind;
  final Offset start;
  final Offset target;
  final Duration born;
  final double spin;
  final int shape;
}

class _Stain {
  _Stain(this.at, this.born, this.seed, this.size);
  final Offset at;
  final Duration born;
  final int seed;
  final double size;
}

class _Petal {
  _Petal(this.x, this.born, this.speed, this.sway, this.spin, this.tone, this.rose);
  final double x;
  final Duration born;
  final double speed;
  final double sway;
  final double spin;
  final double tone;
  final bool rose;
}

class _Confetti {
  _Confetti(this.v, this.born, this.color, this.spin);
  final Offset v;
  final Duration born;
  final Color color;
  final double spin;
}

/// Un cartel sobre la portada ("x2 ¡BUUU!", "¡BRAVO!").
class _Label {
  _Label(this.text, this.born, this.color);
  final String text;
  final Duration born;
  final Color color;
}

class _TheaterOverlayState extends ConsumerState<TheaterOverlay> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _random = Random();
  Duration _now = Duration.zero;

  final _flyers = <_Flyer>[];
  final _stains = <_Stain>[];
  final _petals = <_Petal>[];
  final _confetti = <_Confetti>[];
  _Label? _label;
  Duration? _hitAt;
  Duration? _bowAt;
  Duration? _spotAt;

  // Telón: de 0 (abierto) a 1 (cerrado).
  double _curtain = 0;
  Duration? _curtainFrom;
  bool _curtainClosing = false;
  Timer? _curtainFallback;

  static const flight = Duration(milliseconds: 460);
  static const curtainClose = Duration(milliseconds: 550);
  static const curtainOpen = Duration(milliseconds: 750);

  bool get _simple => reduceMotion(context, ref);

  void _tick(Duration elapsed) {
    _now = elapsed;
    _flyers.removeWhere((f) {
      if (_now - f.born < flight) return false;
      if (f.kind == TheaterKind.tomato) {
        _stains.add(_Stain(f.target, _now, _random.nextInt(1 << 20), 0.8 + _random.nextDouble() * 0.5));
        _hitAt = _now;
      }
      return true;
    });
    _petals.removeWhere((p) => _now - p.born > const Duration(milliseconds: 2600));
    _confetti.removeWhere((c) => _now - c.born > const Duration(milliseconds: 2400));
    if (_label != null && _now - _label!.born > const Duration(milliseconds: 1500)) _label = null;
    // Telón.
    final from = _curtainFrom;
    if (from != null) {
      final t = (_now - from).inMicroseconds / (_curtainClosing ? curtainClose : curtainOpen).inMicroseconds;
      final k = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
      _curtain = _curtainClosing ? k : 1 - k;
      if (t >= 1) _curtainFrom = null;
    }
    final busy = _flyers.isNotEmpty ||
        _petals.isNotEmpty ||
        _confetti.isNotEmpty ||
        _label != null ||
        _curtainFrom != null ||
        _recent(_hitAt, 700) ||
        _recent(_bowAt, 1600) ||
        _recent(_spotAt, 1800) ||
        // Las manchas escurren unos segundos después de pegarse.
        _stains.any((s) => _now - s.born < const Duration(seconds: 4));
    if (!busy) _ticker.stop();
    setState(() {});
  }

  bool _recent(Duration? at, int ms) => at != null && _now - at < Duration(milliseconds: ms);

  void _start() {
    if (_ticker.isActive) return;
    // El reloj del ticker vuelve a 0: lo que quedó (manchas, telón) se corre con él.
    final shift = _now;
    _now = Duration.zero;
    Duration back(Duration d) => d - shift;
    for (var i = 0; i < _stains.length; i++) {
      final s = _stains[i];
      _stains[i] = _Stain(s.at, back(s.born) - const Duration(seconds: 10), s.seed, s.size);
    }
    // Lo que ya terminó no se vuelve a animar con el reloj nuevo.
    _hitAt = _bowAt = _spotAt = null;
    _ticker.start();
  }

  void _launch(TheaterBurst burst) {
    _start();
    final simple = _simple;
    if (burst.kind == TheaterKind.tomato) {
      if (!simple) {
        final count = burst.rain ? 6 : 1;
        for (var i = 0; i < count; i++) {
          final born = _now + Duration(milliseconds: i * 90);
          final target = Offset(0.22 + _random.nextDouble() * 0.56, 0.18 + _random.nextDouble() * 0.5);
          final start = Offset(0.5 + (_random.nextDouble() - 0.5) * 0.9, 1.45);
          _flyers.add(_Flyer(TheaterKind.tomato, start, target, born, (_random.nextDouble() - 0.5) * 8, (burst.variant + i) % 4));
        }
      } else {
        _hitAt = _now;
      }
      if (burst.count >= 3 || burst.booedOff) {
        _label = _Label(tx.tomateFuera(burst.count), _now + (simple ? Duration.zero : flight), KijiColors.theaterTomato);
      } else if (burst.count == 2) {
        _label = _Label(tx.tomateBuuu(burst.count), _now + (simple ? Duration.zero : flight), KijiColors.theaterTomato);
      }
      if (burst.booedOff) _closeCurtain();
    } else {
      _spotAt = _now;
      if (!simple) {
        final count = (10 + 4 * burst.count).clamp(10, 28);
        for (var i = 0; i < count; i++) {
          _petals.add(_Petal(
            _random.nextDouble(),
            _now + Duration(milliseconds: _random.nextInt(500)),
            0.35 + _random.nextDouble() * 0.3,
            0.03 + _random.nextDouble() * 0.06,
            (_random.nextDouble() - 0.5) * 5,
            _random.nextDouble(),
            burst.variant == 1 && i.isEven,
          ));
        }
      }
      if (burst.ovation) {
        _label = _Label(tx.bravo, _now, KijiColors.theaterGold);
        _bowAt = _now;
        if (!simple) {
          final colors = KijiColors.theaterConfetti;
          for (var i = 0; i < 46; i++) {
            final a = -pi / 2 + (_random.nextDouble() - 0.5) * 1.6;
            final speed = 0.9 + _random.nextDouble() * 0.8;
            _confetti.add(_Confetti(
              Offset(cos(a) * speed, sin(a) * speed),
              _now + Duration(milliseconds: _random.nextInt(250)),
              colors[i % colors.length],
              (_random.nextDouble() - 0.5) * 14,
            ));
          }
        }
      }
    }
  }

  void _closeCurtain() {
    _curtainClosing = true;
    _curtainFrom = _now;
    // Si no hay otra canción (la última de la cola), se vuelve a abrir solo.
    _curtainFallback?.cancel();
    _curtainFallback = Timer(const Duration(milliseconds: 2600), _openCurtain);
  }

  void _openCurtain() {
    _curtainFallback?.cancel();
    if (!mounted || (_curtain == 0 && _curtainFrom == null)) return;
    _start();
    _curtainClosing = false;
    _curtainFrom = _now;
  }

  @override
  void didUpdateWidget(TheaterOverlay old) {
    super.didUpdateWidget(old);
    if (old.trackId != widget.trackId) {
      _stains.clear();
      _label = null;
      // La siguiente canción sale a escena: se abre el telón.
      if (_curtain > 0 || _curtainClosing) _openCurtain();
    }
  }

  @override
  void dispose() {
    _curtainFallback?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TheaterBurst?>(theaterBurstProvider, (_, burst) {
      if (burst != null) _launch(burst);
    });
    final simple = _simple;
    // Golpe: la portada se aplasta y rebota (un resorte que se apaga).
    var sx = 1.0, sy = 1.0;
    final hit = _hitAt;
    if (!simple && hit != null && _now - hit < const Duration(milliseconds: 700)) {
      final t = (_now - hit).inMilliseconds / 1000;
      final e = exp(-t * 9) * cos(t * 38);
      sx = 1 + 0.07 * e;
      sy = 1 - 0.1 * e;
    }
    // Reverencia: se inclina hacia adelante y vuelve.
    final matrix = Matrix4.identity()..scaleByDouble(sx, sy, 1, 1);
    final bow = _bowAt;
    if (!simple && bow != null && _now - bow < const Duration(milliseconds: 1600)) {
      final p = (_now - bow).inMilliseconds / 1600;
      final b = sin(pi * p);
      matrix
        ..setEntry(3, 2, 0.0016)
        ..translateByDouble(0, 14 * b, 0, 1)
        ..rotateX(0.55 * b);
    }
    final label = _label;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform(
          alignment: Alignment.bottomCenter,
          transform: matrix,
          child: Stack(
            children: [
              widget.child,
              // Lo que queda pegado (manchas) y el reflector, recortado a la portada.
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.radius),
                    child: CustomPaint(
                      painter: _CoverPainter(
                        stains: List.of(_stains),
                        now: _now,
                        spot: _spotAt == null ? 0 : _spotLevel(_now - _spotAt!),
                        tomato: KijiColors.theaterTomato,
                        spotColor: KijiColors.theaterSpot,
                      ),
                    ),
                  ),
                ),
              ),
              // El telón.
              if (_curtain > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.radius),
                      child: simple
                          ? Opacity(opacity: _curtain, child: CustomPaint(painter: _CurtainPainter(closed: 1)))
                          : CustomPaint(painter: _CurtainPainter(closed: _curtain)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Lo que vuela (tomates, pétalos, confeti) puede salirse de la portada.
        if (_flyers.isNotEmpty || _petals.isNotEmpty || _confetti.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AirPainter(
                  flyers: List.of(_flyers),
                  petals: List.of(_petals),
                  confetti: List.of(_confetti),
                  now: _now,
                  tomato: KijiColors.theaterTomato,
                  leaf: KijiColors.theaterLeaf,
                  rose: KijiColors.like,
                ),
              ),
            ),
          ),
        if (label != null && _now >= label.born)
          Positioned.fill(
            child: IgnorePointer(child: Center(child: _LabelView(label: label, now: _now, simple: simple))),
          ),
      ],
    );
  }

  /// El reflector: sube rápido, queda y se apaga.
  static double _spotLevel(Duration d) {
    final ms = d.inMilliseconds;
    if (ms < 200) return ms / 200;
    if (ms < 1200) return 1;
    return (1 - (ms - 1200) / 600).clamp(0.0, 1.0);
  }
}

class _LabelView extends StatelessWidget {
  const _LabelView({required this.label, required this.now, required this.simple});

  final _Label label;
  final Duration now;
  final bool simple;

  @override
  Widget build(BuildContext context) {
    final t = (now - label.born).inMilliseconds;
    final pop = simple ? 1.0 : 0.55 + 0.45 * Curves.easeOutBack.transform((t / 280).clamp(0.0, 1.0));
    final fade = t < 1150 ? 1.0 : (1 - (t - 1150) / 350).clamp(0.0, 1.0);
    final outline = KijiColors.palette.isLight ? KijiColors.background : const Color(0xE6000000);
    return Opacity(
      opacity: fade,
      child: Transform.rotate(
        angle: simple ? 0 : -0.08,
        child: Transform.scale(
          scale: pop,
          child: Text(
            label.text,
            textAlign: TextAlign.center,
            style: KijiText.display(size: 40).copyWith(
              color: label.color,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              shadows: [
                for (final o in const [Offset(2, 2), Offset(-2, 2), Offset(2, -2), Offset(-2, -2), Offset(0, 4)])
                  Shadow(color: outline, offset: o, blurRadius: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Manchas pegadas que escurren, y el reflector.
class _CoverPainter extends CustomPainter {
  _CoverPainter({required this.stains, required this.now, required this.spot, required this.tomato, required this.spotColor});

  final List<_Stain> stains;
  final Duration now;
  final double spot;
  final Color tomato;
  final Color spotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    for (final s in stains) {
      final r = Random(s.seed);
      final at = Offset(s.at.dx * size.width, s.at.dy * size.height);
      final base = unit * 0.085 * s.size;
      final paint = Paint()..color = tomato.withValues(alpha: 0.88);
      canvas.drawCircle(at, base, paint);
      // Salpicaduras alrededor.
      for (var i = 0; i < 9; i++) {
        final a = r.nextDouble() * 2 * pi;
        final d = base * (0.9 + r.nextDouble() * 0.9);
        canvas.drawCircle(at + Offset(cos(a), sin(a)) * d, base * (0.12 + r.nextDouble() * 0.28), paint);
      }
      // Semillas.
      final seeds = Paint()..color = Color.lerp(tomato, const Color(0xFFFFE0A0), 0.6)!.withValues(alpha: 0.9);
      for (var i = 0; i < 6; i++) {
        final a = r.nextDouble() * 2 * pi;
        final d = base * r.nextDouble() * 0.7;
        canvas.drawOval(Rect.fromCenter(center: at + Offset(cos(a), sin(a)) * d, width: base * 0.14, height: base * 0.09), seeds);
      }
      // Gotas que escurren hacia abajo (y quedan).
      final grow = Curves.easeOutCubic.transform(((now - s.born).inMilliseconds / 3500).clamp(0.0, 1.0));
      for (var i = 0; i < 3; i++) {
        final x = at.dx + (r.nextDouble() - 0.5) * base * 1.4;
        final w = base * (0.18 + r.nextDouble() * 0.16);
        final len = base * (1.2 + r.nextDouble() * 2.2) * grow;
        final top = at.dy + base * 0.4;
        canvas.drawRRect(RRect.fromLTRBR(x - w / 2, top, x + w / 2, top + len, Radius.circular(w / 2)), paint);
        canvas.drawCircle(Offset(x, top + len), w * 0.7, paint);
      }
    }
    if (spot > 0) {
      // Cono de luz desde arriba y un círculo brillante sobre la portada.
      final cone = Path()
        ..moveTo(size.width * 0.38, -size.height * 0.05)
        ..lineTo(size.width * 0.62, -size.height * 0.05)
        ..lineTo(size.width * 1.05, size.height)
        ..lineTo(-size.width * 0.05, size.height)
        ..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [spotColor.withValues(alpha: 0.42 * spot), spotColor.withValues(alpha: 0.05 * spot)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.55),
        unit * 0.55,
        Paint()
          ..shader = RadialGradient(colors: [spotColor.withValues(alpha: 0.35 * spot), spotColor.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.55), radius: unit * 0.55)),
      );
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => true;
}

/// El telón de terciopelo: dos paños con pliegues que se cierran desde los costados, con una
/// cenefa arriba y flecos dorados.
class _CurtainPainter extends CustomPainter {
  _CurtainPainter({required this.closed});

  final double closed;

  @override
  void paint(Canvas canvas, Size size) {
    final velvet = KijiColors.theaterCurtain;
    final shadow = KijiColors.theaterCurtainShadow;
    final gold = KijiColors.theaterGold;
    final half = size.width / 2 * closed;
    for (final left in [true, false]) {
      final rect = left ? Rect.fromLTWH(0, 0, half + 1, size.height) : Rect.fromLTWH(size.width - half - 1, 0, half + 1, size.height);
      if (rect.width <= 0) continue;
      // Pliegues: franjas claras y oscuras.
      final folds = <Color>[];
      final stops = <double>[];
      const n = 7;
      for (var i = 0; i <= n; i++) {
        folds.add(i.isEven ? velvet : shadow);
        stops.add(i / n);
      }
      canvas.drawRect(
        rect,
        Paint()..shader = LinearGradient(colors: folds, stops: stops).createShader(rect),
      );
      // Borde que se junta al medio, más oscuro.
      final edge = left ? Rect.fromLTWH(rect.right - 6, 0, 6, size.height) : Rect.fromLTWH(rect.left, 0, 6, size.height);
      canvas.drawRect(edge, Paint()..color = shadow.withValues(alpha: 0.7));
    }
    // Cenefa con flecos (siempre arriba mientras el telón está a la vista).
    final valance = Rect.fromLTWH(0, 0, size.width, size.height * 0.1);
    canvas.drawRect(valance, Paint()..color = shadow);
    final fringe = Paint()..color = gold;
    final step = size.width / 18;
    for (var i = 0; i < 18; i++) {
      canvas.drawCircle(Offset(step * (i + 0.5), valance.bottom), step * 0.28, fringe);
    }
    canvas.drawRect(Rect.fromLTWH(0, valance.bottom - 2, size.width, 2), fringe);
  }

  @override
  bool shouldRepaint(_CurtainPainter old) => old.closed != closed;
}

/// Lo que vuela: tomates (4 formas), pétalos o rosas que caen, y el confeti.
class _AirPainter extends CustomPainter {
  _AirPainter({
    required this.flyers,
    required this.petals,
    required this.confetti,
    required this.now,
    required this.tomato,
    required this.leaf,
    required this.rose,
  });

  final List<_Flyer> flyers;
  final List<_Petal> petals;
  final List<_Confetti> confetti;
  final Duration now;
  final Color tomato;
  final Color leaf;
  final Color rose;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    Offset at(Offset p) => Offset(p.dx * size.width, p.dy * size.height);

    for (final f in flyers) {
      final t = (now - f.born).inMicroseconds / _TheaterOverlayState.flight.inMicroseconds;
      if (t < 0) continue;
      final k = t.clamp(0.0, 1.0);
      // Arco: sube y cae sobre la portada, achicándose (se aleja).
      final pos = Offset.lerp(at(f.start), at(f.target), k)! - Offset(0, sin(k * pi) * unit * 0.45);
      final r = unit * (0.1 - 0.04 * k);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(f.spin * k);
      _tomato(canvas, r, f.shape);
      canvas.restore();
    }

    for (final p in petals) {
      final t = (now - p.born).inMilliseconds / 1000;
      if (t < 0) continue;
      final y = -0.12 + t * p.speed;
      final x = p.x + sin(t * 3 + p.x * 9) * p.sway;
      final alpha = (1 - (t - 1.8) / 0.8).clamp(0.0, 1.0);
      final color = Color.lerp(rose, p.tone > 0.5 ? const Color(0xFFFFFFFF) : const Color(0xFF000000), p.tone * 0.3)!;
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(p.spin * t);
      final r = unit * (p.rose ? 0.035 : 0.028);
      final paint = Paint()..color = color.withValues(alpha: alpha);
      if (p.rose) {
        for (var i = 0; i < 5; i++) {
          final a = i * 2 * pi / 5;
          canvas.drawCircle(Offset(cos(a), sin(a)) * r * 0.6, r * 0.6, paint);
        }
        canvas.drawCircle(Offset.zero, r * 0.45, Paint()..color = KijiColors.shade(color).withValues(alpha: alpha));
      } else {
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r), paint);
      }
      canvas.restore();
    }

    for (final c in confetti) {
      final t = (now - c.born).inMilliseconds / 1000;
      if (t < 0) continue;
      // Sale de abajo de la portada hacia arriba y cae (gravedad).
      final pos = Offset(0.5 + c.v.dx * t * 0.6, 0.95 + c.v.dy * t + 0.9 * t * t);
      final alpha = (1 - (t - 1.6) / 0.8).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(pos.dx * size.width, pos.dy * size.height);
      canvas.rotate(c.spin * t);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: unit * 0.03, height: unit * 0.014), Paint()..color = c.color.withValues(alpha: alpha));
      canvas.restore();
    }
  }

  /// Cuatro formas de tomate: redondo, dos cherry, ovalado y cortado al medio.
  void _tomato(Canvas canvas, double r, int shape) {
    final body = Paint()..color = tomato;
    final shine = Paint()..color = KijiColors.shine(tomato);
    final green = Paint()..color = leaf;
    void leaves(Offset c, double size) {
      for (var i = 0; i < 5; i++) {
        final a = -pi / 2 + i * 2 * pi / 5;
        canvas.drawOval(Rect.fromCenter(center: c + Offset(cos(a), sin(a)) * size * 0.5, width: size * 0.7, height: size * 0.3), green);
      }
    }

    switch (shape) {
      case 1:
        for (final o in [Offset(-r * 0.45, 0), Offset(r * 0.45, r * 0.15)]) {
          canvas.drawCircle(o, r * 0.6, body);
          canvas.drawCircle(o - Offset(r * 0.2, r * 0.2), r * 0.18, shine);
        }
        canvas.drawLine(Offset(-r * 0.45, -r * 0.6), Offset(0, -r * 1.1), green..strokeWidth = r * 0.12);
        canvas.drawLine(Offset(r * 0.45, -r * 0.45), Offset(0, -r * 1.1), green);
      case 2:
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.4, height: r * 1.7), body);
        canvas.drawOval(Rect.fromCenter(center: Offset(-r * 0.4, -r * 0.3), width: r * 0.6, height: r * 0.35), shine);
        leaves(Offset(0, -r * 0.8), r * 0.6);
      case 3:
        canvas.drawCircle(Offset.zero, r, body);
        canvas.drawCircle(Offset.zero, r * 0.78, Paint()..color = Color.lerp(tomato, const Color(0xFFFFFFFF), 0.25)!);
        final seeds = Paint()..color = const Color(0xFFFFE6A8);
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3;
          canvas.drawOval(Rect.fromCenter(center: Offset(cos(a), sin(a)) * r * 0.42, width: r * 0.16, height: r * 0.1), seeds);
        }
      default:
        canvas.drawCircle(Offset.zero, r, body);
        canvas.drawCircle(Offset(-r * 0.35, -r * 0.35), r * 0.3, shine);
        leaves(Offset(0, -r * 0.9), r * 0.6);
    }
  }

  @override
  bool shouldRepaint(_AirPainter old) => true;
}
