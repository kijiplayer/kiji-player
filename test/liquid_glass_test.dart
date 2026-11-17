import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';
import 'package:kiji_player/widgets/nocturne/glass.dart';
import 'package:kiji_player/widgets/nocturne/liquid_glass.dart';

/// Vidrio líquido (0.8.3): sin desenfoque en vivo, con el fondo ya desenfocado publicado una vez.
void main() {
  Future<ui.Image> smallImage() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = const Color(0xFF6A4CFF));
    return recorder.endRecording().toImage(8, 8);
  }

  for (final style in KijiStyle.values) {
    testWidgets('Se dibuja en ${style.name}: tarjeta y flotante, con y sin fondo publicado', (tester) async {
      final before = (KijiLook.style, KijiColors.palette);
      addTearDown(() {
        KijiLook.style = before.$1;
        KijiColors.palette = before.$2;
      });
      KijiLook.style = style;
      KijiColors.palette = switch (style) {
        KijiStyle.nocturne => KijiPalette.nocturne,
        KijiStyle.graphite => KijiPalette.graphite,
        KijiStyle.paper => KijiPalette.paper,
      };
      final image = await tester.runAsync(smallImage);
      late GlassBackdropController controller;
      await tester.pumpWidget(
        MaterialApp(
          home: GlassBackdropHost(
            child: Builder(
              builder: (context) {
                controller = GlassBackdrop.maybeOf(context)!;
                return ListView(
                  children: const [
                    Glass(child: SizedBox(height: 80, child: Text('Tarjeta inventada'))),
                    Glass(floating: true, child: SizedBox(height: 60, child: Text('Barra inventada'))),
                  ],
                );
              },
            ),
          ),
        ),
      );
      // Sin fondo publicado (fondo liso): se dibuja igual.
      expect(tester.takeException(), isNull);
      // Con la foto ya desenfocada publicada: los vidrios la recortan y repintan.
      controller.set('photo', GlassLayer(image!, const Rect.fromLTWH(0, 0, 800, 600)));
      await tester.pump();
      expect(controller.layers, hasLength(1));
      // Al deslizar, el reflejo se mueve (repinta sin errores).
      await tester.drag(find.byType(ListView), const Offset(0, -40));
      await tester.pump();
      expect(tester.takeException(), isNull);
      controller.remove('photo');
      expect(controller.isEmpty, isTrue);
      await tester.pumpWidget(const SizedBox());
      image.dispose();
    });
  }

  testWidgets('Con "reducir animaciones" el reflejo queda quieto (y no hay desenfoque en vivo)', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Glass(child: SizedBox(width: 100, height: 60))),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(LiquidGlass), findsOneWidget);
  });

  test('Las capas van en orden: la foto abajo, la aurora encima', () async {
    final controller = GlassBackdropController();
    var notified = 0;
    controller.addListener(() => notified++);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawPaint(Paint());
    final image = await recorder.endRecording().toImage(2, 2);
    controller
      ..set('aurora', GlassLayer(image, Rect.zero))
      ..set('photo', GlassLayer(image, const Rect.fromLTWH(0, 0, 1, 1)));
    expect(controller.layers.first.rect, const Rect.fromLTWH(0, 0, 1, 1));
    expect(notified, 2);
    controller.dispose();
    image.dispose();
  });

  testWidgets('Al tocarlo el vidrio se hunde y vuelve; con "reducir animaciones", no', (tester) async {
    Future<double> pressAfterTap({required bool calm}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: calm),
              child: const Center(child: Glass(child: SizedBox(width: 200, height: 80))),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byType(LiquidGlass)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final render = tester.renderObject<RenderLiquidGlass>(
        find.descendant(of: find.byType(LiquidGlass), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_LiquidGlassBox')),
      );
      final pressed = render.debugPress;
      await gesture.up();
      await tester.pumpAndSettle();
      expect(render.debugPress, 0, reason: 'al soltar vuelve');
      return pressed;
    }

    expect(await pressAfterTap(calm: false), greaterThan(0.9));
    expect(await pressAfterTap(calm: true), 0);
  });

  testWidgets('Un toque rapidísimo (apretar y soltar enseguida) no lo deja hundido', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: Glass(child: SizedBox(width: 200, height: 80)))));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(LiquidGlass)));
    await gesture.up();
    await tester.pumpAndSettle();
    final render = tester.renderObject<RenderLiquidGlass>(
      find.descendant(of: find.byType(LiquidGlass), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_LiquidGlassBox')),
    );
    expect(render.debugPress, 0);
  });
}
