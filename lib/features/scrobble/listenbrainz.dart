// Scrobbling a ListenBrainz (https://listenbrainz.org), opcional y apagado de fábrica. Lo conecta el
// usuario con SU token (Configuración de ListenBrainz → «User token»). El token se guarda cifrado,
// solo en este dispositivo, y solo se manda a ListenBrainz. Kiji no guarda nada fuera del
// dispositivo: cada escucha va directo del dispositivo a ListenBrainz.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/track.dart';
import '../../version.dart';

/// Nombre del secreto donde va el token (cifrado con el Keystore o DPAPI).
const listenBrainzSecret = 'listenbrainz_token'; // l10n-ignore

/// ¿Cuándo cuenta como escuchada? Las reglas de ListenBrainz (y Last.fm): la mitad de la canción o
/// 4 minutos, lo que llegue primero. Las de menos de 30 s no se cuentan.
bool shouldScrobble({required Duration played, required Duration length}) {
  if (length < const Duration(seconds: 30)) return false;
  final half = Duration(milliseconds: length.inMilliseconds ~/ 2);
  final needed = half < const Duration(minutes: 4) ? half : const Duration(minutes: 4);
  return played >= needed;
}

/// Lo que se manda de una escucha: artista, título, álbum (si hay), duración y cuándo empezó.
Map<String, Object?> listenPayload(Track track, DateTime startedAt) => {
  'listened_at': startedAt.toUtc().millisecondsSinceEpoch ~/ 1000,
  'track_metadata': {
    'artist_name': track.artist,
    'track_name': track.title,
    if (track.album case final album? when album.isNotEmpty) 'release_name': album,
    'additional_info': {
      if (track.durationMs > 0) 'duration_ms': track.durationMs,
      'media_player': 'Kiji Player', // l10n-ignore
      'submission_client': 'Kiji Player', // l10n-ignore
      'submission_client_version': kijiVersion,
    },
  },
};

class ListenBrainzClient {
  ListenBrainzClient({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.listenbrainz.org/1', // l10n-ignore
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  Options _auth(String token) => Options(headers: {'Authorization': 'Token $token'}); // l10n-ignore

  /// El nombre de usuario si el token sirve; null si no.
  Future<String?> validate(String token) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/validate-token', options: _auth(token));
      final data = response.data;
      return data?['valid'] == true ? data!['user_name'] as String? : null;
    } catch (error) {
      debugPrint('=== LISTENBRAINZ: no se pudo comprobar el token (${error.runtimeType}) ===');
      return null;
    }
  }

  /// Manda una escucha. Devuelve si ListenBrainz la aceptó.
  Future<bool> submit(String token, Track track, DateTime startedAt) async {
    try {
      await _dio.post<Object>(
        '/submit-listens',
        options: _auth(token),
        data: {
          'listen_type': 'single', // l10n-ignore
          'payload': [listenPayload(track, startedAt)],
        },
      );
      return true;
    } catch (error) {
      debugPrint('=== LISTENBRAINZ: no se pudo mandar la escucha (${error.runtimeType}) ===');
      return false;
    }
  }
}
