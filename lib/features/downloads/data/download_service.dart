// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../playback/DownloadUtil.kt y
// ExoDownloadService.kt (descarga a almacenamiento privado, reanudable).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../extractor/data/engines.dart';
import '../../extractor/data/stream_resolver.dart';
import '../../extractor/domain/resolved_stream.dart';
import '../../yt_music/data/ytm_client.dart';
import '../domain/download_failure.dart';
import 'downloads_repository.dart';

/// Lo que se sabe de una descarga antes de empezarla: la URL de audio ya
/// resuelta (con la identidad de la forma que la dio) y, si YouTube lo informa,
/// cuánto va a ocupar.
class DownloadEstimate {
  const DownloadEstimate({
    required this.url,
    required this.extension,
    this.sizeBytes,
    this.headers = const {},
    this.path,
    this.chunkBytes,
    this.stream,
  });

  final String url;
  final String extension;
  final int? sizeBytes;

  /// Encabezados que pide la forma (Tarea T4: los motores de Z8 los necesitan).
  final Map<String, String> headers;

  /// Camino que la dio ("A/WEB_REMIX"), para saltearlo si YouTube corta la descarga.
  final String? path;

  /// Si la forma solo entrega pedazos acotados, de cuántos bytes pedirlos.
  final int? chunkBytes;
  final ResolvedStream? stream;
}

/// El audio para descargar, o por qué no se puede (en palabras simples).
class EstimateOutcome {
  const EstimateOutcome.ok(DownloadEstimate this.estimate) : failure = null;
  const EstimateOutcome.failed(DownloadFailure this.failure) : estimate = null;

  final DownloadEstimate? estimate;
  final DownloadFailure? failure;
}

/// La URL de audio venció o fue rechazada (403/410): hay que resolverla de nuevo.
class ExpiredUrlException implements Exception {
  const ExpiredUrlException();
}

class DownloadService {
  DownloadService(this._repository, {YtMusicClient? ytClient, StreamResolver? resolver, Dio? dio})
      : ytClient = ytClient ?? YtMusicClient(),
        _resolverOverride = resolver,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ));

  final DownloadsRepository _repository;
  final YtMusicClient ytClient;
  final StreamResolver? _resolverOverride;
  final Dio _dio;

  /// Los mismos motores que la reproducción (Tarea T4): en Android A → B, en PC B (→ C).
  late final StreamResolver resolver =
      _resolverOverride ?? StreamResolver(engines: [InnerTubeXEngine(), KijiEngine(ytClient)]);

  /// Partes de 4 MiB: YouTube limita la velocidad de los pedidos grandes de
  /// una sola vez, y además cada parte terminada queda guardada si se corta.
  static const _chunkBytes = 4 * 1024 * 1024;

  /// Resuelve el audio de [videoId] con los motores y calcula el tamaño. Las listas HLS no se
  /// pueden bajar por pedazos: se saltean y se prueba la forma siguiente. [skipPaths]: caminos
  /// que ya cortaron esta descarga.
  Future<EstimateOutcome> estimate(String videoId, {Set<String> skipPaths = const {}}) async {
    final tried = {...skipPaths};
    ResolvedStream? stream;
    for (var attempt = 0; attempt < 12; attempt++) {
      final outcome = await resolver.resolve(videoId, skipPaths: tried);
      final found = outcome.stream;
      if (found == null) return EstimateOutcome.failed(DownloadFailure.fromOutcome(outcome));
      if (!found.isHls) {
        stream = found;
        break;
      }
      // Si el motor vuelve a dar la misma forma, se saltea el motor entero.
      if (!tried.add(found.path)) tried.add('${found.engine.name.toUpperCase()}/AUTO');
    }
    if (stream == null) return EstimateOutcome.failed(DownloadFailure.allFormsFailed);

    final url = stream.url;
    final uri = Uri.parse(url);
    var size = stream.contentLength ?? int.tryParse(uri.queryParameters['clen'] ?? '');
    if (size == null) {
      try {
        final response = await _dio.get<void>(
          url,
          options: Options(
            headers: {...stream.headers, 'Range': 'bytes=0-0'},
            responseType: ResponseType.stream,
          ),
        );
        // "Content-Range: bytes 0-0/1234567"
        final range = response.headers.value('content-range');
        size = int.tryParse(range?.split('/').last ?? '');
      } catch (error) {
        debugPrint('=== DESCARGAS: no se pudo calcular el tamaño de $videoId: $error ===');
      }
    }
    debugPrint('=== DESCARGAS: $videoId por ${stream.path} ===');
    return EstimateOutcome.ok(DownloadEstimate(
      url: url,
      extension: stream.extension,
      sizeBytes: size,
      headers: stream.headers,
      path: stream.path,
      chunkBytes: stream.chunkSize,
      stream: stream,
    ));
  }

  /// YouTube cortó la descarga con esta forma: se anota en la Salud del Extractor.
  Future<void> refused(DownloadEstimate estimate) async {
    final stream = estimate.stream;
    if (stream != null) await resolver.refused(stream);
  }

  /// Baja el audio a `<videoId>.<ext>.part` y lo renombra al terminar.
  /// Si ya existe un `.part` (descarga cortada), sigue desde donde quedó.
  /// Devuelve el nombre del archivo final y su tamaño.
  Future<(String, int)> download(
    String videoId,
    DownloadEstimate estimate, {
    required CancelToken cancelToken,
    required void Function(int received, int? total) onProgress,
  }) async {
    final fileName = '$videoId.${estimate.extension}';
    final finalPath = await _repository.pathFor(fileName);
    final part = File('$finalPath.part');
    final total = estimate.sizeBytes;

    // Un .part solo se continúa si es del mismo archivo (otra forma puede dar otro tamaño):
    // si no, se empieza de cero en vez de pegar dos archivos distintos.
    final sizeMark = File('$finalPath.part.size');
    if (await part.exists()) {
      final marked = await sizeMark.exists() ? int.tryParse(await sizeMark.readAsString()) : null;
      final partLength = await part.length();
      // Sin marca (descargas de versiones anteriores) se continúa si no se pasa del tamaño.
      if (total == null || (marked != null && marked != total) || partLength > total) {
        debugPrint('=== DESCARGAS: el parcial de $videoId es de otro archivo; se empieza de cero ===');
        await part.delete();
      }
    }
    if (total != null) await sizeMark.writeAsString('$total');

    var received = await part.exists() ? await part.length() : 0;
    final chunk = estimate.chunkBytes == null || estimate.chunkBytes! <= 0
        ? _chunkBytes
        : estimate.chunkBytes!.clamp(256 * 1024, _chunkBytes);
    final sink = part.openWrite(mode: FileMode.append);

    try {
      while (total == null || received < total) {
        final end = total == null
            ? received + chunk - 1
            : (received + chunk - 1).clamp(0, total - 1);
        final Response<List<int>> response;
        try {
          response = await _dio.get<List<int>>(
            estimate.url,
            cancelToken: cancelToken,
            options: Options(
              headers: {...estimate.headers, 'Range': 'bytes=$received-$end'},
              responseType: ResponseType.bytes,
              validateStatus: (status) => status == 200 || status == 206 || status == 416,
            ),
          );
        } on DioException catch (error) {
          final status = error.response?.statusCode;
          if (status == 403 || status == 410) throw const ExpiredUrlException();
          rethrow;
        }

        final bytes = response.data ?? const [];
        // 416 = pedimos más allá del final: con tamaño desconocido, terminó.
        if (response.statusCode == 416 || bytes.isEmpty) break;
        sink.add(bytes);
        await sink.flush();
        received += bytes.length;
        onProgress(received, total);

        // Un 200 trae el archivo entero de una vez.
        if (response.statusCode == 200) break;
      }
    } finally {
      await sink.close();
    }

    if (total != null && received < total) throw const ExpiredUrlException();
    await part.rename(finalPath);
    if (await sizeMark.exists()) await sizeMark.delete();
    return (fileName, received);
  }

  /// Guarda la portada junto al audio, para mostrarla sin conexión.
  /// Si falla no pasa nada: la descarga vale igual.
  Future<String?> downloadThumbnail(String videoId, String? url) async {
    if (url == null) return null;
    try {
      final fileName = '$videoId.jpg';
      await _dio.download(url, await _repository.pathFor(fileName));
      return fileName;
    } catch (error) {
      debugPrint('=== DESCARGAS: no se pudo bajar la portada de $videoId: $error ===');
      return null;
    }
  }
}
