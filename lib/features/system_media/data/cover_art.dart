import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';

/// Imagen para la notificación / pantalla de bloqueo.
///
/// Android colorea la notificación con los colores de esta imagen, así que
/// si la canción no tiene portada se genera una con el mismo degradado que
/// muestra el reproductor ([AlbumCover]): la notificación queda del mismo
/// color que la pantalla de Kiji.
Future<Uri?> coverArtFor(Track track) async {
  final thumbnail = track.thumbnailUrl;
  if (thumbnail != null && thumbnail.startsWith('http')) {
    return Uri.parse(largerThumbnailUrl(thumbnail));
  }
  try {
    return await _colorCover(track.coverColor);
  } catch (error) {
    debugPrint('=== CONTROLES: no se pudo generar la portada de color: $error ===');
    return null;
  }
}

/// Las miniaturas de la búsqueda vienen en 60×60; para la pantalla de
/// bloqueo pedimos una más grande ("=w60-h60" → "=w544-h544").
String largerThumbnailUrl(String url) =>
    url.replaceFirstMapped(RegExp(r'=w\d+-h\d+'), (_) => '=w544-h544');

Future<Uri> _colorCover(Color color) async {
  final dir = Directory(p.join((await getTemporaryDirectory()).path, 'covers'));
  final file = File(p.join(dir.path, 'cover_${color.toARGB32().toRadixString(16)}.png'));
  if (await file.exists()) return file.uri;

  const size = 512.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const rect = Rect.fromLTWH(0, 0, size, size);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, Color.lerp(color, Colors.black, 0.45)!],
      ).createShader(rect),
  );
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  await dir.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  return file.uri;
}
