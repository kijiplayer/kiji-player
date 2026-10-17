import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Carpeta de las copias por defecto: `Documentos/Kiji`, fuera de la app,
/// para que sobreviva si se desinstala Kiji (una ruta por
/// plataforma, siempre con path_provider o el sistema).
Future<Directory> defaultBackupFolder() async {
  if (!kIsWeb && Platform.isAndroid) {
    try {
      final documents = await const MethodChannel('kiji/storage').invokeMethod<String>('documentsDir');
      if (documents != null) return Directory(p.join(documents, 'Kiji'));
    } catch (error) {
      debugPrint('=== COPIA: no se pudo ubicar Documentos: $error ===');
    }
    // Respaldo: la carpeta de la app en el almacenamiento externo (se borra al
    // desinstalar, pero es mejor que nada).
    final external = await getExternalStorageDirectory();
    if (external != null) return Directory(p.join(external.path, 'Kiji'));
  }
  return Directory(p.join((await getApplicationDocumentsDirectory()).path, 'Kiji'));
}

/// null si se puede escribir en [folder]; si no, el motivo en palabras simples.
Future<String?> checkWritable(Directory folder) async {
  try {
    await folder.create(recursive: true);
    final probe = File(p.join(folder.path, '.kiji-prueba'));
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
    return null;
  } catch (error) {
    debugPrint('=== COPIA: no se puede escribir en ${folder.path}: $error ===');
    return 'Kiji no puede guardar en esa carpeta. Elegí otra.';
  }
}
