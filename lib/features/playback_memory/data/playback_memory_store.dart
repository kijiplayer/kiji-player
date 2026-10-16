// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: core/.../models/PersistQueue.kt, PersistPlayerState.kt y
// MusicService.kt (qué se guarda, cuándo, y borrar el guardado si está dañado).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';
import '../domain/playback_snapshot.dart';

/// Guarda y recupera la [PlaybackSnapshot] en
/// `<appSupportDir>/playback_state.json`.
class PlaybackMemoryStore {
  PlaybackMemoryStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'playback_state.json';

  final Future<Directory> Function() _directory;
  JsonFile? _file;

  Future<JsonFile> _jsonFile() async =>
      _file ??= JsonFile(p.join((await _directory()).path, _fileName), logTag: 'MEMORIA');

  /// Devuelve null si no hay nada guardado. Si el archivo está dañado, lo
  /// borra y también devuelve null (la app arranca vacía).
  Future<PlaybackSnapshot?> load() async {
    final file = await _jsonFile();
    final json = await file.read();
    if (json == null) return null;
    try {
      return PlaybackSnapshot.fromJson(json as Map<String, dynamic>);
    } catch (error) {
      await file.deleteCorrupt(error);
      return null;
    }
  }

  Future<void> save(PlaybackSnapshot snapshot) async {
    await (await _jsonFile()).write(snapshot.toJson());
  }

  /// Olvida la cola guardada (el usuario la vació).
  Future<void> clear() async {
    await (await _jsonFile()).delete();
  }
}
