import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../utils/app_log.dart';
import 'log_scrubber.dart';

/// El registro guardado en el dispositivo: `kiji.log` y, cuando pasa de [maxBytes],
/// se renombra a `kiji.1.log` (se borra el anterior). Así nunca ocupa más de 2 × [maxBytes].
/// Cada línea se guarda ya sin datos personales. Escribe en el momento (síncrono) para que
/// quede escrito aunque Kiji se cierre de golpe justo después.
class LogFile {
  LogFile(this.directory, {this.maxBytes = 512 * 1024});

  final Directory directory;
  final int maxBytes;
  int _size = -1;

  File get current => File(p.join(directory.path, 'kiji.log'));
  File get previous => File(p.join(directory.path, 'kiji.1.log'));

  void write(LogLine line) {
    // Nunca se usa debugPrint aquí: volvería a entrar al registro.
    try {
      if (_size < 0) {
        directory.createSync(recursive: true);
        _size = current.existsSync() ? current.lengthSync() : 0;
      }
      final text = '${line.at.toIso8601String()} ${scrubPersonalData(line.text)}\n';
      current.writeAsStringSync(text, mode: FileMode.append);
      _size += utf8.encode(text).length;
      if (_size > maxBytes) {
        if (previous.existsSync()) previous.deleteSync();
        current.renameSync(previous.path);
        _size = 0;
      }
    } catch (_) {
      // Sin espacio o sin permiso: el registro no puede trabar Kiji.
    }
  }

  /// Todo lo guardado, de lo más viejo a lo más nuevo.
  Future<String> readAll() async {
    final buffer = StringBuffer();
    for (final file in [previous, current]) {
      try {
        if (await file.exists()) buffer.write(await file.readAsString());
      } catch (_) {
        // Un archivo a medio escribir no impide leer el otro.
      }
    }
    return buffer.toString();
  }

  Future<int> sizeBytes() async {
    var total = 0;
    for (final file in [previous, current]) {
      if (await file.exists()) total += await file.length();
    }
    return total;
  }

  Future<void> delete() async {
    for (final file in [previous, current]) {
      if (await file.exists()) await file.delete();
    }
    _size = 0;
  }
}
