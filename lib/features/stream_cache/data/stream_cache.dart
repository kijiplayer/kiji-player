// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../playback/DownloadUtil.kt (`playerCache`:
// caché de lo escuchado, separada de las descargas, con límite de espacio).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../yt_music/data/ytm_client.dart';

/// Caché de lo que se va escuchando de YouTube: una canción que ya sonó
/// entera no se vuelve a bajar, y suena aunque no haya conexión.
///
/// No es lo mismo que una descarga: el sistema puede vaciar esta carpeta y
/// Kiji borra lo más viejo cuando se pasa del límite.
class StreamCache {
  StreamCache({Future<Directory> Function()? baseDirectory})
      : _baseDirectory = baseDirectory ?? getApplicationCacheDirectory;

  /// Límite por defecto (configurable desde la Tarea G).
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
  /// `LockCachingAudioSource` escribe `<archivo>.part` (y `.mime`) mientras
  /// baja y lo renombra al terminar, así que solo cuenta el archivo final.
  Future<File?> completeFile(String videoId) async {
    final dir = await directory();
    for (final ext in const ['webm', 'm4a']) {
      final file = File(p.join(dir.path, '$videoId.$ext'));
      if (await file.exists()) return file;
    }
    return null;
  }

  /// Canciones que se están guardando ahora mismo. Dos fuentes con caché
  /// escribiendo el mismo archivo a la vez lo corrompen (pasaba al tocar la
  /// misma canción que se había restaurado al abrir).
  final Set<String> _caching = {};

  /// Fuente que reproduce [stream] y la va guardando en caché, o null si esa
  /// canción ya se está guardando (entonces se reproduce sin caché).
  Future<AudioSource?> sourceFor(String videoId, YtStream stream) async {
    if (_caching.contains(videoId)) {
      debugPrint('=== CACHE: $videoId ya se está guardando, esta vez sin caché ===');
      return null;
    }
    final mime = Uri.parse(stream.url).queryParameters['mime'] ?? '';
    final ext = mime.contains('webm') ? 'webm' : 'm4a';
    // Experimental en just_audio, pero es justo lo que pide el plan (Tarea D).
    // Si falla, el reproductor reintenta sin caché (ver PlaybackNotifier).
    // ignore: experimental_member_use
    final source = LockCachingAudioSource(
      Uri.parse(stream.url),
      headers: {'User-Agent': stream.userAgent},
      cacheFile: File(p.join((await directory()).path, '$videoId.$ext')),
    );
    _caching.add(videoId);
    late final StreamSubscription<double> subscription;
    void finished() {
      _caching.remove(videoId);
      subscription.cancel();
    }

    subscription = source.downloadProgressStream.listen(
      (progress) {
        if (progress >= 1.0) finished();
      },
      onError: (Object error) {
        debugPrint('=== CACHE: se cortó el guardado de $videoId: $error ===');
        finished();
      },
      onDone: finished,
    );
    return source;
  }

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
