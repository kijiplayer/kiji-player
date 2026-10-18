import 'package:flutter/foundation.dart';

import '../../yt_music/data/yt_clients.dart';
import '../domain/extraction_failure.dart';
import '../domain/resolved_stream.dart';
import 'engines.dart';
import 'path_health.dart';

/// Resultado de buscar el audio de una canción con todos los motores.
class ResolveOutcome {
  const ResolveOutcome.found(ResolvedStream this.stream)
      : problem = null,
        offline = false,
        failures = const [];
  const ResolveOutcome.content(ContentProblem this.problem, this.failures)
      : stream = null,
        offline = false;
  const ResolveOutcome.failed(this.failures, {this.offline = false})
      : stream = null,
        problem = null;

  final ResolvedStream? stream;

  /// La canción tiene un problema propio (edad, no disponible…): no es culpa de ninguna forma.
  final ContentProblem? problem;
  final bool offline;
  final List<(String path, ExtractionFailure failure)> failures;
}

/// Prueba los motores en orden (Tarea Z8): en Android A → B; en PC B (→ C si el usuario lo
/// aceptó). Anota en la Salud solo las fallas de la forma, y decide si el problema es de la
/// canción cuando las formas coinciden.
class StreamResolver {
  StreamResolver({required this.engines, PathHealth? health}) : health = health ?? PathHealth.instance;

  final List<ExtractionEngine> engines;
  final PathHealth health;

  /// [skipPaths]: caminos que ya fallaron con esta canción ("A/AUTO", "B/WEB_REMIX").
  Future<ResolveOutcome> resolve(String videoId, {bool lowQuality = false, Set<String> skipPaths = const {}}) async {
    final failures = <(String, ExtractionFailure)>[];
    for (final engine in engines) {
      if (!engine.isSupported) continue;
      final prefix = engine.id.name.toUpperCase();
      if (skipPaths.contains('$prefix/AUTO')) continue;
      final skip = {for (final path in skipPaths) if (path.startsWith('$prefix/')) path.substring(prefix.length + 1)};
      final order = engine.id == EngineId.b ? health.order('B', [for (final c in ytPlayerClients) if (!c.isRetired) c.label]) : null;
      final result = await engine.resolve(videoId, lowQuality: lowQuality, skip: skip, order: order);
      for (final (form, failure) in result.failures) {
        final path = '$prefix/$form';
        failures.add((path, failure));
        if (failure.scope == FailureScope.form) health.recordFormFailure(path, failure.message);
      }
      final stream = result.stream;
      if (stream != null) {
        health.recordSuccess(stream.path);
        debugPrint('=== EXTRACTOR: $stream ===');
        return ResolveOutcome.found(stream);
      }
      // Si un motor ya confirmó un problema de la canción, no tiene sentido seguir.
      final verdict = contentVerdict([for (final f in failures) f.$2]);
      if (verdict != null && failures.any((f) => f.$2.isConclusive)) return ResolveOutcome.content(verdict, failures);
    }
    final verdict = contentVerdict([for (final f in failures) f.$2]);
    if (verdict != null) return ResolveOutcome.content(verdict, failures);
    final offline = failures.isNotEmpty && failures.every((f) => f.$2.scope == FailureScope.network);
    return ResolveOutcome.failed(failures, offline: offline);
  }

  /// YouTube rechazó [stream] a mitad de la canción: falla de esa forma.
  Future<void> refused(ResolvedStream stream) async {
    health.recordFormFailure(stream.path, 'YouTube cortó el audio a mitad de la canción');
    for (final engine in engines) {
      if (engine.id == stream.engine) await engine.refused(stream);
    }
  }

  Future<void> prewarm() async {
    for (final engine in engines) {
      if (engine.isSupported) await engine.prewarm();
    }
  }
}
