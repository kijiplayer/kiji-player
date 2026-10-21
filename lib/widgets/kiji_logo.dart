import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kiji_player/l10n/l10n.dart';

import '../theme/kiji_tokens.dart';

/// Las barras del logo (las mismas medidas que assets/branding/kiji_logo.svg, sobre 200 × 200):
/// la K y las 4 barras de la onda.
const kijiLogoBars = [
  (x: 50.0, y: 46.0, w: 16.0, h: 108.0),
  (x: 80.0, y: 88.0, w: 14.0, h: 24.0),
  (x: 104.0, y: 76.0, w: 14.0, h: 48.0),
  (x: 128.0, y: 62.0, w: 14.0, h: 76.0),
  (x: 152.0, y: 48.0, w: 14.0, h: 104.0),
];

/// El logo de Kiji ("Opción B · K de onda"), dibujado igual que `assets/branding/kiji_logo.svg`,
/// la misma fuente que los íconos.
class KijiLogo extends StatelessWidget {
  const KijiLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: tx.logoDeKiji,
        image: true,
        child: CustomPaint(size: Size.square(size), painter: KijiLogoPainter()),
      );
}

/// Dibuja el logo. La bienvenida lo anima con [grow] y [breath].
class KijiLogoPainter extends CustomPainter {
  KijiLogoPainter({this.grow = const [1, 1, 1, 1, 1], this.breath, this.border = false});

  /// Cuánto creció cada barra (0 a 1, con un poco de rebote).
  final List<double> grow;

  /// La fase de la onda que respira (null: quieta).
  final double? breath;

  /// Borde de vidrio alrededor del fondo.
  final bool border;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    canvas.scale(s);
    final bg = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 200, 200), const Radius.circular(46));
    canvas.drawRRect(bg, Paint()..color = const Color(0xFF0B0B14));
    if (border) {
      canvas.drawRRect(
        bg,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = KijiColors.glassBorder,
      );
    }
    final gradient = LinearGradient(colors: [KijiColors.violet, KijiColors.cyan]);
    final shader = gradient.createShader(const Rect.fromLTWH(80, 0, 86, 200));
    for (var i = 0; i < kijiLogoBars.length; i++) {
      final bar = kijiLogoBars[i];
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
      } else if (i == kijiLogoBars.length - 1) {
        paint.color = KijiColors.cyan;
      } else {
        paint.shader = shader;
      }
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(KijiLogoPainter old) =>
      old.breath != breath || old.border != border || !listEquals(old.grow, grow);
}
