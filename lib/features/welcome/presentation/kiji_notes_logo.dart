import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../theme/kiji_tokens.dart';

/// Las barras del logo (las mismas medidas que assets/branding/kiji_logo.svg, sobre 200 × 200):
/// la K y las 4 barras de la onda.
const _bars = [
  (x: 50.0, y: 46.0, w: 16.0, h: 108.0),
  (x: 80.0, y: 88.0, w: 14.0, h: 24.0),
  (x: 104.0, y: 76.0, w: 14.0, h: 48.0),
  (x: 128.0, y: 62.0, w: 14.0, h: 76.0),
  (x: 152.0, y: 48.0, w: 14.0, h: 104.0),
];

/// Entre una barra y la siguiente (igual que entre las notas de assets/sounds/kiji_notes.wav).
const _gap = Duration(milliseconds: 180);
const _grow = Duration(milliseconds: 520);

/// El logo de Kiji que se arma barra por barra, con una nota por barra (las 5 notas de Kiji,
/// bajito). Después la onda "respira" despacio. Con [reduceMotion], aparece quieto.
class KijiNotesLogo extends StatefulWidget {
  const KijiNotesLogo({super.key, this.size = 148, required this.muted, this.reduceMotion = false});

  final double size;

  /// Sin sonido (el botón de silencio de la bienvenida).
  final bool muted;
  final bool reduceMotion;

  @override
  State<KijiNotesLogo> createState() => _KijiNotesLogoState();
}

class _KijiNotesLogoState extends State<KijiNotesLogo> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: _gap * (_bars.length - 1) + _grow,
  );
  late final AnimationController _breath = AnimationController(vsync: this, duration: KijiMotion.breath * 1.5);
  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _intro.value = 1;
    } else {
      _intro.forward().whenComplete(() {
        if (mounted) _breath.repeat();
      });
    }
    if (!widget.muted) _play();
  }

  @override
  void didUpdateWidget(KijiNotesLogo old) {
    super.didUpdateWidget(old);
    if (widget.muted && !old.muted) _player?.stop();
  }

  /// Suena una sola vez, bajito, sin quitarle el audio a otras apps.
  Future<void> _play() async {
    try {
      final player = _player = AudioPlayer(handleInterruptions: false, handleAudioSessionActivation: false);
      await player.setVolume(0.35);
      await player.setAsset('assets/sounds/kiji_notes.wav');
      if (mounted && !widget.muted) await player.play();
    } catch (error) {
      debugPrint('=== BIENVENIDA: no sonaron las notas: $error ===');
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _breath]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _LogoPainter(
            grow: [
              for (var i = 0; i < _bars.length; i++)
                Curves.easeOutBack.transform(
                  ((_intro.value * _intro.duration!.inMilliseconds - _gap.inMilliseconds * i) / _grow.inMilliseconds)
                      .clamp(0.0, 1.0),
                ),
            ],
            breath: _breath.isAnimating ? _breath.value : null,
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.grow, required this.breath});

  /// Cuánto creció cada barra (0 a 1, con un poco de rebote).
  final List<double> grow;

  /// La fase de la onda que respira (null: quieta).
  final double? breath;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    canvas.scale(s);
    final bg = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 200, 200), const Radius.circular(46));
    canvas.drawRRect(bg, Paint()..color = const Color(0xFF0B0B14));
    canvas.drawRRect(
      bg,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = KijiColors.glassBorder,
    );
    const gradient = LinearGradient(colors: [KijiColors.violet, KijiColors.cyan]);
    final shader = gradient.createShader(const Rect.fromLTWH(80, 0, 86, 200));
    for (var i = 0; i < _bars.length; i++) {
      final bar = _bars[i];
      var h = bar.h * grow[i];
      // La onda respira: cada barra de la onda sube y baja un poco, corrida de la anterior.
      if (breath != null && i > 0) h *= 1 + 0.12 * math.sin(2 * math.pi * (breath! - i * 0.18));
      if (h <= 0) continue;
      final cy = bar.y + bar.h / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bar.x + bar.w / 2, cy), width: bar.w, height: h),
        Radius.circular(bar.w / 2),
      );
      final paint = Paint();
      if (i == 0) {
        paint.color = KijiColors.violet;
      } else if (i == _bars.length - 1) {
        paint.color = KijiColors.cyan;
      } else {
        paint.shader = shader;
      }
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.breath != breath || !listEquals(old.grow, grow);
}
