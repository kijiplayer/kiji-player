import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../utils/json_file.dart';
import '../../../utils/startup_log.dart';
import '../../yt_music/domain/subtitle_parser.dart';
import 'local_scanner.dart';

/// Cuánto tardó el último escaneo y cuántos archivos se leyeron de verdad.
class ScanStats {
  const ScanStats({required this.total, required this.read, required this.reused, required this.elapsed});

  final int total;
  final int read;
  final int reused;
  final Duration elapsed;
}

/// El escaneo con caché, igual en el teléfono y en la PC: lo ya leído se guarda en
/// `local_library_cache.json` (es caché: se puede borrar, no va en la copia de seguridad) y la
/// próxima vez solo se leen los archivos nuevos o cambiados. Las portadas incluidas van a la caché
/// de portadas (`artwork/`).
class LocalScanStore {
  LocalScanStore({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDirectory;
  JsonFile? _file;

  /// El último escaneo (para el reporte de tiempos y las pruebas).
  ScanStats? lastStats;

  List<Track>? _last;
  DateTime? _lastAt;

  Future<JsonFile> _cacheFile() async =>
      _file ??= JsonFile(p.join((await _baseDirectory()).path, 'local_library_cache.json'), logTag: 'BIBLIOTECA');

  /// Escanea: [roots] (carpetas, PC) o [entries] (archivos ya listados, Android). Si se escaneó
  /// hace menos de 10 s se devuelve lo mismo (la Biblioteca y la búsqueda lo piden casi a la vez);
  /// [force] ("Volver a escanear") vuelve a leer todos los archivos.
  Future<List<Track>> scan({List<String>? roots, List<ScanEntry>? entries, bool force = false}) async {
    // Uno a la vez: si ya hay un escaneo en curso, se espera ese (dos a la vez se pisan al
    // guardar las portadas). "Volver a escanear" espera y después lee todo.
    final running = _running;
    if (running != null) {
      final result = await running;
      if (!force) return result;
    }
    final future = _scan(roots: roots, entries: entries, force: force);
    _running = future;
    try {
      return await future;
    } finally {
      if (identical(_running, future)) _running = null;
    }
  }

  Future<List<Track>>? _running;

  Future<List<Track>> _scan({List<String>? roots, List<ScanEntry>? entries, required bool force}) async {
    final last = _last, lastAt = _lastAt;
    if (!force && last != null && lastAt != null && DateTime.now().difference(lastAt) < const Duration(seconds: 10)) {
      return last;
    }
    final watch = Stopwatch()..start();
    final file = await _cacheFile();
    final saved = await file.read();
    final cache = saved is Map<String, dynamic> && saved['version'] == 1 && saved['files'] is Map<String, dynamic>
        ? saved['files'] as Map<String, dynamic>
        : <String, dynamic>{};
    final artworkDir = p.join((await _baseDirectory()).path, 'artwork');
    // Recorrer y leer etiquetas puede tardar: en otro isolate, para que la interfaz no se trabe.
    // Con límite: archivos "solo en la nube" (OneDrive) pueden quedarse esperando al leerlos.
    final outcome = await StartupLog.guard(
      'escanear la música', // l10n-ignore
      () => Isolate.run(
        () => scanLibrary(
          ScanJob(
            entries: entries ?? listAudioFiles(roots ?? const []),
            cache: cache,
            artworkDir: artworkDir,
            force: force,
          ),
        ),
      ),
      limit: const Duration(minutes: 5),
    );
    if (outcome == null) return _last ?? const [];
    await file.write({'version': 1, 'files': outcome.cache});
    final tracks = [for (final song in outcome.songs) trackFromScan(song)];
    watch.stop();
    lastStats = ScanStats(total: tracks.length, read: outcome.read, reused: outcome.reused, elapsed: watch.elapsed);
    debugPrint(
      '=== BIBLIOTECA: ${tracks.length} canciones (${outcome.read} leídas, ${outcome.reused} de la caché) '
      'en ${watch.elapsedMilliseconds} ms ===',
    );
    _last = tracks;
    _lastAt = DateTime.now();
    return tracks;
  }
}

/// Una canción escaneada (JSON) como [Track]: con su color y "Artista desconocido" en el idioma
/// de la app si no tiene.
Track trackFromScan(Map<String, dynamic> song) {
  final artist = (song['artist'] as String?) ?? '';
  return Track.fromJson({
    ...song,
    'artist': artist.isEmpty ? unknownArtist : artist,
    'coverColor': colorFromSeed(song['title'] as String? ?? '').toARGB32(),
  });
}

/// El color de la portada generada (siempre el mismo para el mismo título).
Color colorFromSeed(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (acc, unit) => acc + unit);
  final hue = (hash * 37) % 360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();
}
