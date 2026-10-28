import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/kiji_tokens.dart';

/// Microanimaciones de los botones: sutiles, cortas (≤ 450 ms) y apagadas con "Reducir
/// animaciones".

/// Se achica apenas al apoyar el dedo (o el clic) y vuelve con un rebote corto.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true, this.pressed = 0.9});

  final Widget child;
  final bool enabled;

  /// Escala con el dedo apoyado.
  final double pressed;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || KijiEffects.still(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _press.forward(),
      onPointerUp: (_) => _press.reverse(),
      onPointerCancel: (_) => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          // De vuelta, un pequeño rebote (Grafito: un resorte); al apretar, directo.
          final t = _press.status == AnimationStatus.reverse
              ? (KijiLook.museum
                    ? 1 - KijiMotion.spring.transform(1 - _press.value)
                    : Curves.easeOutBack.transform(_press.value))
              : Curves.easeOut.transform(_press.value);
          return Transform.scale(scale: 1 - (1 - widget.pressed) * t, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

/// Cambia de ícono (o de estado) con un "pop": el nuevo entra creciendo y el viejo se desvanece.
/// El hijo tiene que tener una [Key] distinta por estado.
class PopSwitcher extends StatelessWidget {
  const PopSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (KijiEffects.still(context)) return child;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 140),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(animation), child: child),
      ),
      child: child,
    );
  }
}

/// Corazón de "me gusta": al marcarlo late una vez y suelta un anillo de puntitos. En el modo alto
/// rendimiento, más puntitos y con brillo.
class LikeHeart extends StatefulWidget {
  const LikeHeart({super.key, required this.liked, this.size = 24, this.color, this.likedColor});

  final bool liked;
  final double size;
  final Color? color;
  final Color? likedColor;

  @override
  State<LikeHeart> createState() => _LikeHeartState();
}

class _LikeHeartState extends State<LikeHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void didUpdateWidget(LikeHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.liked && !oldWidget.liked && !KijiEffects.still(context)) _burst.forward(from: 0);
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final likedColor = widget.likedColor ?? KijiColors.like;
    final icon = Icon(
      widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: widget.liked ? likedColor : widget.color ?? KijiColors.text,
      size: widget.size,
    );
    return AnimatedBuilder(
      animation: _burst,
      builder: (context, child) {
        final t = _burst.value;
        // Late: 1 → 1,3 → 1.
        final beat = t < 0.35
            ? 1 + 0.3 * Curves.easeOut.transform(t / 0.35)
            : 1 + 0.3 * (1 - Curves.easeInOut.transform((t - 0.35) / 0.65));
        return CustomPaint(
          foregroundPainter: _burst.isAnimating
              ? _BurstPainter(progress: t, color: likedColor, accent: KijiColors.cyan, rich: KijiEffects.rich)
              : null,
          child: Transform.scale(scale: beat, child: child),
        );
      },
      child: icon,
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.color, required this.accent, required this.rich});

  final double progress;
  final Color color;
  final Color accent;
  final bool rich;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final count = rich ? 12 : 6;
    final reach = size.shortestSide * (0.55 + 0.45 * Curves.easeOut.transform(progress));
    final fade = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint();
    if (rich) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (var i = 0; i < count; i++) {
      final angle = 2 * pi * i / count - pi / 2;
      final dot = center + Offset(cos(angle), sin(angle)) * reach;
      paint.color = (i.isEven ? color : accent).withValues(alpha: fade);
      canvas.drawCircle(dot, (rich ? 2.2 : 1.8) * (0.6 + fade * 0.6), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
