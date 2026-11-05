import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../customize/data/artwork_cache.dart' show ArtworkCache, artworkCacheName;
import '../domain/local_song_text.dart';

/// Formatos que lee Kiji.
const localAudioExtensions = {'.mp3', '.flac', '.m4a', '.aac', '.ogg', '.opus', '.wav', '.webm', '.wma'};

/// Imágenes de carpeta que valen como portada (sin la extensión), en orden de preferencia.
const folderCoverNames = ['cover', 'folder', 'front', 'album', 'albumart', 'albumartlarge', 'albumartsmall'];
const folderCoverExtensions = ['.jpg', '.jpeg', '.png', '.webp'];

/// Un archivo para escanear (sin tipos de Flutter: viaja entre isolates). En Android trae lo que
/// ya sabe el MediaStore, por si el archivo no se puede leer.
class ScanEntry {
  const ScanEntry({
    required this.id,
    required this.path,
    required this.sizeBytes,
    required this.modifiedMs,
    this.addedAtMs,
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.track,
    this.durationMs,
  });

  final String id;
  final String path;
  final int sizeBytes;
  final int modifiedMs;
  final int? addedAtMs;
  final String? title;
  final String? artist;
  final String? album;
  final String? genre;

  /// Número de pista del MediaStore (1003 = disco 1, pista 3).
  final int? track;
  final int? durationMs;
}

/// Qué escanear: los archivos, lo que ya se sabía de ellos ([cache], por ruta) y dónde guardar
/// las portadas incluidas. Con [force] se vuelve a leer todo.
class ScanJob {
  const ScanJob({required this.entries, required this.cache, this.artworkDir, this.force = false});

  final List<ScanEntry> entries;
  final Map<String, dynamic> cache;
  final String? artworkDir;
  final bool force;
}

/// Lo escaneado: las canciones (JSON de `Track`, sin el color), la caché nueva y cuántos se
/// leyeron de verdad (los demás salieron de la caché).
class ScanOutcome {
  const ScanOutcome({required this.songs, required this.cache, required this.read, required this.reused});

  final List<Map<String, dynamic>> songs;
  final Map<String, dynamic> cache;
  final int read;
  final int reused;
}

/// Recorre las carpetas elegidas (PC) y arma la lista de archivos de audio, con su tamaño y fecha.
List<ScanEntry> listAudioFiles(List<String> roots) {
  final entries = <ScanEntry>[];
  final seen = <String>{};
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    try {
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (!localAudioExtensions.contains(p.extension(entity.path).toLowerCase())) continue;
        final path = p.normalize(entity.path);
        if (!seen.add(path)) continue;
        try {
          final stat = entity.statSync();
          final modified = stat.modified.millisecondsSinceEpoch;
          entries.add(
            ScanEntry(
              id: desktopTrackId(path),
              path: path,
              sizeBytes: stat.size,
              modifiedMs: modified,
              // En la PC, "agregada" es la fecha del archivo.
              addedAtMs: modified,
            ),
          );
        } catch (error) {
          debugPrint('=== BIBLIOTECA: no se pudo leer un archivo (${p.extension(entity.path)}): ${error.runtimeType} ===');
        }
      }
    } catch (error) {
      debugPrint('=== BIBLIOTECA: no se pudo recorrer una carpeta: ${error.runtimeType} ===');
    }
  }
  return entries;
}

/// El id de una canción de la PC: depende de la ruta (si el archivo se mueve, es otra).
String desktopTrackId(String path) => 'local-file-${path.hashCode.toUnsigned(32).toRadixString(16)}';

/// Escanea [job]: lo que no cambió (mismo tamaño y fecha) sale de la caché; lo nuevo o cambiado
/// se lee del archivo (etiquetas y portada incluida, que se guarda en [ScanJob.artworkDir]).
ScanOutcome scanLibrary(ScanJob job) {
  final songs = <Map<String, dynamic>>[];
  final cache = <String, dynamic>{};
  final folderCovers = <String, String?>{};
  var read = 0, reused = 0;
  for (final entry in job.entries) {
    final known = job.cache[entry.path];
    if (!job.force &&
        known is Map<String, dynamic> &&
        known['m'] == entry.modifiedMs &&
        known['s'] == entry.sizeBytes &&
        known['song'] is Map<String, dynamic>) {
      final song = Map<String, dynamic>.from(known['song'] as Map<String, dynamic>)
        ..['id'] = entry.id
        ..['addedAtMs'] = entry.addedAtMs ?? known['song']['addedAtMs'];
      songs.add(song);
      cache[entry.path] = known;
      reused++;
      continue;
    }
    final dir = p.dirname(entry.path);
    final song = readSong(
      entry,
      artworkDir: job.artworkDir,
      folderCover: folderCovers.putIfAbsent(dir, () => findFolderCover(dir)),
    );
    songs.add(song);
    cache[entry.path] = {'m': entry.modifiedMs, 's': entry.sizeBytes, 'song': song};
    read++;
  }
  return ScanOutcome(songs: songs, cache: cache, read: read, reused: reused);
}

/// La imagen de la carpeta que hace de portada (cover.jpg, folder.jpg, front.png…), o null.
String? findFolderCover(String dir) {
  try {
    final images = <String, String>{};
    for (final entity in Directory(dir).listSync(followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!folderCoverExtensions.contains(ext)) continue;
      images.putIfAbsent(p.basenameWithoutExtension(entity.path).toLowerCase(), () => entity.path);
    }
    for (final name in folderCoverNames) {
      if (images[name] case final path?) return path;
    }
  } catch (error) {
    // En Android, sin permiso de imágenes no se ve la carpeta: queda la portada generada.
    debugPrint('=== BIBLIOTECA: sin imagen de carpeta: ${error.runtimeType} ===');
  }
  return null;
}

/// Lee un archivo: etiquetas (o lo del MediaStore, o el nombre del archivo limpio) y la portada
/// incluida, que se guarda en [artworkDir] con la clave del archivo. Nunca falla: un archivo que
/// no se puede leer queda con lo que se sepa.
Map<String, dynamic> readSong(ScanEntry entry, {String? artworkDir, String? folderCover}) {
  AudioMetadata? tags;
  String? artist, albumArtist;
  try {
    tags = readMetadata(File(entry.path), getImage: artworkDir != null);
    artist = tags.artist;
    albumArtist = tags.albumArtist;
    // En los MP3 la librería usa el artista del álbum (TPE2) como artista: se leen por separado
    // (TPE1 = el de la canción, TPE2 = el del álbum).
    if (p.extension(entry.path).toLowerCase() == '.mp3') {
      final raw = readAllMetadata(File(entry.path), getImage: false);
      if (raw is Mp3Metadata) {
        artist = raw.leadPerformer ?? raw.bandOrOrchestra ?? artist;
        albumArtist = raw.bandOrOrchestra;
      }
    }
  } catch (error) {
    debugPrint('=== BIBLIOTECA: sin etiquetas (${p.extension(entry.path)}): ${error.runtimeType} ===');
  }
  String? clean(String? s) {
    final v = s?.trim();
    return v == null || v.isEmpty || unknownMarkers.contains(v.toLowerCase()) ? null : v;
  }

  final fromName = titleFromFileName(p.basename(entry.path));
  final mediaTrack = entry.track;
  final hasArt = artworkDir != null && _saveArtwork(tags, artworkDir, entry.path);
  return {
    'id': entry.id,
    'title': clean(tags?.title) ?? clean(entry.title) ?? fromName.title,
    // Vacío = "Artista desconocido" (se pone en el idioma de la app al mostrarlo).
    'artist': clean(artist) ?? clean(entry.artist) ?? fromName.artist ?? '',
    'audioUrl': entry.path,
    'source': 'local',
    'album': ?clean(tags?.album) ?? clean(entry.album),
    'albumArtist': ?clean(albumArtist),
    // Sin año, la librería da el año 0.
    'year': ?_positive(tags?.year?.year),
    'trackNumber': ?(tags?.trackNumber ?? (mediaTrack == null || mediaTrack <= 0 ? null : mediaTrack % 1000)),
    'discNumber': ?(tags?.discNumber ?? (mediaTrack != null && mediaTrack >= 1000 ? mediaTrack ~/ 1000 : null)),
    'genre': ?clean(tags?.genres.firstOrNull) ?? clean(entry.genre),
    'durationMs': tags?.duration?.inMilliseconds ?? entry.durationMs ?? 0,
    'sizeBytes': entry.sizeBytes,
    'addedAtMs': ?entry.addedAtMs,
    // Sin portada incluida, la de la carpeta (como ruta de archivo).
    if (!hasArt && folderCover != null) 'thumbnailUrl': folderCover,
  };
}

/// Guarda la portada incluida (la de frente, si hay varias). Si el archivo ya no trae, borra la
/// vieja. true si quedó una.
bool _saveArtwork(AudioMetadata? tags, String artworkDir, String path) {
  final target = File(p.join(artworkDir, artworkCacheName(ArtworkCache.fileKey(path))));
  try {
    final pictures = tags?.pictures ?? const [];
    if (pictures.isEmpty) {
      if (target.existsSync()) target.deleteSync();
      return false;
    }
    final front = pictures.firstWhere((pic) => pic.pictureType == PictureType.coverFront, orElse: () => pictures.first);
    if (front.bytes.isEmpty) return false;
    target.parent.createSync(recursive: true);
    final temp = File('${target.path}.part')..writeAsBytesSync(front.bytes, flush: true);
    temp.renameSync(target.path);
    return true;
  } catch (error) {
    debugPrint('=== BIBLIOTECA: no se pudo guardar una portada: ${error.runtimeType} ===');
    return false;
  }
}

int? _positive(int? n) => n != null && n > 0 ? n : null;
