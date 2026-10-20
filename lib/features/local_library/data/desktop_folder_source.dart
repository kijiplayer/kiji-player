import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../utils/startup_log.dart';

import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../yt_music/domain/subtitle_parser.dart';
import '../../../utils/json_file.dart';
import '../domain/local_library_source.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Windows / Linux / macOS: música de las carpetas que elige el usuario.
/// Kiji no recorre el disco por su cuenta (Cero Sorpresas): solo lee las
/// carpetas elegidas, y quitar una carpeta no borra ningún archivo.
class DesktopFolderSource implements LocalLibrarySource {
  DesktopFolderSource({Future<Directory> Function()? baseDirectory, Future<String?> Function()? pickFolder})
    : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
      _pickFolder = pickFolder ?? (() => FilePicker.getDirectoryPath(dialogTitle: tx.eligeUnaCarpetaConMusica));

  /// Extensiones de audio que se leen.
  static const audioExtensions = {'.mp3', '.m4a', '.aac', '.flac', '.ogg', '.opus', '.wav', '.webm', '.wma'};

  final Future<Directory> Function() _baseDirectory;
  final Future<String?> Function() _pickFolder;
  JsonFile? _file;

  Future<JsonFile> _jsonFile() async =>
      _file ??= JsonFile(p.join((await _baseDirectory()).path, 'library_folders.json'), logTag: 'BIBLIOTECA');

  @override
  bool get usesFolders => true;

  @override
  Future<List<String>> folders() async {
    final json = await (await _jsonFile()).read();
    if (json is! List) return const [];
    return [
      for (final folder in json)
        if (folder is String) folder,
    ];
  }

  Future<void> _saveFolders(List<String> folders) async => (await _jsonFile()).write(folders);

  @override
  Future<bool> hasAccess() async => (await folders()).isNotEmpty;

  @override
  Future<bool> requestAccess() async {
    final picked = await _pickFolder();
    if (picked == null) return hasAccess();
    final current = await folders();
    if (!current.contains(picked)) await _saveFolders([...current, picked]);
    return true;
  }

  @override
  Future<void> removeFolder(String folder) async {
    final current = await folders();
    await _saveFolders([
      for (final f in current)
        if (f != folder) f,
    ]);
  }

  @override
  Future<List<Track>> loadTracks() async {
    final roots = await folders();
    // Recorrer carpetas y leer etiquetas puede tardar: en otro isolate para
    // que la interfaz no se trabe.
    // Con límite: archivos "solo en la nube" (OneDrive) pueden quedarse esperando al leerlos.
    final entries =
        await StartupLog.guard(
          'leer la carpeta de música', // l10n-ignore
          () => Isolate.run(() => scanFolders(roots)),
          limit: const Duration(seconds: 90),
        ) ??
        const <ScannedSong>[];
    return [for (final entry in entries) entry.toTrack()]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
}

/// Datos de un archivo, sin tipos de Flutter (viajan entre isolates).
class ScannedSong {
  const ScannedSong({
    required this.path,
    required this.title,
    required this.artist,
    this.album,
    this.durationMs = 0,
    this.sizeBytes,
  });

  final String path;
  final String title;
  final String artist;
  final String? album;
  final int durationMs;
  final int? sizeBytes;

  Track toTrack() => Track(
    // El id depende de la ruta: si el archivo se mueve, es otra canción.
    id: 'local-file-${path.hashCode.toUnsigned(32).toRadixString(16)}',
    title: title,
    artist: artist,
    coverColor: _colorFromSeed(title),
    audioUrl: path,
    source: TrackSource.local,
    album: album,
    durationMs: durationMs,
    sizeBytes: sizeBytes,
  );
}

/// Recorre [roots] y lee las etiquetas de cada archivo de audio. Si un
/// archivo no tiene etiquetas o están dañadas, usa el nombre del archivo.
List<ScannedSong> scanFolders(List<String> roots) {
  final songs = <ScannedSong>[];
  final seen = <String>{};
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    final files = dir.listSync(recursive: true, followLinks: false).whereType<File>();
    for (final file in files) {
      final extension = p.extension(file.path).toLowerCase();
      if (!DesktopFolderSource.audioExtensions.contains(extension)) continue;
      if (!seen.add(p.normalize(file.path))) continue;
      songs.add(_readSong(file));
    }
  }
  return songs;
}

ScannedSong _readSong(File file) {
  final fallbackTitle = p.basenameWithoutExtension(file.path);
  try {
    final metadata = readMetadata(file);
    final title = metadata.title?.trim();
    final artist = metadata.artist?.trim();
    return ScannedSong(
      path: file.path,
      title: title == null || title.isEmpty ? fallbackTitle : title,
      artist: artist == null || artist.isEmpty ? unknownArtist : artist,
      album: metadata.album,
      durationMs: metadata.duration?.inMilliseconds ?? 0,
      sizeBytes: file.lengthSync(),
    );
  } catch (error) {
    // Sin etiquetas legibles: la canción se muestra igual, con el nombre del archivo.
    debugPrint('=== BIBLIOTECA: sin etiquetas en ${file.path}: $error ===');
    return ScannedSong(
      path: file.path,
      title: fallbackTitle,
      artist: tx.artistaDesconocido,
      sizeBytes: file.lengthSync(),
    );
  }
}

Color _colorFromSeed(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (acc, unit) => acc + unit);
  final hue = (hash * 37) % 360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();
}
