// Vidrio líquido real (0.9): se usa solo si el dispositivo pudo cargarlo, si está prendido en
// Configuración y si nada falló; si no, el vidrio de siempre. En la PC nunca se intenta.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';
import 'package:kiji_player/widgets/nocturne/liquid_glass.dart';
import 'package:kiji_player/widgets/nocturne/real_glass.dart';

void main() {
  tearDown(() {
    RealGlass.debugReset();
    KijiLook.style = KijiStyle.nocturne;
    KijiColors.palette = KijiPalette.nocturne;
  });

  test('Solo con todo a favor: cargado, prendido y sin fallas', () {
    expect(RealGlass.active.value, isFalse, reason: 'hasta que cargue, el de siempre');
    RealGlass.debugSet(ready: true);
    expect(RealGlass.active.value, isTrue);
    RealGlass.userOn.value = false;
    expect(RealGlass.active.value, isFalse, reason: 'apagado en Configuración');
    RealGlass.userOn.value = true;
    expect(RealGlass.active.value, isTrue);
    RealGlass.fail('prueba');
    expect(RealGlass.active.value, isFalse, reason: 'una falla vuelve al de siempre');
  });

  test('En la PC no se intenta (Windows y Linux quedan con el vidrio de siempre)', () async {
    if (Platform.isAndroid) return;
    expect(RealGlass.platformCanTry, isFalse);
    await RealGlass.start();
    expect(RealGlass.active.value, isFalse);
  });

  testWidgets('Sin vidrio real se dibuja el de siempre; Papel nunca usa el real', (tester) async {
    Widget glass() => const MaterialApp(
      home: Center(
        child: LiquidGlass(borderRadius: BorderRadius.all(Radius.circular(16)), child: SizedBox(width: 100, height: 60)),
      ),
    );
    await tester.pumpWidget(glass());
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_LiquidGlassBox'), findsOneWidget);

    KijiLook.style = KijiStyle.paper;
    KijiColors.palette = KijiPalette.paper;
    RealGlass.debugSet(ready: true);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(glass());
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_LiquidGlassBox'), findsOneWidget);
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}
