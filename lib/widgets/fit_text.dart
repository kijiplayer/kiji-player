import 'package:flutter/material.dart';

/// Texto que nunca parte una palabra: si alguna palabra no entra en el ancho o el texto no entra en
/// [maxLines] líneas, baja el tamaño de a un punto hasta [minFontSize]. Recién ahí, si sigue sin
/// entrar, corta con «…» al final. (Los títulos del reproductor se partían: «elephan / t cage».)
class FitText extends StatelessWidget {
  const FitText(
    this.text, {
    super.key,
    required this.style,
    required this.minFontSize,
    this.maxLines = 2,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final double minFontSize;
  final int maxLines;
  final TextAlign? textAlign;

  /// El tamaño más grande (entre el del estilo y [minFontSize]) con el que [text] entra en
  /// [maxWidth] sin partir palabras.
  static double fittingSize({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double minFontSize,
    required int maxLines,
    required TextScaler textScaler,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    bool fits(double size) {
      final sized = style.copyWith(fontSize: size);
      final whole = TextPainter(
        text: TextSpan(text: text, style: sized),
        maxLines: maxLines,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      final over = whole.didExceedMaxLines;
      whole.dispose();
      if (over) return false;
      for (final word in words) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: sized),
          maxLines: 1,
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout();
        final wide = painter.width > maxWidth;
        painter.dispose();
        if (wide) return false;
      }
      return true;
    }

    var size = style.fontSize ?? 14;
    while (size > minFontSize && !fits(size)) {
      size -= 1;
    }
    return size < minFontSize ? minFontSize : size;
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.maxWidth.isFinite
            ? fittingSize(
                text: text,
                style: base,
                maxWidth: box.maxWidth,
                minFontSize: minFontSize,
                maxLines: maxLines,
                textScaler: scaler,
                textDirection: direction,
              )
            : base.fontSize ?? 14;
        return Text(
          text,
          style: base.copyWith(fontSize: size),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        );
      },
    );
  }
}
