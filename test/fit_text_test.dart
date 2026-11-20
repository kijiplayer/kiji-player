// Los títulos del reproductor nunca se parten a mitad de palabra («elephan / t cage»): se achican
// hasta un mínimo y recién ahí se cortan con «…».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/widgets/fit_text.dart';

/// ¿Algún salto de línea cae en mitad de una palabra?
bool _breaksAWord(String text, TextStyle style, double width, int maxLines) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: maxLines,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  final lines = painter.computeLineMetrics();
  for (var i = 0; i < lines.length - 1; i++) {
    final y = lines[i].baseline;
    final end = painter.getLineBoundary(painter.getPositionForOffset(Offset(width - 1, y))).end;
    if (end <= 0 || end >= text.length) continue;
    final before = text[end - 1], after = text[end];
    if (before.trim().isNotEmpty && after.trim().isNotEmpty) return true;
  }
  painter.dispose();
  return false;
}

void main() {
  // Los del anuncio de la 0.8.4 (Grafito: tamaño 38, fino).
  const titles = [
    'elephant cage',
    'Christmas Kids',
    'Idioteque',
    'BAILE INoLVIDABLE',
    'Igual Que Un Ángel (con Peso Pluma)',
    'The Night We Met',
    'Lo Siento BB:/',
    'Supercalifragilisticexpialidocious',
  ];
  const style = TextStyle(fontSize: 38, fontWeight: FontWeight.w300, letterSpacing: -1, height: 1.05);

  for (final width in [312.0, 280.0]) {
    test('A $width de ancho, ningún título se parte a mitad de palabra', () {
      for (final title in titles) {
        final size = FitText.fittingSize(
          text: title,
          style: style,
          maxWidth: width,
          minFontSize: 24,
          maxLines: 2,
          textScaler: TextScaler.noScaling,
        );
        expect(size, inInclusiveRange(24, 38));
        // Si hubo que llegar al mínimo, se acepta el «…» (palabra imposible); si no, nunca se parte.
        if (size > 24) {
          expect(_breaksAWord(title, style.copyWith(fontSize: size), width, 2), isFalse, reason: title);
        }
      }
    });
  }

  test('El detector de cortes funciona: «elephant» a 38 en 120 de ancho se parte', () {
    expect(_breaksAWord('elephant cage', style, 120, 3), isTrue);
  });

  test('Un título corto queda en su tamaño', () {
    final size = FitText.fittingSize(
      text: 'Creep',
      style: style,
      maxWidth: 312,
      minFontSize: 24,
      maxLines: 2,
      textScaler: TextScaler.noScaling,
    );
    expect(size, 38);
  });

  testWidgets('FitText se dibuja sin desbordar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: FitText('elephant cage', style: style, minFontSize: 24),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.text('elephant cage'));
    expect(text.style!.fontSize, lessThanOrEqualTo(38));
  });
}
