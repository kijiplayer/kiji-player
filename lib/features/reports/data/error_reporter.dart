import 'package:flutter/foundation.dart';

import 'error_report.dart';

/// Junta los errores de Kiji para ofrecer mandar un informe (Tarea T3).
///
/// - Los cortes de red no cuentan: no son fallas de Kiji.
/// - Cada tipo de error se ofrece una sola vez por sesión (no molesta con el mismo aviso).
/// - Nunca manda nada solo: deja el informe en [pending] y la app pregunta.
class ErrorReporter {
  ErrorReporter();

  static final instance = ErrorReporter();

  /// El informe que la app tiene que ofrecer (null: nada pendiente).
  final pending = ValueNotifier<ErrorReport?>(null);

  /// Los últimos errores de esta sesión (para la pantalla Registros e informes).
  final List<ErrorReport> recent = [];

  final Set<String> _offered = {};

  static const _noise = [
    'Socket', 'Http', 'Timeout', 'Handshake', 'Connection', 'ClientException', 'Interrupted', 'Dio',
    'PlatformException(abort', 'Loading interrupted',
  ];

  /// true si [error] es de red o de un corte esperado (no es una falla de Kiji).
  static bool isNoise(Object error) {
    final text = '${error.runtimeType} $error';
    return _noise.any(text.contains);
  }

  /// Un error que nadie capturó (o de la interfaz).
  void capture(Object error, StackTrace? stack, {required String where}) {
    if (isNoise(error)) return;
    final lines = '${stack ?? ''}'.split('\n').where((l) => l.trim().isNotEmpty).take(12).join('\n');
    _offer(
      '${error.runtimeType}@$where',
      ErrorReport(
        summary: 'Algo falló en ${where == 'interfaz' ? 'la pantalla' : where}',
        where: where,
        detail: '${error.runtimeType}: $error'.split('\n').first,
        stack: lines,
      ),
    );
  }

  /// Una canción de YouTube no sonó con ninguna forma, con internet (Modo de Gracia).
  void unplayable(String videoId) => _offer(
        'unplayable',
        ErrorReport(
          summary: 'Una canción no se pudo reproducir con ninguna forma',
          where: 'reproducción',
          detail: 'video $videoId: caminos agotados',
        ),
      );

  void _offer(String key, ErrorReport report) {
    debugPrint('=== INFORME: ${report.summary} (${report.where}) ${report.detail} ===');
    // Las primeras líneas de la pila, para encontrar el error en el registro.
    if (report.stack.isNotEmpty) debugPrint(report.stack.split('\n').take(8).join('\n'));
    recent.add(report);
    if (recent.length > 20) recent.removeAt(0);
    if (!_offered.add(key)) return;
    pending.value ??= report;
  }

  /// El usuario ya eligió (mandar, descargar o "No, gracias").
  void dismiss() => pending.value = null;

  @visibleForTesting
  void reset() {
    _offered.clear();
    recent.clear();
    pending.value = null;
  }
}
