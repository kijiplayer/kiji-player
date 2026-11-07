import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/downloaded_track.dart';
import 'download_service.dart';

/// Las descargas de antes de la 0.8.0 guardaron la portada chica de la búsqueda (120 px). Con
/// internet, en segundo plano y de a una, se baja la misma portada en alta calidad y se reemplaza
/// la guardada. El audio no se toca.
class CoverUpgrade {
  CoverUpgrade({
    required this.coverUrlFor,
    required this.download,
    required this.replace,
    this.pause = const Duration(seconds: 1),
  });

  /// La portada de la canción en YouTube Music (null si no se pudo saber).
  final Future<String?> Function(String videoId) coverUrlFor;

  /// Baja la portada en alta calidad; devuelve el nombre del archivo nuevo (null si falló).
  final Future<String?> Function(String videoId, String url) download;

  /// Anota el archivo nuevo en el índice y borra el viejo.
  final Future<void> Function(String videoId, String fileName) replace;

  /// Entre una y otra, para no competir con lo que suena.
  final Duration pause;

  /// Las que todavía tienen la portada vieja (o ninguna).
  static bool needsUpgrade(DownloadedTrack track) =>
      !(track.thumbnailFileName?.endsWith(DownloadService.hqThumbnailSuffix) ?? false);

  /// Mejora las que hagan falta. Si fallan 3 seguidas (sin internet, YouTube no responde), deja
  /// el resto para la próxima vez que se abra Kiji. Devuelve cuántas se mejoraron.
  Future<int> run(Iterable<DownloadedTrack> tracks, {void Function(String videoId, String fileName)? onDone}) async {
    final pending = tracks.where(needsUpgrade).toList();
    if (pending.isEmpty) return 0;
    debugPrint('=== DESCARGAS: ${pending.length} portadas viejas para mejorar en segundo plano ===');
    var done = 0, failures = 0;
    for (final track in pending) {
      if (failures >= 3) {
        debugPrint('=== DESCARGAS: portadas, se sigue la próxima vez ($done mejoradas) ===');
        break;
      }
      try {
        final url = await coverUrlFor(track.videoId);
        final fileName = url == null ? null : await download(track.videoId, url);
        if (fileName == null) {
          failures++;
          continue;
        }
        failures = 0;
        await replace(track.videoId, fileName);
        onDone?.call(track.videoId, fileName);
        done++;
      } catch (error) {
        failures++;
        debugPrint('=== DESCARGAS: no se pudo mejorar la portada de ${track.videoId}: $error ===');
      }
      await Future<void>.delayed(pause);
    }
    if (done > 0) debugPrint('=== DESCARGAS: $done portadas mejoradas a alta calidad ===');
    return done;
  }
}
