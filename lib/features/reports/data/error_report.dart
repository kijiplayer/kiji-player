import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../utils/app_log.dart';
import '../../updates/update_checker.dart';
import 'log_scrubber.dart';

/// Repositorio donde llegan los informes (Tarea T3).
const kijiRepoUrl = 'https://github.com/kijiplayer/kiji-player';

/// Un error para ofrecer mandar (Tarea T3). Todo el texto ya va sin datos personales.
class ErrorReport {
  ErrorReport({
    required this.summary,
    required this.where,
    this.detail = '',
    this.stack = '',
    DateTime? at,
  }) : at = at ?? DateTime.now();

  /// En palabras simples: "Algo falló al reproducir".
  final String summary;

  /// Parte de Kiji: "reproducción", "interfaz", "segundo plano".
  final String where;

  /// Tipo y mensaje del error.
  final String detail;

  /// Las primeras líneas de la pila.
  final String stack;
  final DateTime at;
}

String _platform() {
  if (kIsWeb) return 'web';
  return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
}

/// El informe completo en texto (para el .txt y para GitHub). [log] es el registro (si no se
/// pasa, se usan las líneas en memoria); se toman las últimas [logLines].
String buildReportText(ErrorReport? report, {String? log, int logLines = 120, String? platform}) {
  final lines = (log ?? AppLog.lines.map((l) => '$l').join('\n'))
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  final tail = lines.length > logLines ? lines.sublist(lines.length - logLines) : lines;
  final b = StringBuffer()
    ..writeln('Informe de Kiji Player')
    ..writeln('Versión: $kijiVersion')
    ..writeln('Sistema: ${scrubPersonalData(platform ?? _platform())}')
    ..writeln('Fecha: ${(report?.at ?? DateTime.now()).toIso8601String().substring(0, 19)}');
  if (report != null) {
    b
      ..writeln()
      ..writeln('Qué pasó: ${report.summary}')
      ..writeln('Dónde: ${report.where}');
    if (report.detail.isNotEmpty) b.writeln('Detalle: ${scrubPersonalData(report.detail)}');
    if (report.stack.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Pila:')
        ..writeln(scrubPersonalData(report.stack));
    }
  }
  b
    ..writeln()
    ..writeln('Registro (últimas ${tail.length} líneas, sin datos personales):');
  for (final line in tail) {
    b.writeln(scrubPersonalData(line));
  }
  return b.toString();
}

/// Enlace a un issue de GitHub ya escrito (con el formulario `error.yml`). El usuario lo ve
/// en GitHub y decide si lo manda. Se recorta el registro para que el enlace no sea demasiado
/// largo (los navegadores cortan cerca de 8000 caracteres).
Uri githubIssueUri(ErrorReport? report, {String? log, int maxLength = 7500}) {
  final title = report == null ? 'Informe de Kiji' : 'Error: ${report.summary}';
  for (var lines = 120; lines >= 0; lines = lines > 20 ? lines - 20 : lines - 5) {
    final uri = Uri.parse('$kijiRepoUrl/issues/new').replace(queryParameters: {
      'template': 'error.yml',
      'title': title,
      'informe': buildReportText(report, log: log, logLines: lines),
    });
    if (uri.toString().length <= maxLength || lines <= 0) return uri;
  }
  return Uri.parse('$kijiRepoUrl/issues/new?template=error.yml');
}
