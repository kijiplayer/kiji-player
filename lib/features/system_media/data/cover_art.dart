import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../customize/data/artwork_cache.dart' show ArtworkCache, artworkCacheName;

/// Imagen para la notificación / pantalla de bloqueo.
///
/// Android colorea la notificación con los colores de esta imagen, así que
/// si la canción no tiene portada se genera una con el mismo degradado que
/// muestra el reproductor ([AlbumCover]): la notificación queda del mismo
/// color que la pantalla de Kiji.
Future<Uri?> coverArtFor(Track track) async {
  final thumbnail = track.thumbnailUrl;
  if (thumbnail != null && thumbnail.startsWith('http')) {
    return Uri.parse(fullThumbnailUrl(thumbnail));
  }
  // Canciones de YouTube sin miniatura guardada (descargas, importadas, radio): la del video.
  final videoId = track.youtubeVideoId;
  if (videoId != null) return Uri.parse(youtubeThumbnailUrl(videoId));
  // Música del equipo: la portada incluida en el archivo (guardada al escanear) o la de su carpeta.
  if (track.source == TrackSource.local) {
    try {
      final embedded = File(
        p.join((await getApplicationSupportDirectory()).path, 'artwork', artworkCacheName(ArtworkCache.fileKey(track.audioUrl))),
      );
      if (await embedded.exists()) return Uri.file(embedded.path);
      if (thumbnail != null && thumbnail.isNotEmpty && await File(thumbnail).exists()) return Uri.file(thumbnail);
    } catch (error) {
      debugPrint('=== CONTROLES: sin la portada del archivo: ${error.runtimeType} ===');
    }
  }
  try {
    return await _colorCover(track.coverColor);
  } catch (error) {
    debugPrint('=== CONTROLES: no se pudo generar la portada de color: $error ===');
    return null;
  }
}

/// Miniatura de un video de YouTube por su id (para canciones sin miniatura guardada).
String youtubeThumbnailUrl(String videoId) => 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

/// Las portadas de YouTube Music (lh3/yt3.googleusercontent, ggpht) piden su tamaño en la URL
/// ("=w120-h120-l90-rj", "=s120"): el servidor entrega la misma foto al lado que se pida, hasta
/// la original (~3000 px). Las demás URL quedan como están.
final _sizeInUrl = RegExp(r'=(w\d+-h\d+|s\d+)(?=-|$)');
final _resizableHost = RegExp(r'^https://[^/]*(googleusercontent\.com|ggpht\.com)/');

/// La misma portada a [pixels] px de lado.
String sizedThumbnailUrl(String url, int pixels) => _resizableHost.hasMatch(url)
    ? url.replaceFirstMapped(_sizeInUrl, (_) => '=w$pixels-h$pixels')
    : url;

/// Para listas y tarjetas (las miniaturas de la búsqueda vienen en 60 o 120 px).
String largerThumbnailUrl(String url) => sizedThumbnailUrl(url, 544);

/// Alta calidad: notificación, pantalla de bloqueo, controles de Windows y lo que se guarda en
/// el dispositivo (caché de carátulas y portadas de las descargas).
const fullCoverPixels = 1200;
String fullThumbnailUrl(String url) => sizedThumbnailUrl(url, fullCoverPixels);

/// Para mostrar a [pixels] px reales de pantalla: nunca menos de lo que se ve (hasta 2048).
String thumbnailUrlForPixels(String url, int pixels) => pixels <= 544
    ? largerThumbnailUrl(url)
    : sizedThumbnailUrl(url, pixels <= fullCoverPixels ? fullCoverPixels : 2048);

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
