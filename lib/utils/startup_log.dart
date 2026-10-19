import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Registro del arranque (bug de Windows: "queda en blanco o no abre"). Anota cada fase con su
/// tiempo en `%LOCALAPPDATA%\Kiji Player\logs\inicio.log` (en Windows; en otras plataformas
/// solo en la consola), con escrituras síncronas para que quede escrito aunque la app se trabe
/// justo después. Si el primer cuadro tarda más de 8 s, lo anota con la última fase.
/// No guarda datos personales: solo nombres de fases y tiempos.
abstract final class StartupLog {
  static final _watch = Stopwatch();
  static File? _file;
  static String _lastPhase = 'inicio';
  static bool _firstFrame = false;

  static const maxBytes = 64 * 1024;

  static void start() {
    _watch.start();
    try {
      final base = Platform.isWindows ? Platform.environment['LOCALAPPDATA'] : null;
      if (base != null) {
        final dir = Directory('$base\\Kiji Player\\logs')..createSync(recursive: true);
        final file = File('${dir.path}\\inicio.log');
        // Tamaño limitado: si creció mucho, se empieza de nuevo.
        if (file.existsSync() && file.lengthSync() > maxBytes) file.deleteSync();
        _file = file;
      }
    } catch (error) {
      debugPrint('=== INICIO: no se pudo abrir el registro: $error ===');
    }
    mark('— Kiji arranca (${DateTime.now().toIso8601String()}) —');
    // Vigía: si en 8 s no hay primer cuadro, queda escrito dónde se trabó.
    Timer(const Duration(seconds: 8), () {
      if (!_firstFrame) mark('AVISO: sin primer cuadro después de 8 s; última fase: $_lastPhase');
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _firstFrame = true;
      mark('primer cuadro dibujado');
    });
  }

  /// Anota una fase ("media_kit listo", "restaurar cola"…).
  static void mark(String phase) {
    _lastPhase = phase;
    final line = '[${_watch.elapsedMilliseconds.toString().padLeft(6)} ms] $phase';
    debugPrint('=== INICIO $line ===');
    try {
      _file?.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } catch (error) {
      debugPrint('=== INICIO: no se pudo escribir el registro: $error ===');
    }
  }

  /// Corre [task] anotando su inicio, su fin o su error; nunca deja caer la app.
  static Future<T?> guard<T>(String phase, Future<T> Function() task, {Duration limit = const Duration(seconds: 20)}) async {
    mark('$phase…');
    try {
      final result = await task().timeout(limit);
      mark('$phase: listo');
      return result;
    } on TimeoutException {
      mark('$phase: tardó más de ${limit.inSeconds} s; la app sigue');
      return null;
    } catch (error) {
      mark('$phase: falló (${error.runtimeType}); la app sigue');
      return null;
    }
  }
}
