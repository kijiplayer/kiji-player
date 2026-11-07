// Video de fondo en la PC con la librería completa de media_kit, SOLO EN PC:
//   flutter test integration_test/fondo_video_pc_test.dart -d windows
// Arma un video inventado (colores que cambian, sin sonido ni nada real) y revisa que media_kit lo
// reproduzca en bucle, mudo, con su tamaño de video.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Un AVI sin comprimir (RGB) de [frames] cuadros de [w]×[h] a [fps], de colores que cambian.
File _video(Directory dir, {int w = 64, int h = 48, int frames = 20, int fps = 10}) {
  final row = ((w * 3 + 3) ~/ 4) * 4;
  final frameSize = row * h;
  final out = BytesBuilder();
  void u32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void tag(String s) => out.add(s.codeUnits);

  final strh = BytesBuilder();
  final strf = BytesBuilder();
  // Encabezados en buffers aparte para saber sus tamaños.
  void w32(BytesBuilder b, int v) => b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void w16(BytesBuilder b, int v) => b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  strh.add('vids'.codeUnits);
  strh.add('DIB '.codeUnits);
  for (final v in [0, 0, 0, 1, fps, 0, frames, frameSize, 0xFFFFFFFF, 0]) {
    w32(strh, v);
  }
  for (final v in [0, 0, w, h]) {
    w16(strh, v);
  }
  for (final v in [40, w, h]) {
    w32(strf, v);
  }
  w16(strf, 1);
  w16(strf, 24);
  for (final v in [0, frameSize, 0, 0, 0, 0]) {
    w32(strf, v);
  }
  final strl = 4 + (8 + strh.length) + (8 + strf.length);
  final hdrl = 4 + (8 + 56) + (8 + strl);
  final movi = 4 + frames * (8 + frameSize);
  final idx = frames * 16;
  final riff = 4 + (8 + hdrl) + (8 + movi) + (8 + idx);

  tag('RIFF');
  u32(riff);
  tag('AVI ');
  tag('LIST');
  u32(hdrl);
  tag('hdrl');
  tag('avih');
  u32(56);
  for (final v in [1000000 ~/ fps, frameSize * fps, 0, 0x10, frames, 0, 1, frameSize, w, h, 0, 0, 0, 0]) {
    u32(v);
  }
  tag('LIST');
  u32(strl);
  tag('strl');
  tag('strh');
  u32(strh.length);
  out.add(strh.toBytes());
  tag('strf');
  u32(strf.length);
  out.add(strf.toBytes());
  tag('LIST');
  u32(movi);
  tag('movi');
  for (var f = 0; f < frames; f++) {
    tag('00db');
    u32(frameSize);
    final pixels = Uint8List(frameSize);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * row + x * 3;
        pixels[i] = (f * 12) % 256; // azul
        pixels[i + 1] = (x * 4) % 256; // verde
        pixels[i + 2] = (y * 5 + f * 7) % 256; // rojo
      }
    }
    out.add(pixels);
  }
  tag('idx1');
  u32(idx);
  for (var f = 0; f < frames; f++) {
    tag('00db');
    u32(0x10);
    u32(4 + f * (8 + frameSize));
    u32(frameSize);
  }
  return File('${dir.path}/fondo.avi')..writeAsBytesSync(out.toBytes());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la PC reproduce un video de fondo: mudo, en bucle y con imagen', (tester) async {
    MediaKit.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('kiji_fondo_video_');
    final player = Player();
    final controller = VideoController(player);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Video(controller: controller, controls: NoVideoControls, fit: BoxFit.cover)),
    ));
    await tester.runAsync(() async {
      await player.setVolume(0);
      await player.setPlaylistMode(PlaylistMode.single);
      await player.open(Media(_video(dir).path));
      // El video dura 2 s: después de 3,5 s tiene que haber vuelto a empezar (bucle).
      var loops = 0;
      Duration last = Duration.zero;
      for (var i = 0; i < 35; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final p = player.state.position;
        if (p < last - const Duration(milliseconds: 500)) loops++;
        last = p;
      }
      debugPrint('=== PRUEBA: ancho ${player.state.width}×${player.state.height}, volumen ${player.state.volume}, vueltas $loops ===');
      expect(player.state.width, 64, reason: 'se decodifica el video');
      expect(player.state.volume, 0, reason: 'sin sonido');
      expect(loops, greaterThanOrEqualTo(1), reason: 'en bucle');
      await player.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
