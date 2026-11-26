import 'package:flutter/material.dart';

import 'marquee_text.dart';

/// Texto que nunca parte una palabra: si alguna palabra no entra en el ancho o el texto no entra en
/// [maxLines] líneas, baja el tamaño de a un punto hasta [minFontSize]. Si ni así entra, va en una
/// sola línea que se desplaza ([MarqueeText]) en vez de cortarse con «…». (Los títulos del
/// reproductor se partían, «elephan / t cage», o se cortaban, «BAILE INoLVI…».)
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
  }) => fit(
    text: text,
    style: style,
    maxWidth: maxWidth,
    minFontSize: minFontSize,
    maxLines: maxLines,
    textScaler: textScaler,
    textDirection: textDirection,
  ).size;

  /// Como [fittingSize], y además si a ese tamaño el texto entra de verdad (si no, hace falta el
  /// desplazamiento).
  static ({double size, bool fits}) fit({
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
    if (size < minFontSize) size = minFontSize;
    return (size: size, fits: fits(size));
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.maxWidth.isFinite) {
          return Text(text, style: base, maxLines: maxLines, overflow: TextOverflow.ellipsis, textAlign: textAlign);
        }
        final result = fit(
          text: text,
          style: base,
          maxWidth: box.maxWidth,
          minFontSize: minFontSize,
          maxLines: maxLines,
          textScaler: scaler,
          textDirection: direction,
        );
        final sized = base.copyWith(fontSize: result.size);
        // Ni al mínimo entra (una palabra larguísima o demasiadas): se desplaza, no se corta.
        if (!result.fits) return MarqueeText(text, style: sized, textAlign: textAlign);
        return Text(text, style: sized, maxLines: maxLines, overflow: TextOverflow.ellipsis, textAlign: textAlign);
      },
    );
  }
}
