// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../playback/DownloadUtil.kt y
// ExoDownloadService.kt (descarga a almacenamiento privado, reanudable).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../yt_music/data/ytm_client.dart';
import 'downloads_repository.dart';

/// Lo que se sabe de una descarga antes de empezarla: la URL de audio ya
/// resuelta y, si YouTube lo informa, cuánto va a ocupar.
class DownloadEstimate {
  const DownloadEstimate({required this.url, required this.extension, this.sizeBytes});

  final String url;
  final String extension;
  final int? sizeBytes;
}

/// La URL de audio venció o fue rechazada (403/410): hay que resolverla de nuevo.
class ExpiredUrlException implements Exception {
  const ExpiredUrlException();
}

class DownloadService {
  DownloadService(this._repository, {YtMusicClient? ytClient, Dio? dio})
      : _ytClient = ytClient ?? YtMusicClient(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ));

  final DownloadsRepository _repository;
  final YtMusicClient _ytClient;
  final Dio _dio;

  /// Partes de 4 MiB: YouTube limita la velocidad de los pedidos grandes de
  /// una sola vez, y además cada parte terminada queda guardada si se corta.
  static const _chunkBytes = 4 * 1024 * 1024;

  /// Resuelve la URL de audio y calcula el tamaño. Devuelve null si YouTube
  /// no entrega audio para este video.
  Future<DownloadEstimate?> estimate(String videoId) async {
    final url = await _ytClient.getAudioStreamUrl(videoId);
    if (url == null) return null;

    final uri = Uri.parse(url);
    final mime = uri.queryParameters['mime'] ?? '';
    final extension = mime.contains('webm') ? 'webm' : 'm4a';

    var size = int.tryParse(uri.queryParameters['clen'] ?? '');
    if (size == null) {
      try {
        final response = await _dio.get<void>(
          url,
          options: Options(
            headers: {'Range': 'bytes=0-0'},
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
    return DownloadEstimate(url: url, extension: extension, sizeBytes: size);
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

    var received = await part.exists() ? await part.length() : 0;
    final total = estimate.sizeBytes;
    final sink = part.openWrite(mode: FileMode.append);

    try {
      while (total == null || received < total) {
        final end = total == null
            ? received + _chunkBytes - 1
            : (received + _chunkBytes - 1).clamp(0, total - 1);
        final Response<List<int>> response;
        try {
          response = await _dio.get<List<int>>(
            estimate.url,
            cancelToken: cancelToken,
            options: Options(
              headers: {'Range': 'bytes=$received-$end'},
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

    await part.rename(finalPath);
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
