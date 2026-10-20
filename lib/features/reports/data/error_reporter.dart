// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
import 'package:flutter/foundation.dart';

import 'error_report.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Junta los errores de Kiji para ofrecer mandar un informe (Tarea T3).
///
/// - Los cortes de red no cuentan: no son fallas de Kiji.
/// - Los errores de dibujo que el usuario no nota (un texto que no entra, un aviso a destiempo)
///   van solo al registro.
/// - Como mucho UN aviso por sesión, en total (y la app nunca lo muestra mientras suena música).
/// - Nunca manda nada solo: deja el informe en [pending] y la app pregunta.
class ErrorReporter {
  ErrorReporter();

  static final instance = ErrorReporter();

  /// El informe que la app tiene que ofrecer (null: nada pendiente).
  final pending = ValueNotifier<ErrorReport?>(null);

  /// Los últimos errores de esta sesión (para la pantalla Registros e informes).
  final List<ErrorReport> recent = [];

  /// Ya se ofreció un aviso en esta sesión: los siguientes errores solo van al registro.
  bool _offeredThisSession = false;

  static const _noise = [
    'Socket',
    'Http',
    'Timeout',
    'Handshake',
    'Connection',
    'ClientException',
    'Interrupted',
    'Dio',
    'PlatformException(abort',
    'Loading interrupted',
  ];

  /// true si [error] es de red o de un corte esperado (no es una falla de Kiji).
  static bool isNoise(Object error) {
    final text = '${error.runtimeType} $error';
    return _noise.any(text.contains);
  }

  /// Errores de la interfaz que no le cambian nada al usuario: se anotan y nada más.
  static const _drawingOnly = [
    'overflowed',
    'setState() or markNeedsBuild() called during build',
    'was used after being disposed',
    'Incorrect use of ParentDataWidget',
    'ink splashes may be invisible',
  ];

  /// true si [error] es solo de dibujo (el usuario no lo nota).
  static bool isDrawingOnly(Object error) {
    final text = '$error';
    return _drawingOnly.any(text.contains);
  }

  /// Un error de Flutter (interfaz). De los de dibujo se anota también el widget culpable que
  /// trae Flutter ("The relevant error-causing widget was…"), porque no tienen pila útil.
  void captureFlutter(FlutterErrorDetails details) {
    if (isDrawingOnly(details.exception)) {
      final text = details.toString().split('\n');
      final culprit = [
        for (var i = 0; i < text.length; i++)
          if (text[i].contains('error-causing widget') || text[i].contains('creator:')) ...text.skip(i).take(4),
      ];
      debugPrint(
        '=== REGISTRO: error de dibujo (sin aviso): ${'${details.exception}'.split('\n').first} '
        '${culprit.map((l) => l.trim()).join(' ')} ===',
      );
      return;
    }
    capture(details.exception, details.stack, where: 'interfaz');
  }

  /// Un error que nadie capturó (o de la interfaz).
  void capture(Object error, StackTrace? stack, {required String where}) {
    if (isNoise(error)) return;
    if (isDrawingOnly(error)) {
      debugPrint('=== REGISTRO: error de dibujo (sin aviso): ${'$error'.split('\n').first} ===');
      return;
    }
    final lines = '${stack ?? ''}'.split('\n').where((l) => l.trim().isNotEmpty).take(12).join('\n');
    _offer(
      ErrorReport(
        summary: tx.algoFalloEn(where == 'interfaz' ? tx.laPantalla : where),
        where: where,
        detail: '${error.runtimeType}: $error'.split('\n').first,
        stack: lines,
      ),
    );
  }

  /// Una canción de YouTube no sonó con ninguna forma, con internet (Modo de Gracia).
  void unplayable(String videoId) => _offer(
    ErrorReport(
      summary: tx.unaCancionNoSePudoReproducir,
      where: tx.reproduccion,
      detail: tx.videoCaminosAgotados(videoId),
    ),
  );

  void _offer(ErrorReport report) {
    debugPrint('=== INFORME: ${report.summary} (${report.where}) ${report.detail} ===');
    // Las primeras líneas de la pila, para encontrar el error en el registro.
    if (report.stack.isNotEmpty) debugPrint(report.stack.split('\n').take(8).join('\n'));
    recent.add(report);
    if (recent.length > 20) recent.removeAt(0);
    if (_offeredThisSession) return;
    _offeredThisSession = true;
    pending.value ??= report;
  }

  /// El usuario ya eligió (mandar, descargar o "No, gracias").
  void dismiss() => pending.value = null;

  @visibleForTesting
  void reset() {
    _offeredThisSession = false;
    recent.clear();
    pending.value = null;
  }
}
