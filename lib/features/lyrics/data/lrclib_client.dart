// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: lyrics/LrcLibLyricsProvider.kt (búsqueda exacta y, si falla, por texto
// eligiendo la duración más parecida).

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/lyrics.dart';

/// No se pudo consultar (sin conexión o el servicio falló). Distinto de
/// "no hay letra": esto no se guarda en caché, se reintenta la próxima vez.
class LyricsUnavailableException implements Exception {
  const LyricsUnavailableException(this.reason);
  final String reason;
}

/// Cliente de LRCLIB (https://lrclib.net): letras libres, sin cuenta. Solo se
/// le envían el título, el artista, el álbum y la duración, y solo cuando el
/// usuario abre la letra.
class LrcLibClient {
  LrcLibClient({Dio? dio, String baseUrl = 'https://lrclib.net'})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              // LRCLIB pide que cada app se identifique.
              headers: {'User-Agent': 'Kiji Player 1.0.0 (software libre, GPL-3.0)'},
            ));

  final Dio _dio;

  /// Busca la letra. Devuelve [Lyrics.none] si LRCLIB no la tiene.
  Future<Lyrics> fetch({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    try {
      final exact = await _dio.get<Map<String, dynamic>>(
        '/api/get',
        queryParameters: {
          'track_name': title,
          'artist_name': artist,
          if (album != null && album.isNotEmpty) 'album_name': album,
          if (duration != null && duration > Duration.zero) 'duration': duration.inSeconds,
        },
        options: Options(validateStatus: (s) => s == 200 || s == 404),
      );
      if (exact.statusCode == 200 && exact.data != null) return _toLyrics(exact.data!);

      // Sin coincidencia exacta: búsqueda por texto, la de duración más parecida.
      final search = await _dio.get<List<dynamic>>(
        '/api/search',
        queryParameters: {'track_name': title, 'artist_name': artist},
      );
      final candidates = (search.data ?? const []).whereType<Map<String, dynamic>>().toList();
      if (candidates.isEmpty) return Lyrics.none;
      return _toLyrics(pickClosest(candidates, duration));
    } on DioException catch (error) {
      debugPrint('=== LETRAS: LRCLIB no respondió: $error ===');
      throw LyricsUnavailableException(
        error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout
            ? 'sin conexión'
            : 'el servicio de letras no respondió',
      );
    }
  }

  /// Entre varios resultados, el de duración más parecida (con letra
  /// sincronizada primero si empatan).
  @visibleForTesting
  static Map<String, dynamic> pickClosest(List<Map<String, dynamic>> candidates, Duration? duration) {
    double score(Map<String, dynamic> c) {
      final seconds = (c['duration'] as num?)?.toDouble();
      final diff = duration == null || seconds == null ? 0.0 : (seconds - duration.inSeconds).abs();
      final syncedBonus = (c['syncedLyrics'] as String?)?.isNotEmpty == true ? 0.0 : 0.5;
      return diff + syncedBonus;
    }

    return ([...candidates]..sort((a, b) => score(a).compareTo(score(b)))).first;
  }

  static Lyrics _toLyrics(Map<String, dynamic> json) {
    final synced = json['syncedLyrics'] as String?;
    return Lyrics(
      synced: synced == null ? const [] : parseLrc(synced),
      plain: json['plainLyrics'] as String?,
      instrumental: json['instrumental'] as bool? ?? false,
      source: LyricsSource.lrclib,
    );
  }
}
