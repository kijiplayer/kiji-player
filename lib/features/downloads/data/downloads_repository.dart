// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../playback/DownloadUtil.kt (descargas guardadas
// dentro de la app, separadas de la caché de reproducción, con fecha de descarga).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';
import '../domain/download_settings.dart';
import '../domain/downloaded_track.dart';

/// Índice de descargas y preferencias, guardados en
/// `<appSupportDir>/downloads/`. Todo en almacenamiento privado de la app:
/// no hacen falta permisos y nada queda suelto en la carpeta Música.
class DownloadsRepository {
  DownloadsRepository({Future<Directory> Function()? baseDirectory})
      : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDirectory;

  Directory? _dir;
  JsonFile? _index;
  JsonFile? _settingsFile;
  Map<String, DownloadedTrack>? _entries;

  /// Carpeta de descargas (se crea si no existe).
  Future<Directory> directory() async {
    if (_dir != null) return _dir!;
    final dir = Directory(p.join((await _baseDirectory()).path, 'downloads'));
    await dir.create(recursive: true);
    _index = JsonFile(p.join(dir.path, 'index.json'), logTag: 'DESCARGAS');
    _settingsFile = JsonFile(p.join(dir.path, 'settings.json'), logTag: 'DESCARGAS');
    return _dir = dir;
  }

  Future<String> pathFor(String fileName) async => p.join((await directory()).path, fileName);

  /// Descargas completas, por `videoId`. Las que figuran en el índice pero
  /// cuyo archivo ya no existe se descartan.
  Future<Map<String, DownloadedTrack>> all() async {
    if (_entries != null) return _entries!;
    await directory();
    final entries = <String, DownloadedTrack>{};
    final json = await _index!.read();
    if (json != null) {
      try {
        for (final item in (json as Map<String, dynamic>)['tracks'] as List<dynamic>) {
          final track = DownloadedTrack.fromJson(item as Map<String, dynamic>);
          if (await File(await pathFor(track.fileName)).exists()) {
            entries[track.videoId] = track;
          }
        }
      } catch (error) {
        await _index!.deleteCorrupt(error);
      }
    }
    return _entries = entries;
  }

  /// Archivo descargado para [videoId], o null si no está descargado.
  Future<File?> fileFor(String videoId) async {
    final track = (await all())[videoId];
    if (track == null) return null;
    final file = File(await pathFor(track.fileName));
    return await file.exists() ? file : null;
  }

  Future<void> add(DownloadedTrack track) async {
    (await all())[track.videoId] = track;
    await _saveIndex();
  }

  /// Borra el archivo y su portada. La canción sigue en colas y playlists:
  /// solo vuelve a sonar desde internet.
  Future<void> remove(String videoId) async {
    final track = (await all()).remove(videoId);
    if (track == null) return;
    for (final name in [track.fileName, ?track.thumbnailFileName]) {
      final file = File(await pathFor(name));
      if (await file.exists()) await file.delete();
    }
    await _saveIndex();
  }

  Future<int> totalBytes() async =>
      (await all()).values.fold<int>(0, (sum, track) => sum + track.sizeBytes);

  Future<void> _saveIndex() async {
    final entries = await all();
    await _index!.write({
      'version': 1,
      'tracks': [for (final track in entries.values) track.toJson()],
    });
  }

  Future<DownloadSettings> loadSettings() async {
    await directory();
    final json = await _settingsFile!.read();
    if (json == null) return const DownloadSettings();
    try {
      return DownloadSettings.fromJson(json as Map<String, dynamic>);
    } catch (error) {
      await _settingsFile!.deleteCorrupt(error);
      return const DownloadSettings();
    }
  }

  Future<void> saveSettings(DownloadSettings settings) async {
    await directory();
    await _settingsFile!.write(settings.toJson());
  }
}
