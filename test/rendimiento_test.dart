// Rendimiento 0.9 (docs/RENDIMIENTO_0.9.md): que no se pierdan los arreglos medidos.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/utils/image_decode.dart';

void main() {
  test('Windows dibuja con Skia (Impeller sobre ANGLE tardaba ~20 ms por cuadro)', () {
    final runner = File('windows/runner/main.cpp').readAsStringSync();
    expect(runner, contains('set_impeller_switch(flutter::ImpellerSwitch::Disabled)'));
  });

  testWidgets('Las miniaturas se decodifican al tamaño en pantalla', (tester) async {
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    late int size;
    await tester.pumpWidget(Builder(builder: (context) {
      size = decodeSize(context, 44);
      return const SizedBox();
    }));
    expect(size, 116);
  });
}
