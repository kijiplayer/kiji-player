import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/backup_manifest.dart';

/// Archivos de Kiji que van en la copia (relativos a la carpeta de datos).
/// La cola que suena, las cachés y el audio descargado no van.
const backedUpFiles = [
  'settings.json',
  'equalizer.json',
  'playlists.json',
  'favorites.json',
  'history.json',
  'imports.json',
  'library_folders.json',
  // Título, artista y foto personalizados de cada canción (Tarea Z3).
  'track_overrides.json',
];

/// La lista de descargas va aparte: al restaurar no se pisa el índice (los
/// archivos de audio no están en la copia); se ofrece volver a bajarlas.
const _downloadsIndex = 'downloads/index.json';
const downloadsListEntry = 'downloads_list.json';

/// Carátulas personalizadas (Tarea Z3): todo lo que haya en esta carpeta.
const coversFolder = 'covers';

/// Una canción de la lista de descargas de la copia.
class BackupDownload {
  const BackupDownload({required this.videoId, required this.title, required this.artist, this.album, this.durationMs = 0});
  final String videoId;
  final String title;
  final String artist;
  final String? album;
  final int durationMs;
}

/// Lo que se ve antes de restaurar.
class BackupPreview {
  const BackupPreview({required this.file, required this.manifest, required this.downloads});
  final File file;
  final BackupManifest manifest;
  final List<BackupDownload> downloads;
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Crea, lista, revisa y restaura copias. Sin estado: recibe las carpetas.
class BackupService {
  const BackupService({required this.dataDirectory, this.platform});

  /// Carpeta de datos de Kiji (`getApplicationSupportDirectory`).
  final Future<Directory> Function() dataDirectory;

  /// Para el manifiesto (en los tests, fijo).
  final String? platform;

  /// Hace una copia en [folder] y borra las que sobran (quedan 7).
  Future<File> create(Directory folder, {String reason = 'manual', DateTime? now}) async {
    final when = now ?? DateTime.now();
    final data = await dataDirectory();
    final archive = Archive();
    final included = <String>[];

    void add(String name, List<int> bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      included.add(name);
    }

    for (final name in backedUpFiles) {
      final file = File(p.join(data.path, name));
      if (await file.exists()) add(name, await file.readAsBytes());
    }
    final downloads = File(p.join(data.path, _downloadsIndex));
    if (await downloads.exists()) add(downloadsListEntry, await downloads.readAsBytes());
    final covers = Directory(p.join(data.path, coversFolder));
    var coverCount = 0;
    if (await covers.exists()) {
      await for (final entity in covers.list()) {
        if (entity is File) {
          add('$coversFolder/${p.basename(entity.path)}', await entity.readAsBytes());
          coverCount++;
        }
      }
    }

    final manifest = BackupManifest(
      createdAt: when,
      platform: platform ?? (kIsWeb ? 'web' : Platform.operatingSystem),
      reason: reason,
      files: List.of(included),
      counts: _count(archive, coverCount),
    );
    final manifestBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest.toJson()));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    await folder.create(recursive: true);
    final name = backupFileName(when, suffix: reason == 'antes-de-restaurar' ? reason : null);
    final target = File(p.join(folder.path, name));
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
    if (await target.exists()) await target.delete();
    await temp.rename(target.path);
    debugPrint('=== COPIA: hecha $name (${included.length} archivos, $reason) ===');
    await prune(folder);
    return target;
  }

  /// Borra las copias de Kiji que sobran. No toca ningún otro archivo.
  Future<void> prune(Directory folder) async {
    final names = [
      await for (final entity in folder.list())
        if (entity is File) p.basename(entity.path),
    ];
    for (final name in backupsToDelete(names)) {
      try {
        await File(p.join(folder.path, name)).delete();
        debugPrint('=== COPIA: borrada la copia vieja $name ===');
      } catch (error) {
        debugPrint('=== COPIA: no se pudo borrar $name: $error ===');
      }
    }
  }

  /// Copias de Kiji en [folder], de la más nueva a la más vieja.
  Future<List<File>> list(Directory folder) async {
    if (!await folder.exists()) return const [];
    final files = [
      await for (final entity in folder.list())
        if (entity is File && backupDateFromName(p.basename(entity.path)) != null) entity,
    ]..sort((a, b) =>
        backupDateFromName(p.basename(b.path))!.compareTo(backupDateFromName(p.basename(a.path))!));
    return files;
  }

  /// Lee una copia sin tocar nada.
  Future<BackupPreview> preview(File file) async {
    final archive = await _read(file);
    final manifestFile = archive.findFile('manifest.json');
    final manifest = manifestFile == null
        ? null
        : BackupManifest.tryParse(_json(manifestFile.content as List<int>));
    if (manifest == null) throw const BackupException('El archivo no es una copia de Kiji (o es de una versión más nueva).');
    final list = archive.findFile(downloadsListEntry);
    return BackupPreview(
      file: file,
      manifest: manifest,
      downloads: list == null ? const [] : _downloads(_json(list.content as List<int>)),
    );
  }

  /// Restaura [file]: antes guarda una copia de lo que hay ahora en
  /// [safetyFolder] (así se puede volver atrás). Reemplaza solo los datos
  /// que van en las copias; la lista de descargas no se pisa.
  Future<BackupPreview> restore(File file, {required Directory safetyFolder}) async {
    final preview = await this.preview(file);
    await create(safetyFolder, reason: 'antes-de-restaurar');
    final archive = await _read(file);
    final data = await dataDirectory();

    for (final name in backedUpFiles) {
      final entry = archive.findFile(name);
      final target = File(p.join(data.path, name));
      if (entry != null) {
        await _writeAtomically(target, entry.content as List<int>);
      } else if (await target.exists()) {
        // En la copia no estaba: ese dato estaba de fábrica.
        await target.delete();
      }
    }
    final covers = Directory(p.join(data.path, coversFolder));
    if (await covers.exists()) await covers.delete(recursive: true);
    for (final entry in archive.files) {
      if (!entry.isFile || !entry.name.startsWith('$coversFolder/')) continue;
      // Solo el nombre del archivo: un zip armado a mano no puede escribir
      // fuera de la carpeta de carátulas.
      final name = p.basename(entry.name);
      if (name.isEmpty || name.startsWith('.')) continue;
      await covers.create(recursive: true);
      await File(p.join(covers.path, name)).writeAsBytes(entry.content as List<int>);
    }
    debugPrint('=== COPIA: restaurada ${p.basename(file.path)} ===');
    return preview;
  }

  Future<Archive> _read(File file) async {
    try {
      return ZipDecoder().decodeBytes(await file.readAsBytes());
    } catch (error) {
      debugPrint('=== COPIA: no se pudo abrir ${file.path}: $error ===');
      throw const BackupException('El archivo está dañado o no es una copia de Kiji.');
    }
  }

  static Object? _json(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (error) {
      debugPrint('=== COPIA: JSON dañado en la copia: $error ===');
      return null;
    }
  }

  static Future<void> _writeAtomically(File target, List<int> bytes) async {
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.restaurando');
    await temp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await temp.rename(target.path);
  }

  static List<BackupDownload> _downloads(Object? json) {
    final tracks = json is Map ? json['tracks'] : null;
    if (tracks is! List) return const [];
    return [
      for (final t in tracks)
        if (t is Map && t['videoId'] is String)
          BackupDownload(
            videoId: t['videoId'] as String,
            title: '${t['title'] ?? ''}',
            artist: '${t['artist'] ?? ''}',
            album: t['album'] as String?,
            durationMs: t['durationMs'] is int ? t['durationMs'] as int : 0,
          ),
    ];
  }

  static BackupCounts _count(Archive archive, int covers) {
    int lengthOf(String name, {String? key}) {
      final file = archive.findFile(name);
      if (file == null) return 0;
      final json = _json(file.content as List<int>);
      final list = key == null ? json : (json is Map ? json[key] : null);
      return list is List ? list.length : 0;
    }

    return BackupCounts(
      playlists: lengthOf('playlists.json', key: 'playlists'),
      likes: lengthOf('favorites.json'),
      history: lengthOf('history.json'),
      downloads: lengthOf(downloadsListEntry, key: 'tracks'),
      covers: covers,
    );
  }
}
