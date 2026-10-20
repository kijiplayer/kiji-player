// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../playback/DownloadUtil.kt (`playerCache`:
// caché de lo escuchado, separada de las descargas, con límite de espacio).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';


/// Caché de lo que se va escuchando de YouTube: una canción que ya sonó
/// entera no se vuelve a bajar, y suena aunque no haya conexión.
///
/// No es lo mismo que una descarga: el sistema puede vaciar esta carpeta y
/// Kiji borra lo más viejo cuando se pasa del límite.
class StreamCache {
  StreamCache({Future<Directory> Function()? baseDirectory})
      : _baseDirectory = baseDirectory ?? getApplicationCacheDirectory;

  /// Límite por defecto (configurable).
  static const defaultLimitBytes = 300 * 1024 * 1024;

  final Future<Directory> Function() _baseDirectory;
  Directory? _dir;

  Future<Directory> directory() async {
    if (_dir != null) return _dir!;
    final dir = Directory(p.join((await _baseDirectory()).path, 'stream_cache'));
    await dir.create(recursive: true);
    return _dir = dir;
  }

  /// Archivo completo en caché para [videoId], o null.
  /// La fuente por pedazos escribe `<archivo>.part` mientras baja y lo renombra
  /// al terminar, así que solo cuenta el archivo final.
  Future<File?> completeFile(String videoId) async {
    final dir = await directory();
    for (final ext in const ['webm', 'm4a']) {
      final file = File(p.join(dir.path, '$videoId.$ext'));
      if (await file.exists()) return file;
    }
    return null;
  }

  /// Archivo donde se guarda [videoId] cuando suena entero (lo escribe la fuente por
  /// pedazos, que primero usa `<archivo>.part`).
  Future<File> targetFor(String videoId, String extension) async =>
      File(p.join((await directory()).path, '$videoId.$extension'));

  /// Marca [file] como recién usado (para borrar primero lo más viejo).
  Future<void> touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } catch (error) {
      debugPrint('=== CACHE: no se pudo marcar como usado ${file.path}: $error ===');
    }
  }

  /// Bytes que ocupa la caché.
  Future<int> sizeBytes() async {
    var total = 0;
    await for (final entity in (await directory()).list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Borra canciones completas, de la menos usada a la más usada, hasta que
  /// la caché ocupe menos de [limitBytes]. Nunca toca [keepVideoId] (la que
  /// está sonando) ni archivos a medio bajar.
  Future<void> evict({required int limitBytes, String? keepVideoId}) async {
    try {
      final files = <File, FileStat>{};
      var total = 0;
      await for (final entity in (await directory()).list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        total += stat.size;
        final name = p.basename(entity.path);
        final complete = !name.endsWith('.part') && !name.endsWith('.mime');
        final isCurrent = keepVideoId != null && name.startsWith('$keepVideoId.');
        if (isCurrent) continue;
        if (complete) {
          files[entity] = stat;
        } else if (name.endsWith('.part') &&
            DateTime.now().difference(stat.modified) > const Duration(hours: 1)) {
          // Canción que se dejó de escuchar a la mitad: no se va a completar.
          await entity.delete();
          total -= stat.size;
        }
      }
      if (total <= limitBytes) return;

      final oldestFirst = files.entries.toList()
        ..sort((a, b) => a.value.modified.compareTo(b.value.modified));
      for (final entry in oldestFirst) {
        if (total <= limitBytes) break;
        await entry.key.delete();
        final mime = File('${entry.key.path}.mime');
        if (await mime.exists()) await mime.delete();
        total -= entry.value.size;
        debugPrint('=== CACHE: borrada ${p.basename(entry.key.path)} para respetar el límite ===');
      }
    } catch (error) {
      debugPrint('=== CACHE: error al limpiar: $error ===');
    }
  }

  /// Vacía la caché entera (opción de Configuración).
  Future<void> clear() async {
    final dir = await directory();
    await for (final entity in dir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (error) {
        debugPrint('=== CACHE: no se pudo borrar ${entity.path}: $error ===');
      }
    }
  }
}
