import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
  });

  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final String? album;
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

  final Dio _dio;

  /// Clave pública embebida en el frontend web de YouTube Music. No es
  /// secreta: viaja en el HTML público del sitio y la reutilizan
  /// prácticamente todos los clientes FOSS de YTM.
  static const _apiKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL47NlEVNIeM';

  /// Clave asociada al cliente oficial de Android de YouTube. Tan pública
  /// como la de arriba — la usan NewPipe, yt-dlp, y prácticamente todo
  /// extractor FOSS, porque el cliente Android suele devolver URLs de
  /// audio directas (sin cifrar), evitando la necesidad de descifrado.
  static const _androidApiKey = 'AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w';

  Map<String, dynamic> get _androidContext => {
        'context': {
          'client': {
            'clientName': 'ANDROID',
            'clientVersion': '19.09.37',
            'androidSdkVersion': 30,
            'hl': 'es',
            'gl': 'US',
          },
        },
      };

  Map<String, dynamic> get _context => {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20241201.01.00',
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

    void walk(dynamic node) {
      if (node is Map) {
        final renderer = node['musicResponsiveListItemRenderer'];
        if (renderer is Map) {
          final parsed = _parseItem(Map<String, dynamic>.from(renderer));
          if (parsed != null && seenVideoIds.add(parsed.videoId)) {
            results.add(parsed);
          }
        }
        for (final value in node.values) {
          walk(value);
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
    }

    try {
      walk(data['contents']);
    } catch (error, stackTrace) {
      debugPrint('=== YTM parse: EXCEPCIÓN: $error ===');
      debugPrint('$stackTrace');
    }

    return results;
  }

  YtMusicSearchResult? _parseItem(Map<String, dynamic> renderer) {
    try {
      final videoId = _findVideoId(renderer);
      if (videoId == null) return null;

      final flexColumns = renderer['flexColumns'] as List?;
      final title = _extractText(flexColumns, 0);
      final subtitle = _extractText(flexColumns, 1);

      final thumbnails = ((renderer['thumbnail'] as Map?)?['musicThumbnailRenderer']
              as Map?)?['thumbnail']?['thumbnails'] as List?;
      final thumbnailUrl =
          thumbnails != null && thumbnails.isNotEmpty ? thumbnails.last['url'] as String? : null;

      return YtMusicSearchResult(
        videoId: videoId,
        title: (title == null || title.isEmpty) ? 'Sin título' : title,
        artist: (subtitle == null || subtitle.isEmpty) ? 'Artista desconocido' : subtitle,
        thumbnailUrl: thumbnailUrl,
      );
    } catch (_) {
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
    if (flexColumns == null || index >= flexColumns.length) return null;
    final column = flexColumns[index] as Map?;
    final runs =
        (column?['musicResponsiveListItemFlexColumnRenderer'] as Map?)?['text']?['runs'] as List?;
    if (runs == null || runs.isEmpty) return null;
    return runs.map((run) => (run as Map)['text']).join();
  }

  /// Resuelve la URL de audio directo para [videoId].
  ///
  /// Primero prueba con el cliente "Android" de YouTube, que normalmente
  /// entrega URLs de audio ya listas (sin cifrar) — el mismo truco que usan
  /// NewPipe y otros extractores para no necesitar descifrado casi nunca.
  /// Si eso no trae nada, recién ahí recurre al cliente Web + descifrado
  /// con JavaScript real como respaldo.
  Future<String?> getAudioStreamUrl(String videoId) async {
    final signatureTimestamp = await _cipherSolver.getSignatureTimestamp(videoId);

    final androidUrl = await _tryGetStreamUrl(
      videoId,
      apiKey: _androidApiKey,
      context: _androidContext,
      clientLabel: 'ANDROID',
      // El cliente Android usa un host de API distinto al de la web.
      endpoint: 'https://youtubei.googleapis.com/youtubei/v1/player',
      signatureTimestamp: signatureTimestamp,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip',
        'X-YouTube-Client-Name': '3',
        'X-YouTube-Client-Version': '19.09.37',
      },
    );
    if (androidUrl != null) return androidUrl;

    debugPrint('=== YTM stream: cliente ANDROID no dio resultado, probando cliente WEB ===');
    return _tryGetStreamUrl(
      videoId,
      apiKey: _apiKey,
      context: _context,
      clientLabel: 'WEB_REMIX',
      endpoint: 'https://www.youtube.com/youtubei/v1/player',
      signatureTimestamp: signatureTimestamp,
      headers: {
        'Content-Type': 'application/json',
        'Origin': 'https://music.youtube.com',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'X-YouTube-Client-Name': '67',
        'X-YouTube-Client-Version': '1.20241201.01.00',
      },
    );
  }

  Future<String?> _tryGetStreamUrl(
    String videoId, {
    required String apiKey,
    required Map<String, dynamic> context,
    required String clientLabel,
    required String endpoint,
    required Map<String, String> headers,
    int? signatureTimestamp,
  }) async {
    final Map<String, dynamic>? data;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        queryParameters: {'key': apiKey},
        // Headers propios de este pedido — pisan por completo los que trae
        // el Dio compartido (evita mezclar, por ejemplo, "soy Android" en el
        // cuerpo con encabezados de navegador de escritorio, que es lo que
        // causaba el 400).
        options: Options(headers: headers),
        data: {
          ...context,
          'videoId': videoId,
          if (signatureTimestamp != null)
            'playbackContext': {
              'contentPlaybackContext': {
                'signatureTimestamp': signatureTimestamp,
              },
            },
        },
      );
      data = response.data;
    } catch (error) {
      // Importante: si este cliente falla (400, timeout, lo que sea), NO
      // dejamos que la excepción se escape hacia arriba — así el llamador
      // todavía puede intentar con el otro cliente como respaldo.
      String detail = '$error';
      if (error is DioException && error.response?.data != null) {
        detail = '$detail\n>>> Respuesta del servidor: ${error.response?.data}';
      }
      debugPrint('=== YTM stream [$clientLabel]: falló el pedido: $detail ===');
      return null;
    }

    if (data == null) return null;

    final playabilityStatus = data['playabilityStatus'] as Map?;
    debugPrint(
      '=== YTM stream [$clientLabel]: playabilityStatus = '
      '${playabilityStatus?['status']} (${playabilityStatus?['reason']}) ===',
    );

    final formats = (data['streamingData']?['adaptiveFormats'] as List?) ?? const [];

    final audioFormats = formats.where((format) {
      final mimeType = (format as Map)['mimeType'] as String? ?? '';
      return mimeType.startsWith('audio/');
    }).toList()
      ..sort((a, b) {
        final bitrateA = (a as Map)['bitrate'] as int? ?? 0;
        final bitrateB = (b as Map)['bitrate'] as int? ?? 0;
        return bitrateB.compareTo(bitrateA);
      });

    debugPrint('=== YTM stream [$clientLabel]: ${audioFormats.length} formatos de audio disponibles ===');

    for (final format in audioFormats) {
      final map = format as Map;

      // Caso simple: ya viene con URL usable.
      final directUrl = map['url'] as String?;
      if (directUrl != null) {
        debugPrint('=== YTM stream [$clientLabel]: formato sin cifrar, aplicando fix de "n" ===');
        return _applyNFix(videoId, directUrl);
      }

      // Caso cifrado: hay que descifrar la firma con el motor JS.
      final cipher = map['signatureCipher'] as String? ?? map['cipher'] as String?;
      if (cipher != null) {
        final resolved = await _resolveCipheredUrl(videoId, cipher);
        if (resolved != null) return resolved;
        debugPrint('=== YTM stream [$clientLabel]: no se pudo resolver este formato cifrado, probando el siguiente ===');
      }
    }

    return null;
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
