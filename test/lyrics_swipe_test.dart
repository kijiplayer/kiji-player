import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/screens/player/lyrics_swipe.dart';

void main() {
  const rule = LyricsSwipeRule();
  const screen = Size(400, 900);
  const gestures = EdgeInsets.only(left: 20, right: 20, bottom: 32);
  const padding = EdgeInsets.only(top: 24, bottom: 24);

  bool startsOk(Offset start) => rule.startsOutsideSystemGestures(
        start: start,
        screen: screen,
        systemGestureInsets: gestures,
        viewPadding: padding,
      );

  group('LyricsSwipeRule', () {
    test('ignora gestos que empiezan en la zona de gestos de abajo', () {
      expect(startsOk(const Offset(200, 890)), isFalse);
      expect(startsOk(const Offset(200, 860)), isFalse); // dentro del margen extra
      expect(startsOk(const Offset(200, 600)), isTrue);
    });

    test('ignora los bordes laterales de "atrás"', () {
      expect(startsOk(const Offset(5, 400)), isFalse);
      expect(startsOk(const Offset(395, 400)), isFalse);
      expect(startsOk(const Offset(200, 400)), isTrue);
    });

    test('pide recorrido y velocidad claros', () {
      expect(rule.accepts(upwardDistance: 200, upwardVelocity: 1200), isTrue);
      expect(rule.accepts(upwardDistance: 60, upwardVelocity: 1200), isFalse);
      expect(rule.accepts(upwardDistance: 200, upwardVelocity: 300), isFalse);
      expect(rule.accepts(upwardDistance: -200, upwardVelocity: -1200), isFalse);
    });
  });

  group('LyricsSwipeDetector', () {
    Future<int> swipe(WidgetTester tester, Offset from, Offset by) async {
      var opened = 0;
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      tester.view.systemGestureInsets = const FakeViewPadding(bottom: 32, left: 20, right: 20);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: LyricsSwipeDetector(
          onSwipeUp: () => opened++,
          child: const SizedBox.expand(),
        ),
      ));
      await tester.flingFrom(from, by, 1500);
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('abre la letra con un deslizar claro desde el medio', (tester) async {
      expect(await swipe(tester, const Offset(200, 600), const Offset(0, -300)), 1);
    });

    testWidgets('no abre la letra con el gesto de salir desde abajo', (tester) async {
      expect(await swipe(tester, const Offset(200, 895), const Offset(0, -400)), 0);
    });

    testWidgets('no abre la letra con un toque corto', (tester) async {
      expect(await swipe(tester, const Offset(200, 600), const Offset(0, -50)), 0);
    });
  });
}
