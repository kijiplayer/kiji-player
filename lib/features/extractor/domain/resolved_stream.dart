import 'extraction_failure.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Los motores de extracción (Tarea Z8).
enum EngineId {
  /// InnerTubeX, solo Android (principal ahí).
  a,

  /// El de Kiji, en todas las plataformas (principal en PC, respaldo en Android).
  b,

  /// yt-dlp, solo PC y a pedido.
  c;

  String get label => switch (this) {
    EngineId.a => tx.motorAInnertubex,
    EngineId.b => tx.motorBKiji,
    EngineId.c => tx.motorCYtDlp,
  };
}

/// Un audio listo para reproducir, con la identidad que tiene que usar al pedirlo.
class ResolvedStream {
  const ResolvedStream({
    required this.videoId,
    required this.url,
    required this.engine,
    required this.form,
    this.headers = const {},
    this.mime,
    this.kbps,
    this.expiresAt,
    this.contentLength,
    this.chunkSize,
    this.isHls = false,
  });

  final String videoId;
  final String url;
  final EngineId engine;

  /// La forma que lo entregó ("WEB_REMIX", "VISIONOS_0_1"…); con [engine] identifica el camino.
  final String form;
  final Map<String, String> headers;
  final String? mime;
  final int? kbps;
  final DateTime? expiresAt;
  final int? contentLength;

  /// Si la forma solo entrega pedazos acotados, de cuántos bytes pedirlos.
  final int? chunkSize;
  final bool isHls;

  /// Identificador del camino para la Salud del Extractor ("A/WEB_REMIX").
  String get path => '${engine.name.toUpperCase()}/$form';

  String get extension => (mime ?? Uri.parse(url).queryParameters['mime'] ?? '').contains('webm') ? 'webm' : 'm4a';

  /// Nunca la URL ni los encabezados (van firmados).
  @override
  String toString() => tx.resolvedstreamKbps(path, kbps ?? '?', isHls ? ', HLS' : ''); // l10n-ignore
}

/// Lo que devuelve un motor: el audio, o por qué no.
class EngineResult {
  const EngineResult.ok(ResolvedStream this.stream) : failures = const [];
  const EngineResult.failed(this.failures) : stream = null;

  final ResolvedStream? stream;

  /// Una por forma probada (sin las que no aplican).
  final List<(String form, ExtractionFailure failure)> failures;

  bool get ok => stream != null;
}
