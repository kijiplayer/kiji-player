// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../playback/ChunkedDataSource.kt (pedir el audio
// en rangos acotados y renovar la URL cuando googlevideo la rechaza). Código propio en Dart.

// StreamAudioSource es experimental en just_audio (igual que LockCachingAudioSource, que se usaba
// antes); si cambia, el reproductor reintenta con la URL directa.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../extractor/domain/resolved_stream.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Pide otra URL para la misma canción (después de un rechazo). null si no hay.
typedef StreamRefresher = Future<ResolvedStream?> Function(ResolvedStream refused);

/// Fuente de audio de YouTube para just_audio:
/// - pide el archivo **por pedazos** con `Range` (algunas formas solo entregan rangos acotados y
///   cortan en 1 MiB si se pide entero);
/// - si googlevideo rechaza la URL (403/410) a mitad de la canción, pide otra y **sigue desde el
///   mismo byte**, sin cortar la reproducción;
/// - si la lectura empezó en 0 y llegó al final, guarda la canción en [cacheFile] (también en
///   calidad baja, decisión del proyecto).
class ChunkedYtSource extends StreamAudioSource {
  ChunkedYtSource({
    required ResolvedStream stream,
    required this.refresh,
    this.cacheFile,
    Dio? dio,
    this.maxRefreshes = 2,
  }) : _stream = stream,
       _dio =
           dio ??
           Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30))),
       super(tag: stream.videoId);

  /// Tamaño de pedazo si la forma no pide uno propio.
  static const defaultChunk = 2 * 1024 * 1024;

  /// Canciones que se están guardando ahora (dos escritores a la vez corrompen el archivo).
  static final Set<String> _writing = {};

  final StreamRefresher refresh;
  final File? cacheFile;
  final int maxRefreshes;
  final Dio _dio;
  ResolvedStream _stream;
  int? _length;

  /// El audio que se está usando ahora (cambia si hubo que renovar la URL).
  ResolvedStream get current => _stream;

  int get _chunk => _stream.chunkSize != null && _stream.chunkSize! > 0 ? _stream.chunkSize! : defaultChunk;

  String get _contentType {
    final mime = (_stream.mime ?? '').split(';').first.trim();
    if (mime.isNotEmpty) return mime;
    return _stream.extension == 'webm' ? 'audio/webm' : 'audio/mp4';
  }

  Future<int> _totalLength() async {
    final known = _length ?? _stream.contentLength;
    if (known != null && known > 0) return _length = known;
    // Un pedido de 1 byte devuelve el tamaño total en Content-Range ("bytes 0-0/12345").
    final response = await _get(0, 0);
    final range = response.headers.value('content-range') ?? '';
    final total = int.tryParse(range.split('/').last);
    if (total == null) throw HttpException(tx.youtubeNoDijoElTamanoDel2);
    return _length = total;
  }

  Future<Response<List<int>>> _get(int from, int to) => _dio.get<List<int>>(
    _stream.url,
    options: Options(
      responseType: ResponseType.bytes,
      headers: {..._stream.headers, 'Range': 'bytes=$from-$to'},
      validateStatus: (_) => true,
    ),
  );

  /// Un pedazo [from]..[to] (inclusive), renovando la URL si la rechazan.
  @visibleForTesting
  Future<List<int>> fetchChunk(int from, int to) async {
    var refreshes = 0;
    while (true) {
      final response = await _get(from, to);
      final status = response.statusCode ?? 0;
      final data = response.data ?? const <int>[];
      if ((status == 206 || status == 200) && data.isNotEmpty) {
        // Un 200 trae el archivo desde el principio: se recorta lo que hace falta.
        if (status == 200 && from > 0) return data.sublist(min(from, data.length), min(to + 1, data.length));
        return data.length > to - from + 1 ? data.sublist(0, to - from + 1) : data;
      }
      if (refreshes >= maxRefreshes) {
        throw HttpException(tx.youtubeRechazoElAudioHttpY(status));
      }
      refreshes++;
      debugPrint('=== AUDIO: ${_stream.path} rechazada en el byte $from (HTTP $status); se pide otra URL ===');
      final next = await refresh(_stream);
      if (next == null) throw HttpException(tx.youtubeRechazoElAudioHttp(status));
      _stream = next;
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final total = await _totalLength();
    final from = (start ?? 0).clamp(0, total);
    final until = (end ?? total).clamp(from, total); // exclusivo
    final file = cacheFile;
    final write = from == 0 && until == total && file != null && _writing.add(_stream.videoId);
    final controller = StreamController<List<int>>();
    var cancelled = false;
    controller.onCancel = () => cancelled = true;

    Future<void> pump() async {
      IOSink? sink;
      final part = write ? File('${file.path}.part') : null;
      try {
        if (part != null) sink = part.openWrite();
        for (var pos = from; pos < until && !cancelled; pos += _chunk) {
          final chunk = await fetchChunk(pos, min(pos + _chunk, until) - 1);
          if (cancelled) break;
          controller.add(chunk);
          sink?.add(chunk);
        }
        await sink?.flush();
        await sink?.close();
        sink = null;
        if (part != null) {
          if (!cancelled && await part.length() == total) {
            await part.rename(file!.path);
            debugPrint('=== CACHE: ${_stream.videoId} guardada entera ===');
          } else if (await part.exists()) {
            await part.delete();
          }
        }
      } catch (error) {
        debugPrint('=== AUDIO: se cortó ${_stream.path}: $error ===');
        if (!controller.isClosed) controller.addError(error);
        await sink?.close();
        if (part != null && await part.exists()) await part.delete();
      } finally {
        if (write) _writing.remove(_stream.videoId);
        if (!controller.isClosed) await controller.close();
      }
    }

    unawaited(pump());
    return StreamAudioResponse(
      sourceLength: total,
      contentLength: until - from,
      offset: from,
      stream: controller.stream,
      contentType: _contentType,
    );
  }
}
