import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Portadas con franjas (0.9): las miniaturas de video de YouTube suelen traer bandas negras (y a
/// veces de un color liso) arriba y abajo. Se recortan las franjas de un solo color de los cuatro
/// lados, también si vienen una dentro de otra (negro dentro de lila). Si no hay franjas, o si la
/// imagen es casi toda de un color, no se toca nada (devuelve null).
Uint8List? trimFlatBorders(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var left = 0, top = 0, right = decoded.width, bottom = decoded.height;

  // ¿La fila (o columna) es casi toda del color del borde?
  bool flatRow(int y, int x0, int x1, img.Pixel ref) {
    var same = 0;
    for (var x = x0; x < x1; x++) {
      if (_close(decoded.getPixel(x, y), ref)) same++;
    }
    return same >= (x1 - x0) * 0.98;
  }

  bool flatCol(int x, int y0, int y1, img.Pixel ref) {
    var same = 0;
    for (var y = y0; y < y1; y++) {
      if (_close(decoded.getPixel(x, y), ref)) same++;
    }
    return same >= (y1 - y0) * 0.98;
  }

  // Hasta 3 vueltas: franjas una dentro de otra.
  for (var round = 0; round < 3; round++) {
    final before = (left, top, right, bottom);
    if (right - left < 8 || bottom - top < 8) return null;
    final topRef = decoded.getPixel((left + right) ~/ 2, top);
    while (top < bottom - 1 && flatRow(top, left, right, topRef)) {
      top++;
    }
    final bottomRef = decoded.getPixel((left + right) ~/ 2, bottom - 1);
    while (bottom - 1 > top && flatRow(bottom - 1, left, right, bottomRef)) {
      bottom--;
    }
    final leftRef = decoded.getPixel(left, (top + bottom) ~/ 2);
    while (left < right - 1 && flatCol(left, top, bottom, leftRef)) {
      left++;
    }
    final rightRef = decoded.getPixel(right - 1, (top + bottom) ~/ 2);
    while (right - 1 > left && flatCol(right - 1, top, bottom, rightRef)) {
      right--;
    }
    if (before == (left, top, right, bottom)) break;
  }

  final width = right - left, height = bottom - top;
  // Nada que recortar (menos de un 2 % por lado) o casi toda lisa: se deja como estaba.
  final trimmed = 1 - (width * height) / (decoded.width * decoded.height);
  if (trimmed < 0.04) return null;
  if (width < decoded.width * 0.3 || height < decoded.height * 0.3) return null;
  final cropped = img.copyCrop(decoded, x: left, y: top, width: width, height: height);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
}

bool _close(img.Pixel a, img.Pixel b) =>
    (a.r - b.r).abs() <= 18 && (a.g - b.g).abs() <= 18 && (a.b - b.b).abs() <= 18;

/// Recorta las franjas de la portada guardada en [path] (en otro hilo). true si la cambió.
Future<bool> trimCoverFile(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return false;
    final result = await compute(trimFlatBorders, await file.readAsBytes());
    if (result == null) return false;
    final temp = File('$path.part');
    await temp.writeAsBytes(result, flush: true);
    await temp.rename(path);
    return true;
  } catch (error) {
    debugPrint('=== PORTADAS: no se pudo recortar una portada (${error.runtimeType}) ===');
    return false;
  }
}
