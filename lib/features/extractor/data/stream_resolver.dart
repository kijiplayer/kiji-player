import 'package:flutter/foundation.dart';

import '../../yt_music/data/yt_clients.dart';
import '../domain/extraction_failure.dart';
import '../domain/resolved_stream.dart';
import 'engines.dart';
import 'extractor_trace.dart';
import 'path_health.dart';
import '../../account/domain/yt_session.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Resultado de buscar el audio de una canción con todos los motores.
class ResolveOutcome {
  const ResolveOutcome.found(ResolvedStream this.stream, [this.failures = const []]) : problem = null, offline = false;
  const ResolveOutcome.content(ContentProblem this.problem, this.failures) : stream = null, offline = false;
  const ResolveOutcome.failed(this.failures, {this.offline = false}) : stream = null, problem = null;

  final ResolvedStream? stream;

  /// La canción tiene un problema propio (edad, no disponible…): no es culpa de ninguna forma.
  final ContentProblem? problem;
  final bool offline;
  final List<(String path, ExtractionFailure failure)> failures;
}

/// Prueba los motores en orden: en Android A → B; en PC B (→ C si el usuario lo
/// aceptó). Anota en la Salud solo las fallas de la forma, y decide si el problema es de la
/// canción cuando las formas coinciden.
class StreamResolver {
  StreamResolver({required this.engines, PathHealth? health, ExtractorTrace? trace, bool Function()? signedIn})
    : health = health ?? PathHealth.instance,
      trace = trace ?? ExtractorTrace.instance,
      signedIn = signedIn ?? (() => YtSessionHolder.signedIn);

  /// Hay una cuenta iniciada (Configuración → Cuenta).
  final bool Function() signedIn;

  final List<ExtractionEngine> engines;
  final PathHealth health;

  /// Las últimas búsquedas, para las herramientas de Kiji Dev.
  final ExtractorTrace trace;

  /// [skipPaths]: caminos que ya fallaron con esta canción ("A/AUTO", "B/WEB_REMIX").
  Future<ResolveOutcome> resolve(String videoId, {bool lowQuality = false, Set<String> skipPaths = const {}}) async {
    final watch = Stopwatch()..start();
    final outcome = await _resolve(videoId, lowQuality: lowQuality, skipPaths: skipPaths);
    trace.add(
      TraceEntry(
        at: DateTime.now(),
        videoId: videoId,
        elapsed: watch.elapsed,
        ok: outcome.stream != null,
        result:
            outcome.stream?.toString() ??
            (outcome.problem != null
                ? 'contenido: ${outcome.problem!.name}' // l10n-ignore
                : outcome.offline
                ? tx.sinConexionMinuscula
                : tx.fallo),
        failures: [for (final (path, failure) in outcome.failures) (path, failure.toString())],
      ),
    );
    return outcome;
  }

  Future<ResolveOutcome> _resolve(String videoId, {required bool lowQuality, required Set<String> skipPaths}) async {
    final failures = <(String, ExtractionFailure)>[];
    for (final engine in engines) {
      if (!engine.isSupported) continue;
      final prefix = engine.id.name.toUpperCase();
      if (skipPaths.contains('$prefix/AUTO')) continue;
      final skip = {
        for (final path in skipPaths)
          if (path.startsWith('$prefix/')) path.substring(prefix.length + 1),
      };
      final order = engine.id == EngineId.b
          ? health.order('B', [
              for (final c in ytPlayerClients)
                if (!c.isRetired) c.label,
            ])
          : null;
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
        return ResolveOutcome.found(stream, failures);
      }
      // Si un motor ya confirmó un problema de la canción, no tiene sentido seguir. Con la cuenta
      // opcional, la restricción de edad no corta: la prueban las formas que mandan la sesión.
      final verdict = contentVerdict([for (final f in failures) f.$2]);
      final accountMayHelp = verdict == ContentProblem.ageRestricted && signedIn();
      if (verdict != null && !accountMayHelp && failures.any((f) => f.$2.isConclusive)) {
        return ResolveOutcome.content(verdict, failures);
      }
    }
    final verdict = contentVerdict([for (final f in failures) f.$2]);
    if (verdict != null) return ResolveOutcome.content(verdict, failures);
    final offline = failures.isNotEmpty && failures.every((f) => f.$2.scope == FailureScope.network);
    return ResolveOutcome.failed(failures, offline: offline);
  }

  /// YouTube rechazó [stream] a mitad de la canción: falla de esa forma.
  Future<void> refused(ResolvedStream stream) async {
    health.recordFormFailure(stream.path, tx.youtubeCortoElAudioAMitad);
    for (final engine in engines) {
      if (engine.id == stream.engine) await engine.refused(stream);
    }
  }

  /// Corre suelto al abrir: nunca deja escapar un error.
  Future<void> prewarm() async {
    for (final engine in engines) {
      try {
        if (engine.isSupported) await engine.prewarm();
      } catch (error) {
        debugPrint('=== EXTRACTOR: no se pudo precalentar el motor ${engine.id}: $error ===');
      }
    }
  }
}
