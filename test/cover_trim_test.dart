// Portadas con franjas (0.9): imágenes inventadas, hechas en la prueba.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kiji_player/utils/cover_trim.dart';

/// Una «miniatura de video» de 480×360: franjas lilas, adentro franjas negras, y en el medio un
/// degradado (la portada de verdad).
Uint8List _letterboxed() {
  final image = img.Image(width: 480, height: 360);
  img.fill(image, color: img.ColorRgb8(170, 150, 190));
  img.fillRect(image, x1: 0, y1: 30, x2: 479, y2: 329, color: img.ColorRgb8(0, 0, 0));
  for (var y = 75; y < 285; y++) {
    for (var x = 0; x < 480; x++) {
      image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('Quita las franjas lilas y negras, una dentro de otra', () {
    final out = img.decodeImage(trimFlatBorders(_letterboxed())!)!;
    expect(out.width, 480);
    expect(out.height, closeTo(210, 3));
  });

  test('Una portada sin franjas no se toca', () {
    final image = img.Image(width: 300, height: 300);
    for (var y = 0; y < 300; y++) {
      for (var x = 0; x < 300; x++) {
        image.setPixelRgb(x, y, x % 256, y % 256, 120);
      }
    }
    expect(trimFlatBorders(Uint8List.fromList(img.encodePng(image))), isNull);
  });

  test('Una portada casi toda lisa (un fondo negro con algo chico) no se recorta', () {
    final image = img.Image(width: 300, height: 300);
    img.fill(image, color: img.ColorRgb8(0, 0, 0));
    img.fillRect(image, x1: 140, y1: 140, x2: 160, y2: 160, color: img.ColorRgb8(255, 255, 255));
    expect(trimFlatBorders(Uint8List.fromList(img.encodePng(image))), isNull);
  });

  test('Si no es una imagen, no pasa nada', () {
    expect(trimFlatBorders(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
