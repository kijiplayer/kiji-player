import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../backup/data/backup_service.dart' show coversFolder;
import 'package:kiji_player/l10n/l10n.dart';


/// Fotos personalizadas (Tarea Z3): se guardan en `<datos>/covers/`, la misma
/// carpeta que entra en la copia de seguridad (Tarea U). Nunca se toca el
/// archivo de música original.
class CoverStore {
  CoverStore({Future<Directory> Function()? directory}) : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  /// Lado máximo de las fotos guardadas (suficiente para el reproductor).
  static const maxSide = 800;

  Future<Directory> folder() async => Directory(p.join((await _directory()).path, coversFolder));

  /// Guarda [bytes] (cualquier formato de imagen) como JPEG achicado y
  /// devuelve el nombre del archivo. El nombre cambia en cada foto nueva,
  /// así la caché de imágenes no muestra la vieja.
  Future<String> save(String prefix, Uint8List bytes) async {
    final jpg = await compute(_toJpeg, bytes);
    final safe = prefix.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final name = '$safe-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dir = await folder();
    await dir.create(recursive: true);
    await File(p.join(dir.path, name)).writeAsBytes(jpg, flush: true);
    debugPrint('=== PERSONALIZAR: foto guardada $name (${jpg.length ~/ 1024} KB) ===');
    return name;
  }

  Future<File> file(String name) async => File(p.join((await folder()).path, p.basename(name)));

  Future<void> delete(String? name) async {
    if (name == null) return;
    try {
      final target = await file(name);
      if (await target.exists()) await target.delete();
    } catch (error) {
      debugPrint('=== PERSONALIZAR: no se pudo borrar la foto $name: $error ===');
    }
  }
}

Uint8List _toJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw FormatException(tx.noEsUnaImagenQueKijiPuedaLeer);
  final big = decoded.width > CoverStore.maxSide || decoded.height > CoverStore.maxSide;
  final resized = !big
      ? decoded
      : decoded.width >= decoded.height
      ? img.copyResize(decoded, width: CoverStore.maxSide)
      : img.copyResize(decoded, height: CoverStore.maxSide);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
}
