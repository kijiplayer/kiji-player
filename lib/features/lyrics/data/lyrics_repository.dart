// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: lyrics/LyricsHelper.kt (primero la caché, después las fuentes, y si
// una falla se prueba la siguiente).

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';
import '../domain/lyrics.dart';
import 'lrclib_client.dart';
import 'lyrics_sources.dart';

import 'package:kiji_player/l10n/l10n.dart';

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

/// Qué respondió una fuente al comparar (⋯ → Fuente).
enum LyricsProbeState { off, none, failed, plain, synced }

class LyricsProbe {
  const LyricsProbe(this.source, this.state, [this.lyrics]);

  final LyricsSource source;
  final LyricsProbeState state;
  final Lyrics? lyrics;
}

/// Letras guardadas en `<appSupportDir>/lyrics/`, para pedirlas una sola vez.
class LyricsRepository {
  LyricsRepository({
    LrcLibClient? client,
    List<LyricsFetcher>? fetchers,
    Future<Directory> Function()? baseDirectory,
    DateTime Function()? clock,
  }) : _fetchers = fetchers ?? defaultLyricsFetchers(lrclib: client),
       _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now;

  /// "No encontrada" se vuelve a preguntar pasado este tiempo (LRCLIB suma
  /// letras todo el tiempo).
  static const notFoundRetry = Duration(days: 7);

  final List<LyricsFetcher> _fetchers;
  final Future<Directory> Function() _baseDirectory;
  final DateTime Function() _clock;

  Future<JsonFile> _fileFor(String id) async {
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return JsonFile(p.join((await _baseDirectory()).path, 'lyrics', '$safe.json'), logTag: 'LETRAS');
  }

  /// La letra de [request]: la guardada; si no, la incluida en el archivo;
  /// si no, la primera fuente que la tenga, salteando las de
  /// [disabled]. Si ninguna respondió (sin conexión), tira
  /// [LyricsUnavailableException] y no se guarda nada.
  Future<Lyrics> get(
    LyricsRequest request, {
    Set<LyricsSource> disabled = const {},
    List<LyricsSource> order = LyricsSource.online,
  }) async {
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

    // 3) Las fuentes, en el orden que eligió el usuario.
    final lyrics = await _fromSources(request, disabled, order);
    await _save(file, lyrics);
    return lyrics;
  }

  /// "Buscar a mano": con otro título o artista, en todas las
  /// fuentes; si encuentra, reemplaza la guardada de la canción [request.id].
  Future<Lyrics> search(
    LyricsRequest request, {
    Set<LyricsSource> disabled = const {},
    List<LyricsSource> order = LyricsSource.online,
  }) async {
    final lyrics = await _fromSources(request, disabled, order);
    if (!lyrics.isEmpty) await _save(await _fileFor(request.id), lyrics);
    return lyrics;
  }

  /// Las fuentes en el orden elegido (las que no estén en [order] van al final).
  List<LyricsFetcher> _ordered(List<LyricsSource> order) {
    int rank(LyricsFetcher f) {
      final i = order.indexOf(f.source);
      return i < 0 ? order.length : i;
    }

    return [..._fetchers]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  Future<Lyrics> _fromSources(LyricsRequest request, Set<LyricsSource> disabled, List<LyricsSource> order) async {
    var answered = 0;
    final failures = <String>[];
    for (final fetcher in _ordered(order)) {
      if (disabled.contains(fetcher.source)) continue;
      try {
        final lyrics = await fetcher.fetch(request);
        answered++;
        if (lyrics != null && !lyrics.isEmpty) {
          debugPrint('=== LETRAS: encontrada en ${fetcher.source.label} ===');
          return lyrics;
        }
      } on LyricsUnavailableException catch (error) {
        failures.add(error.reason);
      } catch (error) {
        debugPrint('=== LETRAS: ${fetcher.source.label} falló: $error ===');
        answered++;
      }
    }
    // Ninguna respondió: probablemente sin conexión. No se guarda "no hay".
    if (answered == 0 && failures.isNotEmpty) {
      throw LyricsUnavailableException(failures.length == 1 ? failures.first : tx.sinConexion2);
    }
    return Lyrics.none;
  }

  /// Pregunta a TODAS las fuentes a la vez (⋯ → Fuente) y avisa cada respuesta apenas llega:
  /// cuáles tienen esta letra y si está sincronizada. Las apagadas se informan sin preguntarles.
  Stream<LyricsProbe> probe(LyricsRequest request, {Set<LyricsSource> disabled = const {}}) {
    final controller = StreamController<LyricsProbe>();
    var pending = 0;
    for (final fetcher in _fetchers) {
      if (disabled.contains(fetcher.source)) {
        controller.add(LyricsProbe(fetcher.source, LyricsProbeState.off));
        continue;
      }
      pending++;
      () async {
        LyricsProbe result;
        try {
          final lyrics = await fetcher.fetch(request);
          result = lyrics == null || lyrics.isEmpty
              ? LyricsProbe(fetcher.source, LyricsProbeState.none)
              : LyricsProbe(fetcher.source, lyrics.isSynced ? LyricsProbeState.synced : LyricsProbeState.plain, lyrics);
        } catch (error) {
          debugPrint('=== LETRAS: ${fetcher.source.label} no respondió al comparar (${error.runtimeType}) ===');
          result = LyricsProbe(fetcher.source, LyricsProbeState.failed);
        }
        if (!controller.isClosed) controller.add(result);
        if (--pending == 0) await controller.close();
      }();
    }
    if (pending == 0) controller.close();
    return controller.stream;
  }

  /// El usuario eligió [lyrics] para la canción [id] (⋯ → Fuente): se guarda y se usa siempre.
  Future<void> choose(String id, Lyrics lyrics) async {
    debugPrint('=== LETRAS: elegida a mano ${lyrics.source?.label} ===');
    await _save(await _fileFor(id), lyrics);
  }

  /// Importar un `.lrc` (o texto) para la canción [id].
  Future<Lyrics> importText(String id, String text) async {
    final lyrics = lyricsFromText(text, LyricsSource.imported);
    if (lyrics == null) throw FormatException(tx.elArchivoNoTieneUnaLetra);
    await _save(await _fileFor(id), lyrics);
    return lyrics;
  }

  /// Desfase guardado de la canción [id] (positivo = la letra va antes).
  Future<Duration> offset(String id) async {
    final cached = await (await _fileFor(id)).read();
    final ms = cached is Map ? cached['offsetMs'] : null;
    return Duration(milliseconds: ms is int ? ms : 0);
  }

  Future<void> setOffset(String id, Duration offset) async {
    final file = await _fileFor(id);
    final cached = await file.read();
    if (cached is! Map<String, dynamic>) return;
    await file.write({...cached, 'offsetMs': offset.inMilliseconds});
  }

  /// Al guardar una letra nueva el desfase vuelve a 0.
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
