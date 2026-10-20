// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../viewmodels/BackupRestoreViewModel.kt y
// ui/screens/settings/BackupAndRestore.kt (formato .backup: zip con song.db y
// settings.preferences_pb), y core/.../db/entities/ (tablas song, artist, song_artist_map,
// playlist, playlist_song_map, event). Solo se lee song.db, en modo lectura.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/imported.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Elige el lector según la extensión y el contenido. Recibe los bytes porque en Android
/// `file_picker` a veces no da una ruta real.
Future<ImportBundle> parseImportBytes(
  Uint8List bytes,
  String name, {
  required Directory tempDir,
  String? baseDir,
}) async {
  final ext = p.extension(name).toLowerCase();
  final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B; // "PK"
  if (isZip || ext == '.backup' || ext == '.zip') {
    return parseEchoBackup(bytes, tempDir: tempDir);
  }
  final text = _decodeText(bytes);
  final base = p.basenameWithoutExtension(name);
  if (ext == '.m3u' || ext == '.m3u8' || text.trimLeft().startsWith('#EXTM3U')) {
    return parseM3u(text, name: base, baseDir: baseDir);
  }
  if (ext == '.csv') return parseCsvPlaylist(text, name: base);
  throw ImportFormatException(tx.noReconozcoElFormatoDeKiji(name));
}

String _decodeText(Uint8List bytes) {
  // Sin BOM de UTF-8 si lo tiene.
  final start = bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF ? 3 : 0;
  return _utf8(bytes.sublist(start));
}

String _utf8(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return String.fromCharCodes(bytes); // latin-1 de respaldo
  }
}

// ---------------------------------------------------------------------------
// .backup de Echo Music / Metrolist / InnerTune / OuterTune
// ---------------------------------------------------------------------------

/// Lee un `.backup` (zip). De adentro usa **solo `song.db`**, en modo
/// lectura: playlists, me gusta e historial. Los ajustes
/// (`settings.preferences_pb`) y cualquier cuenta o cookie se ignoran.
Future<ImportBundle> parseEchoBackup(Uint8List bytes, {required Directory tempDir}) async {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (error) {
    debugPrint('=== IMPORTAR: zip dañado: $error ===');
    throw ImportFormatException(tx.elArchivoDeCopiaDeSeguridad);
  }
  final entry = archive.files.where((f) => f.isFile && p.basename(f.name) == 'song.db').firstOrNull;
  if (entry == null) {
    throw ImportFormatException(tx.estaCopiaDeSeguridadNoTiene);
  }

  // sqlite necesita un archivo: se copia a una carpeta temporal propia y se
  // borra al terminar. Se abre en modo solo lectura.
  final work = await tempDir.createTemp('kiji_import_');
  final dbFile = File(p.join(work.path, 'song.db'));
  try {
    await dbFile.writeAsBytes(entry.content as List<int>, flush: true);
    final db = sqlite3.open(dbFile.path, mode: OpenMode.readOnly);
    try {
      return readEchoDatabase(db);
    } finally {
      db.close();
    }
  } on ImportFormatException {
    rethrow;
  } catch (error) {
    debugPrint('=== IMPORTAR: no se pudo leer song.db: $error ===');
    throw ImportFormatException(tx.noSePudoLeerLaBase);
  } finally {
    try {
      await work.delete(recursive: true);
    } catch (error) {
      debugPrint('=== IMPORTAR: no se pudo borrar la carpeta temporal: $error ===');
    }
  }
}

/// Lee las tablas de Echo/Metrolist de una base ya abierta.
ImportBundle readEchoDatabase(Database db) {
  final tables = {for (final r in db.select("SELECT name FROM sqlite_master WHERE type='table'")) r['name']};
  if (!tables.contains('song')) {
    throw ImportFormatException(tx.laBaseNoTieneElFormato);
  }
  final hasArtists = tables.contains('song_artist_map') && tables.contains('artist');
  final songColumns = {for (final r in db.select('PRAGMA table_info(song)')) r['name'] as String};

  // Artistas de cada canción, en orden.
  final artistsBySong = <String, List<String>>{};
  if (hasArtists) {
    for (final r in db.select(
      'SELECT m.songId AS songId, a.name AS name FROM song_artist_map m '
      'JOIN artist a ON a.id = m.artistId ORDER BY m.songId, m.position',
    )) {
      artistsBySong.putIfAbsent(r['songId'] as String, () => []).add(r['name'] as String);
    }
  }

  final songs = <String, ImportedSong>{};
  final likedIds = <String>[];
  final isLocalCol = songColumns.contains('isLocal');
  for (final r in db.select('SELECT * FROM song')) {
    final id = r['id'] as String;
    final isLocal = isLocalCol && (r['isLocal'] as int? ?? 0) == 1;
    final duration = r['duration'] as int?;
    final artists = artistsBySong[id];
    songs[id] = ImportedSong(
      // Las canciones de YouTube usan el videoId como id; las locales no.
      videoId: isLocal ? null : id,
      title: r['title'] as String?,
      artist: artists == null || artists.isEmpty ? null : artists.join(', '),
      album: songColumns.contains('albumName') ? r['albumName'] as String? : null,
      durationMs: duration == null || duration <= 0 ? null : duration * 1000,
      thumbnailUrl: songColumns.contains('thumbnailUrl') ? r['thumbnailUrl'] as String? : null,
    );
    if ((r['liked'] as int? ?? 0) == 1) likedIds.add(id);
  }

  final playlists = <ImportedPlaylist>[];
  if (tables.contains('playlist') && tables.contains('playlist_song_map')) {
    final playlistColumns = {for (final r in db.select('PRAGMA table_info(playlist)')) r['name'] as String};
    final extra = [
      if (playlistColumns.contains('thumbnailUrl')) 'thumbnailUrl',
      if (playlistColumns.contains('isPinned')) 'isPinned',
    ];
    for (final pl in db.select('SELECT ${['id', 'name', ...extra].join(', ')} FROM playlist ORDER BY createdAt')) {
      final rows = db.select('SELECT songId FROM playlist_song_map WHERE playlistId = ? ORDER BY position', [pl['id']]);
      final list = [for (final r in rows) ?songs[r['songId']]];
      if (list.isNotEmpty) {
        playlists.add(
          ImportedPlaylist(
            pl['name'] as String,
            list,
            thumbnailUrl: extra.contains('thumbnailUrl') ? pl['thumbnailUrl'] as String? : null,
            pinned: extra.contains('isPinned') && (pl['isPinned'] as int? ?? 0) == 1,
          ),
        );
      }
    }
  }

  final history = <ImportedPlay>[];
  if (tables.contains('event')) {
    for (final r in db.select('SELECT songId, timestamp FROM event ORDER BY timestamp')) {
      final song = songs[r['songId']];
      final ms = r['timestamp'] as int?;
      if (song != null && ms != null) {
        history.add(ImportedPlay(song, DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal()));
      }
    }
  }

  return ImportBundle(
    source: 'Echo / Metrolist (.backup)', // l10n-ignore
    playlists: playlists,
    liked: [for (final id in likedIds) songs[id]!],
    history: history,
  );
}

// ---------------------------------------------------------------------------
// .m3u / .m3u8
// ---------------------------------------------------------------------------

final _ytUrl = RegExp(
  r'(?:youtube\.com/watch\?(?:.*&)?v=|youtu\.be/|music\.youtube\.com/watch\?(?:.*&)?v=)([A-Za-z0-9_-]{11})',
);

/// Lista .m3u/.m3u8: rutas de archivos (relativas a la carpeta de la lista)
/// y enlaces de YouTube. Usa `#EXTINF:segundos,Artista - Título` si está.
ImportBundle parseM3u(String text, {required String name, String? baseDir}) {
  final songs = <ImportedSong>[];
  int? pendingSeconds;
  String? pendingInfo;
  String? pendingImage;
  var playlistName = name;
  // Imagen indicada en la lista (#EXTIMG o tvg-logo), relativa a la lista.
  String resolve(String path) {
    if (path.startsWith('http')) return path;
    final local = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
    return p.isAbsolute(local) || baseDir == null ? local : p.normalize(p.join(baseDir, local));
  }

  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#PLAYLIST:')) {
      playlistName = line.substring('#PLAYLIST:'.length).trim();
      continue;
    }
    if (line.startsWith('#EXTIMG:')) {
      pendingImage = resolve(line.substring('#EXTIMG:'.length).trim());
      continue;
    }
    if (line.startsWith('#EXTINF:')) {
      final body = line.substring('#EXTINF:'.length);
      final logo = RegExp(r'tvg-logo="([^"]+)"').firstMatch(body)?.group(1);
      if (logo != null) pendingImage = resolve(logo);
      final comma = body.indexOf(',');
      pendingSeconds = int.tryParse((comma == -1 ? body : body.substring(0, comma)).trim().split(' ').first);
      pendingInfo = comma == -1 ? null : body.substring(comma + 1).trim();
      continue;
    }
    if (line.startsWith('#')) continue;

    String? artist;
    String? title = pendingInfo;
    final dash = pendingInfo?.indexOf(' - ') ?? -1;
    if (pendingInfo != null && dash > 0) {
      artist = pendingInfo.substring(0, dash).trim();
      title = pendingInfo.substring(dash + 3).trim();
    }
    final duration = pendingSeconds != null && pendingSeconds > 0 ? pendingSeconds * 1000 : null;
    final yt = _ytUrl.firstMatch(line);
    if (yt != null) {
      songs.add(
        ImportedSong(videoId: yt[1], title: title, artist: artist, durationMs: duration, thumbnailUrl: pendingImage),
      );
    } else {
      final path = line.startsWith('file://') ? Uri.parse(line).toFilePath() : line;
      final absolute = p.isAbsolute(path) || baseDir == null ? path : p.normalize(p.join(baseDir, path));
      songs.add(
        ImportedSong(
          localPath: absolute,
          title: title ?? p.basenameWithoutExtension(absolute),
          artist: artist,
          durationMs: duration,
          thumbnailUrl: pendingImage,
        ),
      );
    }
    pendingSeconds = null;
    pendingInfo = null;
    pendingImage = null;
  }
  if (songs.isEmpty) throw ImportFormatException(tx.laListaNoTieneCanciones(name));
  return ImportBundle(source: '$name (.m3u)', playlists: [ImportedPlaylist(playlistName, songs)]);
}

// ---------------------------------------------------------------------------
// .csv (Exportify / Google Takeout de YouTube Music)
// ---------------------------------------------------------------------------

/// Separa un CSV respetando comillas ("a, b" es un solo campo; "" es una
/// comilla). Acepta coma o punto y coma.
List<List<String>> parseCsv(String text) {
  final firstLine = text.split('\n').first;
  final separator = firstLine.split(';').length > firstLine.split(',').length ? ';' : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == separator) {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  row.add(field.toString());
  if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
  return rows;
}

int? _column(List<String> header, List<String> names) {
  final normalized = [for (final h in header) h.trim().toLowerCase()];
  for (final name in names) {
    final i = normalized.indexOf(name);
    if (i != -1) return i;
  }
  for (final name in names) {
    final i = normalized.indexWhere((h) => h.contains(name));
    if (i != -1) return i;
  }
  return null;
}

/// CSV de una playlist. Detecta las columnas por el encabezado:
/// - Exportify (Spotify): "Track Name", "Artist Name(s)", "Album Name", "Duration (ms)".
/// - Google Takeout de YouTube Music: "Video ID" (a veces sin título).
/// - Y variantes: "Title"/"Título", "Artist"/"Artista", "Duration".
ImportBundle parseCsvPlaylist(String text, {required String name}) {
  final rows = parseCsv(text);
  if (rows.length < 2) throw ImportFormatException(tx.noTieneCanciones(name));
  final header = rows.first;
  final videoCol = _column(header, ['video id', 'videoid', 'video_id']); // l10n-ignore
  final titleCol = _column(header, ['track name', 'title', 'título', 'titulo', 'song', 'name']); // l10n-ignore
  final artistCol = _column(header, ['artist name(s)', 'artist names', 'artist', 'artista']); // l10n-ignore
  final albumCol = _column(header, ['album name', 'album', 'álbum']); // l10n-ignore
  final durationCol = _column(header, ['duration (ms)', 'duration_ms', 'duration', 'duración']); // l10n-ignore
  final pathCol = _column(header, ['path', 'ruta', 'file path']); // l10n-ignore
  if (videoCol == null && titleCol == null) {
    throw ImportFormatException(tx.noEncontreColumnasDeCancionesEn(name));
  }

  String? cell(List<String> row, int? col) {
    if (col == null || col >= row.length) return null;
    final value = row[col].trim();
    return value.isEmpty ? null : value;
  }

  final songs = <ImportedSong>[];
  for (final row in rows.skip(1)) {
    final rawDuration = cell(row, durationCol);
    int? durationMs;
    if (rawDuration != null) {
      final n = int.tryParse(rawDuration);
      final isMs = header[durationCol!].toLowerCase().contains('ms');
      durationMs = n == null ? null : (isMs ? n : n * 1000);
    }
    final song = ImportedSong(
      videoId: cell(row, videoCol),
      localPath: cell(row, pathCol),
      title: cell(row, titleCol),
      // Exportify separa varios artistas con coma: se queda el primero.
      artist: cell(row, artistCol)?.split(RegExp(r'[,;]')).first.trim(),
      album: cell(row, albumCol),
      durationMs: durationMs,
    );
    if (song.isUsable) songs.add(song);
  }
  if (songs.isEmpty) throw ImportFormatException(tx.noTieneCanciones(name));
  final source = videoCol != null ? tx.googleTakeoutCsv : 'Exportify / Spotify (.csv)'; // l10n-ignore
  return ImportBundle(source: source, playlists: [ImportedPlaylist(name, songs)]);
}
