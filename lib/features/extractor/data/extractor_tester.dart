import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../yt_music/data/yt_clients.dart';
import '../../yt_music/data/ytm_client.dart';
import '../domain/resolved_stream.dart';
import 'engines.dart';
import 'path_health.dart';

/// Canciones de CONTROL (Tarea Z8): normales, públicas y disponibles en todo el mundo. Las
/// pruebas nunca usan el historial ni nada del usuario.
const controlVideos = <(String id, String name)>[
  ('BSTsnWoslP4', 'Bohemian Rhapsody · Queen'),
  ('8Xv_Hg8o1fw', 'Clocks · Coldplay'),
  ('BycLmWI97Nc', 'La Bamba · Ritchie Valens'),
];

/// Formas del motor A que se prueban una por una (las automáticas de InnerTubeX que sirven sin
/// cuenta; las demás las usa solo si hacen falta).
const engineAForms = ['VISIONOS_0_1', 'VISIONOS', 'WEB_REMIX', 'WEB_EMBEDDED_PLAYER', 'TVHTML5_SIMPLY'];

/// Resultado de probar un camino con una canción de control.
class PathTestResult {
  const PathTestResult(this.path, {required this.ok, this.reason, this.elapsed = Duration.zero, this.control});

  final String path;
  final bool ok;
  final String? reason;
  final Duration elapsed;
  final String? control;
}

/// Prueba cada camino con una canción de control y la prueba del ÚLTIMO byte (así se detectan
/// las formas que cortan en 1 MiB, como hace `validateStatus` en Echo).
class ExtractorTester {
  ExtractorTester({
    required this.client,
    InnerTubeXEngine? engineA,
    PathHealth? health,
    Dio? dio,
    DateTime Function()? now,
  })  : engineA = engineA ?? InnerTubeXEngine(),
        health = health ?? PathHealth.instance,
        _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20))),
        _now = now ?? DateTime.now;

  final YtMusicClient client;
  final InnerTubeXEngine engineA;
  final PathHealth health;
  final Dio _dio;
  final DateTime Function() _now;

  /// Una canción de control por forma, rotando cada día.
  (String, String) controlFor(int index) => controlVideos[(index + _now().day) % controlVideos.length];

  /// null si el último byte llegó; si no, el motivo.
  Future<String?> lastByteCheck(ResolvedStream stream) async {
    try {
      if (stream.isHls) {
        final r = await _dio.get<String>(stream.url, options: Options(headers: stream.headers, validateStatus: (_) => true));
        return r.statusCode == 200 ? null : 'La lista HLS no responde (HTTP ${r.statusCode})';
      }
      var length = stream.contentLength;
      if (length == null || length <= 0) {
        final first = await _get(stream, 'bytes=0-0');
        length = int.tryParse((first.headers.value('content-range') ?? '').split('/').last);
        if (length == null) return 'YouTube no dijo el tamaño del audio (HTTP ${first.statusCode})';
      }
      final last = await _get(stream, 'bytes=${length - 1}-${length - 1}');
      final status = last.statusCode ?? 0;
      if ((status == 206 || status == 200) && (last.data?.isNotEmpty ?? false)) return null;
      return status == 403 ? 'Corta antes del final (HTTP 403 en el último byte)' : 'El último byte no llegó (HTTP $status)';
    } catch (error) {
      return 'No se pudo pedir el último byte (${error.runtimeType})';
    }
  }

  Future<Response<List<int>>> _get(ResolvedStream s, String range) => _dio.get<List<int>>(
        s.url,
        options: Options(responseType: ResponseType.bytes, headers: {...s.headers, 'Range': range}, validateStatus: (_) => true),
      );

  /// Prueba todos los caminos (A en Android, B siempre) y lo anota en la Salud.
  Future<List<PathTestResult>> runAll({void Function(PathTestResult)? onResult}) async {
    final results = <PathTestResult>[];
    void add(PathTestResult r) {
      results.add(r);
      // Con una canción de control cualquier falla es de la forma (la canción sí se puede escuchar).
      r.ok ? health.recordSuccess(r.path) : health.recordFormFailure(r.path, r.reason ?? 'Falló la prueba');
      onResult?.call(r);
    }

    var i = 0;
    if (engineA.isSupported) {
      for (final form in engineAForms) {
        final (videoId, name) = controlFor(i++);
        final watch = Stopwatch()..start();
        final result = await engineA.resolveWith(videoId, only: form);
        final stream = result.stream;
        if (stream == null) {
          final f = result.failures.isEmpty ? null : result.failures.first.$2;
          add(PathTestResult('A/$form', ok: false, reason: f?.message ?? 'Sin audio', elapsed: watch.elapsed, control: name));
          continue;
        }
        final problem = await lastByteCheck(stream);
        add(PathTestResult('A/$form', ok: problem == null, reason: problem, elapsed: watch.elapsed, control: name));
      }
    }
    // En la PC el reproductor no abre listas HLS: esas formas no aplican (no son una falla).
    final hlsPlays = !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
    for (final c in ytPlayerClients) {
      if (c.isRetired || (c.useHls && !hlsPlays)) continue;
      final (videoId, name) = controlFor(i++);
      final attempt = await client.tryClient(videoId, c);
      // tryClient ya pide el final del archivo (y el último segmento en HLS).
      add(PathTestResult(
        'B/${c.label}',
        ok: attempt.ok,
        reason: attempt.ok ? null : (attempt.offline ? 'Sin conexión' : attempt.reason),
        elapsed: attempt.elapsed,
        control: name,
      ));
    }
    health.markTested();
    debugPrint('=== SALUD: prueba completa, ${results.where((r) => r.ok).length} de ${results.length} caminos andan ===');
    return results;
  }
}

/// Resumen en palabras simples para arriba de la Salud del Extractor.
String healthSummary(List<PathTestResult> results) {
  final ok = results.where((r) => r.ok).length;
  if (results.isEmpty) return 'Todavía no se probó.';
  if (ok == 0) return 'Canciones normales: ✗ ninguna forma funciona ahora';
  return 'Canciones normales: ✓ $ok ${ok == 1 ? 'forma funcionando' : 'formas funcionando'}';
}

/// El problema de contenido nunca baja el contador de formas.
const ageSummary = 'Con restricción de edad: necesitan cuenta (no cuentan como falla)';
