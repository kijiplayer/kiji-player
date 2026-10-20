// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Una línea del registro de Kiji.
class LogLine {
  const LogLine(this.at, this.text);

  final DateTime at;
  final String text;

  String get time {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}.${at.millisecond.toString().padLeft(3, '0')}';
  }

  @override
  String toString() => '$time $text';
}

/// Registro de Kiji en memoria: se queda con las últimas [capacity] líneas de
/// `debugPrint` para verlas en vivo en las herramientas de Kiji Dev. Todo lo que Kiji anota
/// pasa por aquí.
abstract final class AppLog {
  static const capacity = 2000;

  static final _lines = ListQueue<LogLine>();
  static final _controller = StreamController<LogLine>.broadcast();
  static bool _installed = false;

  /// Las líneas guardadas, de la más vieja a la más nueva.
  static List<LogLine> get lines => List.unmodifiable(_lines);

  /// Cada línea nueva, en vivo.
  static Stream<LogLine> get stream => _controller.stream;

  /// Engancha `debugPrint` (una sola vez; el original sigue escribiendo en la consola).
  static void install() {
    if (_installed) return;
    _installed = true;
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) add(message);
      original(message, wrapWidth: wrapWidth);
    };
  }

  static void Function(LogLine line)? _sink;

  /// Copia cada línea también a [sink] (el registro guardado), empezando por
  /// las que ya están en memoria. Con null deja de copiar.
  static void attachSink(void Function(LogLine line)? sink) {
    _sink = sink;
    if (sink != null) _lines.forEach(sink);
  }

  static void add(String text, {DateTime? at}) {
    final line = LogLine(at ?? DateTime.now(), tidy(text));
    _sink?.call(line);
    _lines.addLast(line);
    while (_lines.length > capacity) {
      _lines.removeFirst();
    }
    if (_controller.hasListener) _controller.add(line);
  }

  /// Sin los `===` que marcan las líneas de Kiji en la consola.
  static String tidy(String text) {
    var t = text.trim();
    if (t.startsWith('=== ')) t = t.substring(4);
    if (t.endsWith(' ===')) t = t.substring(0, t.length - 4);
    return t;
  }

  @visibleForTesting
  static void clear() => _lines.clear();
}
