import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../yt_music/data/ytm_client.dart';
import '../domain/extraction_failure.dart';
import '../domain/resolved_stream.dart';

/// Un motor de extracción (Tarea Z8): todos dan el mismo [ResolvedStream] o fallas clasificadas.
abstract class ExtractionEngine {
  EngineId get id;

  /// Si funciona en esta plataforma.
  bool get isSupported;

  /// [skip]: formas que ya fallaron con esta canción. [order]: orden preferido de las formas.
  Future<EngineResult> resolve(String videoId, {bool lowQuality = false, Set<String> skip = const {}, List<String>? order});

  /// YouTube rechazó esta URL a mitad de la canción.
  Future<void> refused(ResolvedStream stream) async {}

  /// Pagar los costos en frío antes de la primera canción.
  Future<void> prewarm() async {}
}

/// Motor A: InnerTubeX en el lado Android, por el canal `kiji/innertubex`.
class InnerTubeXEngine extends ExtractionEngine {
  InnerTubeXEngine({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('kiji/innertubex');

  final MethodChannel _channel;

  @override
  EngineId get id => EngineId.a;

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  @override
  Future<EngineResult> resolve(String videoId, {bool lowQuality = false, Set<String> skip = const {}, List<String>? order}) =>
      resolveWith(videoId, lowQuality: lowQuality, skip: skip);

  /// Con [only], prueba una sola forma de InnerTubeX (para la Salud del Extractor).
  Future<EngineResult> resolveWith(String videoId, {bool lowQuality = false, Set<String> skip = const {}, String? only}) async {
    if (!isSupported) return const EngineResult.failed([]);
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('extract', {
        'videoId': videoId,
        'quality': lowQuality ? 'low' : 'auto',
        'skip': skip.toList(),
        'only': ?only,
      });
      return innerTubeXResult(videoId, map);
    } on PlatformException catch (error) {
      debugPrint('=== MOTOR A: el canal falló: ${error.code} ${error.message} ===');
      return EngineResult.failed([('AUTO', ExtractionFailure(FailureScope.form, 'El motor A falló (${error.message})'))]);
    } on MissingPluginException {
      return const EngineResult.failed([]);
    }
  }

  @override
  Future<void> refused(ResolvedStream stream) async {
    try {
      await _channel.invokeMethod<void>('onRefused', {'url': stream.url});
    } on PlatformException catch (error) {
      debugPrint('=== MOTOR A: no se pudo avisar el rechazo: ${error.code} ===');
    }
  }

  @override
  Future<void> prewarm() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('prewarm');
    } on PlatformException catch (error) {
      debugPrint('=== MOTOR A: no se pudo precalentar: ${error.code} ===');
    }
  }
}

/// Convierte la respuesta del canal (ver `InnerTubeXEngine.kt`) en un [EngineResult].
@visibleForTesting
EngineResult innerTubeXResult(String videoId, Map<String, Object?>? map) {
  if (map == null) return EngineResult.failed([('AUTO', const ExtractionFailure(FailureScope.form, 'El motor A no respondió'))]);
  final error = map['error'] as String?;
  if (error != null) {
    final reason = '${map['reason'] ?? ''}';
    final failure = switch (reason) {
      'age_restricted' => const ExtractionFailure(FailureScope.content, 'Tiene restricción de edad',
          problem: ContentProblem.ageRestricted, confirmed: true),
      'unavailable' => const ExtractionFailure(FailureScope.content, 'YouTube dice que no está disponible',
          problem: ContentProblem.unavailable, confirmed: true),
      'explicit_unsupported' || 'no_music_video' => ExtractionFailure(FailureScope.content, 'InnerTubeX no la reproduce ($reason)',
          problem: ContentProblem.unavailable),
      'network' => const ExtractionFailure(FailureScope.network, 'Sin conexión'),
      _ => ExtractionFailure(FailureScope.form, 'Motor A: ${map['message'] ?? reason}'),
    };
    return EngineResult.failed([('AUTO', failure)]);
  }
  final url = map['url'] as String?;
  if (url == null) return EngineResult.failed([('AUTO', const ExtractionFailure(FailureScope.form, 'El motor A no dio URL'))]);
  final expires = map['expiresAtMs'] as int?;
  return EngineResult.ok(ResolvedStream(
    videoId: videoId,
    url: url,
    engine: EngineId.a,
    form: '${map['profileId'] ?? map['client'] ?? 'AUTO'}',
    headers: {for (final e in ((map['headers'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
    mime: map['mime'] as String?,
    kbps: map['kbps'] as int?,
    expiresAt: expires == null ? null : DateTime.fromMillisecondsSinceEpoch(expires),
    contentLength: (map['contentLength'] as num?)?.toInt(),
    chunkSize: (map['chunkSize'] as num?)?.toInt(),
    isHls: map['isHls'] == true,
  ));
}

/// Motor B: el extractor propio de Kiji (todas las plataformas).
class KijiEngine extends ExtractionEngine {
  KijiEngine(this.client);

  final YtMusicClient client;

  @override
  EngineId get id => EngineId.b;

  @override
  bool get isSupported => true;

  @override
  Future<EngineResult> resolve(String videoId, {bool lowQuality = false, Set<String> skip = const {}, List<String>? order}) async {
    final attempts = <StreamAttempt>[];
    final stream = await client.resolveStream(
      videoId,
      skipClients: skip,
      lowQuality: lowQuality,
      attempts: attempts,
      order: order,
      isContentProblem: (reason) => classifyFailure(reason).isContent,
    );
    if (stream != null) {
      return EngineResult.ok(ResolvedStream(
        videoId: videoId,
        url: stream.url,
        engine: EngineId.b,
        form: stream.client,
        headers: {'User-Agent': stream.userAgent},
        contentLength: stream.contentLength,
        isHls: stream.isHls,
      ));
    }
    return EngineResult.failed([
      for (final a in attempts)
        if (!a.ok) (a.client, a.offline ? const ExtractionFailure(FailureScope.network, 'Sin conexión') : classifyFailure(a.reason ?? '')),
    ]);
  }
}
