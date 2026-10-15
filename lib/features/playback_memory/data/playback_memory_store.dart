// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: core/.../models/PersistQueue.kt, PersistPlayerState.kt y
// MusicService.kt (qué se guarda, cuándo, y borrar el guardado si está dañado).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/playback_snapshot.dart';

/// Guarda y recupera la [PlaybackSnapshot] en
/// `<appSupportDir>/playback_state.json`.
class PlaybackMemoryStore {
  PlaybackMemoryStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'playback_state.json';

  final Future<Directory> Function() _directory;

  /// Cadena de escrituras: cada `save` espera a la anterior, para que dos
  /// guardados seguidos no pisen el mismo archivo temporal.
  Future<void> _pendingWrite = Future.value();

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  /// Devuelve null si no hay nada guardado. Si el archivo está dañado, lo
  /// borra y también devuelve null (la app arranca vacía).
  Future<PlaybackSnapshot?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return PlaybackSnapshot.fromJson(json);
    } catch (error) {
      debugPrint('=== MEMORIA: guardado dañado, se borra: $error ===');
      try {
        await file.delete();
      } catch (deleteError) {
        debugPrint('=== MEMORIA: no se pudo borrar el guardado: $deleteError ===');
      }
      return null;
    }
  }

  /// Escribe en un archivo temporal y lo renombra: si la app se cierra a
  /// mitad de escritura, el guardado anterior queda intacto.
  Future<void> save(PlaybackSnapshot snapshot) {
    return _pendingWrite = _pendingWrite.then((_) async {
      try {
        final file = await _file();
        final temp = File('${file.path}.tmp');
        await temp.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
        await temp.rename(file.path);
      } catch (error) {
        debugPrint('=== MEMORIA: error al guardar: $error ===');
      }
    });
  }
}
