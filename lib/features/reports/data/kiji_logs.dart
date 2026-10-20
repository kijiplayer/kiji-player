import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/app_log.dart';
import 'log_file.dart';

/// Prende o apaga el registro guardado según Configuración → Registros e informes.
abstract final class KijiLogs {
  static Future<Directory> Function() directory =
      () async => Directory(p.join((await getApplicationSupportDirectory()).path, 'logs'));

  static LogFile? _file;
  static bool _enabled = false;

  static bool get enabled => _enabled;

  static Future<LogFile> file() async => _file ??= LogFile(await directory());

  /// Con [on] en false deja de guardar y borra lo guardado.
  static Future<void> setEnabled(bool on) async {
    _enabled = on;
    if (!on) AppLog.attachSink(null);
    try {
      final log = await file();
      if (on) {
        AppLog.attachSink(log.write);
      } else {
        await log.delete();
      }
    } catch (error) {
      // Sin carpeta (pruebas, permisos): Kiji sigue sin registro guardado.
      _enabled = false;
      debugPrint('=== REGISTRO: no se pudo ${on ? 'abrir' : 'borrar'} el registro guardado (${error.runtimeType}) ===');
    }
  }

  /// El registro para un informe: lo guardado (varias sesiones) o, si está apagado, lo de esta
  /// sesión que está en memoria.
  static Future<String> text() async {
    if (_enabled) {
      final saved = await (await file()).readAll();
      if (saved.trim().isNotEmpty) return saved;
    }
    return AppLog.lines.map((l) => '$l').join('\n');
  }
}
