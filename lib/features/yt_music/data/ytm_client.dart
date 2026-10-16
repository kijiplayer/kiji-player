// Adaptado de Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos originales: innertube/.../models/YouTubeClient.kt (clientes VISIONOS y ANDROID_VR)
// y app/src/main/kotlin/.../utils/YTPlayerUtils.kt (orden de clientes y visitorData).

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/subtitle_parser.dart';
import 'yt_cipher_solver.dart';

/// Resultado crudo de una búsqueda en YouTube Music, antes de mapearlo
/// a nuestro modelo de dominio [Track].
class YtMusicSearchResult {
  const YtMusicSearchResult({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.album,
    this.durationMs,
  });

  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final String? album;
  final int? durationMs;
}

/// Cliente para el endpoint interno de YouTube Music (InnerTube), el mismo
/// que usa la web pública de music.youtube.com. No requiere login ni
/// cookies: la búsqueda y la reproducción son 100% anónimas.
///
/// NOTA HONESTA: esto es ingeniería inversa (igual que Metrolist, Namida,
/// NewPipe, etc.), no una API oficial ni documentada por Google. Puede
/// requerir ajustes si YouTube cambia la forma de su respuesta.
class YtMusicClient {
  YtMusicClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://music.youtube.com/youtubei/v1',
            headers: {
              'Content-Type': 'application/json',
              'Origin': 'https://music.youtube.com',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ),
        _cipherSolver = YtCipherSolver(Dio());

  final YtCipherSolver _cipherSolver;

  /// Dio limpio para pedir el audio: sin headers heredados del cliente de
  /// búsqueda (cada "cliente" de YouTube manda los suyos propios).
  final Dio _playerDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  final Dio _dio;

  /// Clave pública embebida en el frontend web de YouTube Music. No es
  /// secreta: viaja en el HTML público del sitio y la reutilizan
  /// prácticamente todos los clientes FOSS de YTM.
  static const _apiKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL47NlEVNIeM';

  Map<String, dynamic> get _context => {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20260213.01.00',
            'hl': 'es',
            'gl': 'US',
          },
        },
      };

  /// Busca canciones de forma anónima. Devuelve una lista vacía si no hay
  /// resultados o si la respuesta no se pudo interpretar.
  Future<List<YtMusicSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return const [];

    debugPrint('=== YTM search: enviando query "$query" ===');

    final response = await _dio.post<Map<String, dynamic>>(
      '/search',
      queryParameters: {'key': _apiKey},
      data: {
        ..._context,
        'query': query,
      },
    );

    debugPrint('=== YTM search: status ${response.statusCode} ===');

    final data = response.data;
    if (data == null) {
      debugPrint('=== YTM search: response.data es null ===');
      return const [];
    }

    debugPrint('=== YTM search: claves top-level: ${data.keys.toList()} ===');

    final results = _parseResults(data);
    debugPrint('=== YTM search: ${results.length} resultados parseados ===');

    return results;
  }

  /// Recorre recursivamente [data['contents']] buscando cualquier nodo
  /// `musicResponsiveListItemRenderer`, sin importar en qué tipo de
  /// contenedor esté (`musicShelfRenderer`, `musicCardShelfRenderer`, o
  /// cualquier otro que YouTube use). Esto lo hace resistente a que
  /// YouTube cambie qué tipo de "estante" usa para mostrar resultados —
  /// en vez de tener que enumerar cada contenedor posible a mano.
  List<YtMusicSearchResult> _parseResults(Map<String, dynamic> data) {
    final results = <YtMusicSearchResult>[];
    final seenVideoIds = <String>{};

    // [cardArtist]: dentro de la tarjeta del resultado principal de un
    // artista, las canciones no repiten el artista en su subtítulo.
    void walk(dynamic node, String? cardArtist) {
      if (node is Map) {
        final renderer = node['musicResponsiveListItemRenderer'];
        if (renderer is Map) {
          final parsed =
              _parseItem(Map<String, dynamic>.from(renderer), fallbackArtist: cardArtist);
          if (parsed != null && seenVideoIds.add(parsed.videoId)) {
            results.add(parsed);
          }
        }
        final card = node['musicCardShelfRenderer'];
        final artist = card is Map ? _cardArtist(card) ?? cardArtist : cardArtist;
        for (final value in node.values) {
          walk(value, artist);
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item, cardArtist);
        }
      }
    }

    try {
      walk(data['contents'], null);
    } catch (error, stackTrace) {
      debugPrint('=== YTM parse: EXCEPCIÓN: $error ===');
      debugPrint('$stackTrace');
    }

    return results;
  }

  /// Nombre del artista si [card] es la tarjeta de un artista.
  String? _cardArtist(Map card) {
    final runs = (card['title'] as Map?)?['runs'] as List?;
    final run = runs?.whereType<Map>().firstOrNull;
    final pageType = (((run?['navigationEndpoint'] as Map?)?['browseEndpoint'] as Map?)?[
            'browseEndpointContextSupportedConfigs'] as Map?)?['browseEndpointContextMusicConfig']
        ?['pageType'];
    return pageType == 'MUSIC_PAGE_TYPE_ARTIST' ? run!['text'] as String? : null;
  }

  YtMusicSearchResult? _parseItem(Map<String, dynamic> renderer, {String? fallbackArtist}) {
    try {
      final videoId = _findVideoId(renderer);
      if (videoId == null) return null;

      final flexColumns = renderer['flexColumns'] as List?;
      final title = _extractText(flexColumns, 0);
      final subtitleRuns = _extractRuns(flexColumns, 1);
      final subtitle = subtitleRuns == null ? null : parseSubtitleRuns(subtitleRuns);

      final thumbnails = ((renderer['thumbnail'] as Map?)?['musicThumbnailRenderer']
              as Map?)?['thumbnail']?['thumbnails'] as List?;
      final thumbnailUrl =
          thumbnails != null && thumbnails.isNotEmpty ? thumbnails.last['url'] as String? : null;

      return YtMusicSearchResult(
        videoId: videoId,
        title: (title == null || title.isEmpty) ? 'Sin título' : title,
        artist: subtitle?.artist ?? fallbackArtist ?? unknownArtist,
        album: subtitle?.album,
        durationMs: subtitle?.durationMs,
        thumbnailUrl: thumbnailUrl,
      );
    } catch (error) {
      debugPrint('=== YTM parse: item descartado: $error ===');
      return null;
    }
  }

  String? _findVideoId(Map<String, dynamic> renderer) {
    final overlay = renderer['overlay'] as Map?;
    final overlayRenderer = overlay?['musicItemThumbnailOverlayRenderer'] as Map?;
    final content = overlayRenderer?['content'] as Map?;
    final playButtonRenderer = content?['musicPlayButtonRenderer'] as Map?;
    final playNavigationEndpoint = playButtonRenderer?['playNavigationEndpoint'] as Map?;
    final watchEndpoint = playNavigationEndpoint?['watchEndpoint'] as Map?;
    final overlayVideoId = watchEndpoint?['videoId'] as String?;

    if (overlayVideoId != null) return overlayVideoId;

    return (renderer['playlistItemData'] as Map?)?['videoId'] as String?;
  }

  String? _extractText(List? flexColumns, int index) {
    return _extractRuns(flexColumns, index)?.map((run) => (run as Map)['text']).join();
  }

  List<dynamic>? _extractRuns(List? flexColumns, int index) {
    if (flexColumns == null || index >= flexColumns.length) return null;
    final column = flexColumns[index] as Map?;
    final runs =
        (column?['musicResponsiveListItemFlexColumnRenderer'] as Map?)?['text']?['runs'] as List?;
    if (runs == null || runs.isEmpty) return null;
    return runs;
  }

  // ---------------------------------------------------------------------
  // Reproducción: la receta que usa Echo Music / Metrolist (probada en
  // producción). Los clientes "VISIONOS" y "ANDROID_VR 1.65.10" devuelven
  // URLs de audio DIRECTAS (sin firma cifrada, sin tocar JavaScript), pero
  // exigen mandar un `visitorData` válido. El descifrado con JS queda solo
  // como último respaldo.
  // ---------------------------------------------------------------------

  static const _webUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/18.0 Safari/605.1.15';

  static const _playerClients = <_PlayerClient>[
    _PlayerClient(
      label: 'VISIONOS',
      name: 'VISIONOS',
      id: '101',
      version: '0.1',
      userAgent: _webUserAgent,
      osName: 'visionOS',
      osVersion: '1.3.21O771',
      deviceMake: 'Apple',
      deviceModel: 'RealityDevice14,1',
    ),
    _PlayerClient(
      label: 'ANDROID_VR',
      name: 'ANDROID_VR',
      id: '28',
      version: '1.65.10',
      userAgent: 'com.google.android.apps.youtube.vr.oculus/1.65.10 '
          '(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      osName: 'Android',
      osVersion: '12L',
      deviceMake: 'Oculus',
      deviceModel: 'Quest 3',
      androidSdkVersion: 32,
    ),
  ];

  String? _visitorData;

  /// Pide un `visitorData` (identificador anónimo de visitante) a la web de
  /// YouTube Music. Es público y no identifica a nadie: es lo que cualquier
  /// navegador recibe al abrir music.youtube.com por primera vez.
  Future<String?> _getVisitorData() async {
    final cached = _visitorData;
    if (cached != null) return cached;

    try {
      final response = await Dio().get<String>(
        'https://music.youtube.com/sw.js_data',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'User-Agent': _webUserAgent},
        ),
      );

      final body = response.data ?? '';
      final start = body.indexOf('[');
      if (start == -1) {
        debugPrint('=== YTM visitorData: respuesta inesperada ===');
        return null;
      }

      final decoded = jsonDecode(body.substring(start));
      final candidate = RegExp(r'^Cg[ts]');

      String? found;
      void walk(dynamic node) {
        if (found != null) return;
        if (node is String) {
          if (candidate.hasMatch(node) && node.length > 20) found = node;
        } else if (node is List) {
          node.forEach(walk);
        } else if (node is Map) {
          node.values.forEach(walk);
        }
      }

      walk(decoded);
      debugPrint('=== YTM visitorData: ${found == null ? "NO encontrado" : "obtenido OK"} ===');
      _visitorData = found;
      return found;
    } catch (error) {
      debugPrint('=== YTM visitorData: falló: $error ===');
      return null;
    }
  }

  /// Resuelve una URL de audio reproducible para [videoId].
  /// Orden: VISIONOS -> ANDROID_VR -> (último respaldo) WEB + descifrado JS.
  Future<String?> getAudioStreamUrl(String videoId) async {
    final visitorData = await _getVisitorData();

    if (visitorData != null) {
      for (final client in _playerClients) {
        final url = await _tryDirectClient(videoId, client, visitorData);
        if (url != null) return url;
      }
    }

    debugPrint('=== YTM stream: clientes directos sin resultado, probando WEB + descifrado ===');
    return _tryWebWithCipher(videoId, visitorData);
  }

  Future<String?> _tryDirectClient(
    String videoId,
    _PlayerClient client,
    String visitorData,
  ) async {
    final Map<String, dynamic>? data;
    try {
      final response = await _playerDio.post<Map<String, dynamic>>(
        'https://music.youtube.com/youtubei/v1/player',
        queryParameters: {'prettyPrint': 'false'},
        options: Options(headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Format-Version': '1',
          'X-YouTube-Client-Name': client.id,
          'X-YouTube-Client-Version': client.version,
          'X-Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/',
          'X-Goog-Visitor-Id': visitorData,
          'User-Agent': client.userAgent,
        }),
        data: {
          'context': {
            'client': {
              'clientName': client.name,
              'clientVersion': client.version,
              'osName': client.osName,
              'osVersion': client.osVersion,
              'deviceMake': client.deviceMake,
              'deviceModel': client.deviceModel,
              if (client.androidSdkVersion != null)
                'androidSdkVersion': client.androidSdkVersion,
              'hl': 'es',
              'gl': 'US',
              'visitorData': visitorData,
            },
          },
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
        },
      );
      data = response.data;
    } catch (error) {
      String detail = '$error';
      if (error is DioException && error.response?.data != null) {
        detail = '$detail\n>>> Respuesta del servidor: ${error.response?.data}';
      }
      debugPrint('=== YTM stream [${client.label}]: falló el pedido: $detail ===');
      return null;
    }

    if (data == null) return null;

    final playability = data['playabilityStatus'] as Map?;
    debugPrint(
      '=== YTM stream [${client.label}]: playabilityStatus = '
      '${playability?['status']} (${playability?['reason']}) ===',
    );

    final audio = _audioFormats(data);
    debugPrint('=== YTM stream [${client.label}]: ${audio.length} formatos de audio ===');

    for (final format in audio) {
      final url = format['url'] as String?;
      if (url != null) {
        debugPrint('=== YTM stream [${client.label}]: URL directa lista ===');
        return url;
      }
    }
    return null;
  }

  /// Último recurso: cliente WEB_REMIX + descifrado de firma con JS real.
  Future<String?> _tryWebWithCipher(String videoId, String? visitorData) async {
    final signatureTimestamp = await _cipherSolver.getSignatureTimestamp(videoId);

    final Map<String, dynamic>? data;
    try {
      final response = await _playerDio.post<Map<String, dynamic>>(
        'https://music.youtube.com/youtubei/v1/player',
        queryParameters: {'prettyPrint': 'false'},
        options: Options(headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Format-Version': '1',
          'X-YouTube-Client-Name': '67',
          'X-YouTube-Client-Version': '1.20260213.01.00',
          'X-Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/',
          'X-Goog-Visitor-Id': ?visitorData,
          'User-Agent': _webUserAgent,
        }),
        data: {
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20260213.01.00',
              'hl': 'es',
              'gl': 'US',
              'visitorData': ?visitorData,
            },
          },
          'videoId': videoId,
          if (signatureTimestamp != null)
            'playbackContext': {
              'contentPlaybackContext': {'signatureTimestamp': signatureTimestamp},
            },
        },
      );
      data = response.data;
    } catch (error) {
      debugPrint('=== YTM stream [WEB_REMIX]: falló el pedido: $error ===');
      return null;
    }

    if (data == null) return null;

    final playability = data['playabilityStatus'] as Map?;
    debugPrint(
      '=== YTM stream [WEB_REMIX]: playabilityStatus = '
      '${playability?['status']} (${playability?['reason']}) ===',
    );

    for (final format in _audioFormats(data)) {
      final directUrl = format['url'] as String?;
      if (directUrl != null) return _applyNFix(videoId, directUrl);

      final cipher = format['signatureCipher'] as String? ?? format['cipher'] as String?;
      if (cipher != null) {
        final resolved = await _resolveCipheredUrl(videoId, cipher);
        if (resolved != null) return resolved;
      }
    }
    return null;
  }

  /// Formatos de audio de `streamingData`, de mayor a menor bitrate.
  List<Map> _audioFormats(Map<String, dynamic> data) {
    final formats = (data['streamingData']?['adaptiveFormats'] as List?) ?? const [];
    return formats
        .whereType<Map>()
        .where((f) => ((f['mimeType'] as String?) ?? '').startsWith('audio/'))
        .toList()
      ..sort((a, b) =>
          ((b['bitrate'] as int?) ?? 0).compareTo((a['bitrate'] as int?) ?? 0));
  }

  /// Parsea un `signatureCipher` (algo como `s=XXX&sp=sig&url=YYY`),
  /// descifra la firma, y arma la URL final reproducible.
  Future<String?> _resolveCipheredUrl(String videoId, String cipher) async {
    final params = Uri.splitQueryString(cipher);
    final baseUrl = params['url'];
    final signature = params['s'];
    final signatureParamName = params['sp'] ?? 'signature';

    if (baseUrl == null || signature == null) {
      debugPrint('=== YTM stream: signatureCipher sin url o sin "s" ===');
      return null;
    }

    final deciphered = await _cipherSolver.decipherSignature(videoId, signature);
    if (deciphered == null) {
      debugPrint('=== YTM stream: no se pudo descifrar la firma ===');
      return null;
    }

    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        ...Uri.parse(baseUrl).queryParameters,
        signatureParamName: deciphered,
      },
    );

    return _applyNFix(videoId, uri.toString());
  }

  /// Reemplaza el parámetro "n" de la URL por su versión transformada
  /// (evita que YouTube limite la velocidad de la descarga a casi cero).
  Future<String> _applyNFix(String videoId, String url) async {
    final uri = Uri.parse(url);
    final n = uri.queryParameters['n'];
    if (n == null) return url;

    final transformed = await _cipherSolver.transformN(videoId, n);
    final newUri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'n': transformed,
      },
    );
    return newUri.toString();
  }
}

/// Datos de un "cliente" de YouTube (quién dice ser la app que pide el audio).
class _PlayerClient {
  const _PlayerClient({
    required this.label,
    required this.name,
    required this.id,
    required this.version,
    required this.userAgent,
    required this.osName,
    required this.osVersion,
    required this.deviceMake,
    required this.deviceModel,
    this.androidSdkVersion,
  });

  final String label;
  final String name;
  final String id;
  final String version;
  final String userAgent;
  final String osName;
  final String osVersion;
  final String deviceMake;
  final String deviceModel;
  final int? androidSdkVersion;
}
