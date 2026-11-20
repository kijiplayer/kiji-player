// La onda de una canción que recién empieza ya tiene el color del estilo (antes arrancaba gris:
// todo lo que falta se pintaba en blanco al 16 %).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';
import 'package:kiji_player/widgets/nocturne/waveform_progress.dart';

void main() {
  testWidgets('Nocturne, al empezar (progreso 0): la onda tiene color, no es gris', (tester) async {
    KijiLook.style = KijiStyle.nocturne;
    KijiColors.palette = KijiPalette.nocturne;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 300,
                height: 44,
                child: WaveformProgress(seed: 'yt-aaaaaaaaaaa', progress: 0, onSeek: (_) {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!;
    });
    // El píxel con más "color" (diferencia entre canales) de toda la onda.
    var chroma = 0;
    for (var i = 0; i + 3 < data!.lengthInBytes; i += 4) {
      final r = data.getUint8(i), g = data.getUint8(i + 1), b = data.getUint8(i + 2);
      final c = [r, g, b].reduce((a, x) => a > x ? a : x) - [r, g, b].reduce((a, x) => a < x ? a : x);
      if (c > chroma) chroma = c;
    }
    expect(chroma, greaterThan(30), reason: 'violeta/cian tenue, no gris');
  });
}
