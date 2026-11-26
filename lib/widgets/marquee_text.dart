import 'package:flutter/material.dart';

import '../theme/kiji_tokens.dart';

/// Una línea de texto que, si no entra, se desplaza despacio hasta mostrar el final (marquee),
/// espera, vuelve al principio y repite. Si entra, o con "reducir animaciones", es un
/// [Text] normal con «…».
class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {super.key, required this.style, this.textAlign});

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  /// Velocidad del desplazamiento, en píxeles lógicos por segundo.
  static const speed = 40.0;

  /// Margen al final, para que la última letra no quede pegada al borde.
  static const endPadding = 8.0;

  /// Pausa al principio y al final de cada vuelta.
  static const pause = Duration(milliseconds: 1600);

  /// Cuántas vueltas da cada título.
  static const loops = 3;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Lo que ya se desplazó (texto y recorrido): no se repite hasta que cambie.
  String? _ranFor;

  void _run(double distance) {
    final key = '${widget.text}|${distance.round()}';
    if (key == _ranFor) return;
    _ranFor = key;
    final travel = Duration(milliseconds: (distance / MarqueeText.speed * 1000).round());
    _controller
      ..stop()
      ..duration = travel + MarqueeText.pause * 2;
    // Unas vueltas y queda quieto en el principio (no se mueve para siempre: gasta batería y distrae).
    _controller.repeat(count: MarqueeText.loops).whenComplete(() {
      if (mounted) _controller.value = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        final width = painter.width;
        final height = painter.height;
        painter.dispose();
        final fits = !box.maxWidth.isFinite || width <= box.maxWidth;
        if (fits || KijiEffects.still(context)) {
          if (_controller.isAnimating) _controller.stop();
          return Text(
            widget.text,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
          );
        }
        final distance = width - box.maxWidth + MarqueeText.endPadding;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _run(distance);
        });
        final line = Text(widget.text, style: style, maxLines: 1, softWrap: false);
        return Semantics(
          label: widget.text,
          excludeSemantics: true,
          child: SizedBox(
            height: height,
            width: box.maxWidth,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Quieto al principio, se desplaza, quieto al final y vuelve de un salto.
                  final total = _controller.duration?.inMilliseconds ?? 1;
                  final pauseShare = MarqueeText.pause.inMilliseconds / total;
                  final moving = 1 - 2 * pauseShare;
                  final t = ((_controller.value - pauseShare) / moving).clamp(0.0, 1.0);
                  // Los bordes se desvanecen (no letras cortadas en seco): el derecho mientras falte
                  // texto por ver; el izquierdo, cuando el principio ya se fue.
                  final fade = 16 / box.maxWidth;
                  return ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: t > 0 ? 0 : 1),
                        Colors.white,
                        Colors.white,
                        Colors.white.withValues(alpha: t < 1 ? 0 : 1),
                      ],
                      stops: [0, fade, 1 - fade, 1],
                    ).createShader(rect),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(left: -Curves.easeInOut.transform(t) * distance, top: 0, child: child!),
                      ],
                    ),
                  );
                },
                child: line,
              ),
            ),
          ),
        );
      },
    );
  }
}
