// Vidrio líquido real (0.9): refracción con un shader propio sobre el fondo de Kiji. Se usa solo si
// el shader cargó, si está prendido en Configuración y si nada falló; si no, el vidrio de siempre.
import 'dart:ui' as ui;

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

  test('El shader está en el pubspec y carga', () async {
    final program = await ui.FragmentProgram.fromAsset(RealGlass.asset);
    expect(program.fragmentShader(), isNotNull);
  });

  test('Solo con todo a favor: cargado, prendido y sin fallas', () async {
    expect(RealGlass.active.value, isFalse, reason: 'hasta que cargue, el de siempre');
    RealGlass.debugSet(program: await ui.FragmentProgram.fromAsset(RealGlass.asset));
    expect(RealGlass.active.value, isTrue);
    expect(RealGlass.program, isNotNull);
    RealGlass.userOn.value = false;
    expect(RealGlass.active.value, isFalse, reason: 'apagado en Configuración');
    expect(RealGlass.program, isNull);
    RealGlass.userOn.value = true;
    RealGlass.fail('prueba');
    expect(RealGlass.active.value, isFalse, reason: 'una falla vuelve al de siempre');
  });

  for (final style in KijiStyle.values) {
    testWidgets('Con el vidrio real se dibuja sin errores (${style.name})', (tester) async {
      KijiLook.style = style;
      KijiColors.palette = KijiPalette.forStyle(style);
      final program = await tester.runAsync(() => ui.FragmentProgram.fromAsset(RealGlass.asset));
      RealGlass.debugSet(program: program);
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: LiquidGlass(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              child: SizedBox(width: 100, height: 60),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      RealGlass.userOn.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
