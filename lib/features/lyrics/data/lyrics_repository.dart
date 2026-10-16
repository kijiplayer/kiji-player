// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: lyrics/LyricsHelper.kt (primero la caché, después las fuentes).

import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';
import '../domain/lyrics.dart';
import 'lrclib_client.dart';

/// Lo necesario para buscar una letra. Es un registro: dos pedidos con los
/// mismos datos son iguales (sirve de clave para Riverpod).
typedef LyricsRequest = ({
  String id,
  String title,
  String artist,
  String? album,
  int durationMs,

  /// Ruta del archivo, si es una canción local (puede traer la letra adentro).
  String? localPath,
});

/// Letras guardadas en `<appSupportDir>/lyrics/`, para pedirlas una sola vez.
class LyricsRepository {
  LyricsRepository({
    LrcLibClient? client,
    Future<Directory> Function()? baseDirectory,
    DateTime Function()? clock,
  })  : _client = client ?? LrcLibClient(),
        _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
        _clock = clock ?? DateTime.now;

  /// "No encontrada" se vuelve a preguntar pasado este tiempo (LRCLIB suma
  /// letras todo el tiempo).
  static const notFoundRetry = Duration(days: 7);

  final LrcLibClient _client;
  final Future<Directory> Function() _baseDirectory;
  final DateTime Function() _clock;

  Future<JsonFile> _fileFor(String id) async {
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return JsonFile(
      p.join((await _baseDirectory()).path, 'lyrics', '$safe.json'),
      logTag: 'LETRAS',
    );
  }

  Future<Lyrics> get(LyricsRequest request) async {
    final file = await _fileFor(request.id);

    // 1) Caché.
    final cached = await file.read();
    if (cached is Map<String, dynamic>) {
      try {
        final lyrics = Lyrics.fromJson(cached['lyrics'] as Map<String, dynamic>);
        final savedAt = DateTime.fromMillisecondsSinceEpoch(cached['savedAt'] as int);
        if (!lyrics.isEmpty || _clock().difference(savedAt) < notFoundRetry) return lyrics;
      } catch (error) {
        await file.deleteCorrupt(error);
      }
    }

    // 2) Incluida en el archivo local (sin internet).
    final path = request.localPath;
    if (path != null && path.isNotEmpty) {
      final embedded = await Isolate.run(() => readEmbeddedLyrics(path));
      if (embedded != null && !embedded.isEmpty) {
        await _save(file, embedded);
        return embedded;
      }
    }

    // 3) LRCLIB. Si no hay conexión, no se guarda nada (se reintenta luego).
    final lyrics = await _client.fetch(
      title: request.title,
      artist: request.artist,
      album: request.album,
      duration: request.durationMs > 0 ? Duration(milliseconds: request.durationMs) : null,
    );
    await _save(file, lyrics);
    return lyrics;
  }

  Future<void> _save(JsonFile file, Lyrics lyrics) =>
      file.write({'savedAt': _clock().millisecondsSinceEpoch, 'lyrics': lyrics.toJson()});
}

/// Letra guardada en las etiquetas del archivo (LRC o texto), o null.
Lyrics? readEmbeddedLyrics(String path) {
  try {
    final text = readMetadata(File(path)).lyrics?.trim();
    if (text == null || text.isEmpty) return null;
    final synced = parseLrc(text);
    return synced.isNotEmpty
        ? Lyrics(synced: synced, source: LyricsSource.embedded)
        : Lyrics(plain: text, source: LyricsSource.embedded);
  } catch (error) {
    debugPrint('=== LETRAS: sin letra incluida en $path: $error ===');
    return null;
  }
}
