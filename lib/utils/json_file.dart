import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Archivo JSON que se escribe de forma atómica: primero en `<ruta>.tmp` y
/// después se renombra. Si la app se cierra a mitad de escritura, el
/// contenido anterior queda intacto.
class JsonFile {
  JsonFile(this.path, {required this.logTag});

  final String path;

  /// Prefijo de los logs, por ejemplo `MEMORIA` o `DESCARGAS`.
  final String logTag;

  /// Cadena de escrituras: cada una espera a la anterior, para que dos
  /// guardados seguidos no pisen el mismo archivo temporal.
  Future<void> _pendingWrite = Future.value();

  /// Devuelve null si no existe. Si existe pero está dañado, lo borra y
  /// devuelve null.
  Future<Object?> read() async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } catch (error) {
      await deleteCorrupt(error);
      return null;
    }
  }

  /// Borra el archivo cuando su contenido no se puede usar.
  Future<void> deleteCorrupt(Object error) async {
    debugPrint('=== $logTag: archivo dañado, se borra ($path): $error ===');
    try {
      await File(path).delete();
    } catch (deleteError) {
      debugPrint('=== $logTag: no se pudo borrar $path: $deleteError ===');
    }
  }

  /// Borra el archivo (si existe), después de las escrituras pendientes.
  Future<void> delete() {
    return _pendingWrite = _pendingWrite.then((_) async {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (error) {
        debugPrint('=== $logTag: no se pudo borrar $path: $error ===');
      }
    });
  }

  /// Renombra [temp] sobre [target]. En Windows el antivirus o el indexador
  /// pueden retener el archivo un instante ("está siendo utilizado por otro
  /// proceso"): se reintenta y, como último recurso, se copia encima.
  static Future<void> _replace(File temp, String target) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await temp.rename(target);
        return;
      } on FileSystemException {
        await Future<void>.delayed(Duration(milliseconds: 40 * (attempt + 1)));
      }
    }
    await temp.copy(target);
    await temp.delete();
  }

  Future<void> write(Object json) {
    return _pendingWrite = _pendingWrite.then((_) async {
      try {
        final temp = File('$path.tmp');
        await temp.parent.create(recursive: true);
        await temp.writeAsString(jsonEncode(json), flush: true);
        await _replace(temp, path);
      } catch (error) {
        debugPrint('=== $logTag: error al guardar $path: $error ===');
      }
    });
  }
}
