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

  group('Cerrar el reproductor deslizando hacia abajo', () {
    Future<(int, int)> swipe(WidgetTester tester, Offset from, Offset by, {double speed = 1500}) async {
      var up = 0, down = 0;
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: LyricsSwipeDetector(
          onSwipeUp: () => up++,
          onSwipeDown: () => down++,
          child: const SizedBox.expand(key: Key('reproductor')),
        ),
      ));
      await tester.flingFrom(from, by, speed);
      await tester.pumpAndSettle();
      return (up, down);
    }

    testWidgets('un deslizar claro hacia abajo lo cierra', (tester) async {
      expect(await swipe(tester, const Offset(200, 300), const Offset(0, 300)), (0, 1));
    });

    testWidgets('un recorrido largo y lento también', (tester) async {
      expect(await swipe(tester, const Offset(200, 200), const Offset(0, 400), speed: 200), (0, 1));
    });

    testWidgets('un toquecito no lo cierra y vuelve a su lugar', (tester) async {
      expect(await swipe(tester, const Offset(200, 300), const Offset(0, 30), speed: 100), (0, 0));
      final moved = tester.getTopLeft(find.byKey(const Key('reproductor')));
      expect(moved.dy, 0, reason: 'volvió arriba');
    });

    testWidgets('hacia arriba sigue abriendo la letra (y no lo cierra)', (tester) async {
      expect(await swipe(tester, const Offset(200, 600), const Offset(0, -300)), (1, 0));
    });
  });

  group('Reproductor más alto que la pantalla (la columna se desplaza)', () {
    Future<int> pull(WidgetTester tester, {bool scrollFirst = false}) async {
      var closed = 0;
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: PullDownToClose(
          onClose: () => closed++,
          child: const SingleChildScrollView(child: SizedBox(height: 1400, width: 400)),
        ),
      ));
      if (scrollFirst) {
        await tester.dragFrom(const Offset(200, 400), const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      await tester.dragFrom(const Offset(200, 150), const Offset(0, 250));
      await tester.pumpAndSettle();
      return closed;
    }

    testWidgets('arriba de todo, tirar hacia abajo lo cierra', (tester) async {
      expect(await pull(tester), 1);
    });

    testWidgets('a mitad de la columna, bajar solo desplaza', (tester) async {
      expect(await pull(tester, scrollFirst: true), 0);
    });
  });
}
