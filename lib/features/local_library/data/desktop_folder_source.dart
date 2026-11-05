import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';
import '../../../models/track.dart';
import '../domain/local_library_source.dart';
import 'local_scan_store.dart';
import 'local_scanner.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Windows / Linux / macOS: música de las carpetas que elige el usuario.
/// Kiji no recorre el disco por su cuenta (Cero Sorpresas): solo lee las
/// carpetas elegidas, y quitar una carpeta no borra ningún archivo.
class DesktopFolderSource implements LocalLibrarySource {
  DesktopFolderSource({Future<Directory> Function()? baseDirectory, Future<String?> Function()? pickFolder})
    : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
      _pickFolder = pickFolder ?? (() => FilePicker.getDirectoryPath(dialogTitle: tx.eligeUnaCarpetaConMusica)),
      _store = LocalScanStore(baseDirectory: baseDirectory);

  /// Extensiones de audio que se leen.
  static const audioExtensions = localAudioExtensions;

  final LocalScanStore _store;

  /// El último escaneo (tiempo y cuántos se leyeron).
  ScanStats? get lastStats => _store.lastStats;

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
  Future<List<Track>> loadTracks({bool force = false}) async {
    final tracks = await _store.scan(roots: await folders(), force: force);
    return [...tracks]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
}
