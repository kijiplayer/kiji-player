// Adaptado de Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos originales: innertube/.../models/YouTubeClient.kt (clientes, ver yt_clients.dart)
// y app/src/main/kotlin/.../utils/YTPlayerUtils.kt (orden de respaldo, visitorData y la
// verificación de que el audio baje entero).

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/js_challenge_solver.dart';
import '../domain/subtitle_parser.dart';
import 'player_script.dart';
import 'po_token.dart';
import 'webview_ejs_solver.dart';
import 'ytm_browse_parser.dart';
import 'yt_clients.dart';
import '../../account/domain/yt_session.dart';
import '../../../utils/json_access.dart';

import 'package:kiji_player/l10n/l10n.dart';

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

/// URL de audio lista para reproducir, con el cliente de YouTube que la
/// entregó. El reproductor manda el mismo `User-Agent`
/// y, si falla a mitad de canción, reintenta excluyendo ese cliente.
class YtStream {
  const YtStream({
    required this.url,
    required this.client,
    required this.userAgent,
    this.isHls = false,
    this.contentLength,
  });

  /// Tamaño del archivo de audio, si se sabe.
  final int? contentLength;

  final String url;
  final String client;
  final String userAgent;

  /// Lista HLS (segmentos): se reproduce sin la caché de lo escuchado y no
  /// sirve para descargar.
  final bool isHls;
}

/// Cliente para el endpoint interno de YouTube Music (InnerTube), el mismo
/// que usa la web pública de music.youtube.com. No requiere login ni
/// cookies: la búsqueda y la reproducción son 100% anónimas.
///
/// NOTA HONESTA: esto es ingeniería inversa (igual que Metrolist, Namida,
/// NewPipe, etc.), no una API oficial ni documentada por Google. Puede
/// requerir ajustes si YouTube cambia la forma de su respuesta.
class YtMusicClient {
  YtMusicClient({JsChallengeSolver? solver, PlayerScriptSource? playerScripts, PoTokenProvider? poTokens})
    : _solver = solver ?? sharedSolver,
      _poTokens = poTokens ?? sharedPoTokens,
      _playerScripts = playerScripts ?? sharedPlayerScripts,
      _dio = Dio(
        BaseOptions(
          baseUrl: 'https://music.youtube.com/youtubei/v1',
          headers: {
            'Content-Type': 'application/json',
            'Origin': 'https://music.youtube.com',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' // l10n-ignore
                '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36', // l10n-ignore
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

  /// Una sola WebView y un solo reproductor para toda la app.
  static final JsChallengeSolver sharedSolver = WebViewEjsSolver();
  static final PlayerScriptSource sharedPlayerScripts = PlayerScriptSource();
  static final PoTokenProvider sharedPoTokens = WebViewPoTokens();

  final JsChallengeSolver _solver;
  final PlayerScriptSource _playerScripts;
  final PoTokenProvider _poTokens;

  /// Dio limpio para pedir el audio: sin headers heredados del cliente de
  /// búsqueda (cada "cliente" de YouTube manda los suyos propios).
  final Dio _playerDio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 15)),
  );

  final Dio _dio;

  /// Clave pública embebida en el frontend web de YouTube Music. No es
  /// secreta: viaja en el HTML público del sitio y la reutilizan
  /// prácticamente todos los clientes FOSS de YTM.
  static const _apiKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL47NlEVNIeM'; // l10n-ignore

  Map<String, dynamic> get _context => {
    'context': {
      'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20260213.01.00', 'hl': 'es', 'gl': 'US'},
    },
  };

  /// Busca canciones de forma anónima. Devuelve una lista vacía si no hay
  /// resultados o si la respuesta no se pudo interpretar.
  /// Filtro "solo canciones" de la búsqueda de YouTube Music (el mismo
  /// `params` que manda la web al tocar el chip "Canciones").
  static const songsFilter = 'EgWKAQIIAWoKEAkQBRAKEAMQBA=='; // l10n-ignore

  /// Busca de forma anónima. Con [songsOnly], solo canciones (sin videos).
  Future<List<YtMusicSearchResult>> search(String query, {bool songsOnly = false}) async {
    if (query.trim().isEmpty) return const [];

    debugPrint('=== YTM search: enviando query "$query" ===');

    final response = await _dio.post<Map<String, dynamic>>(
      '/search',
      queryParameters: {'key': _apiKey},
      data: {..._context, 'query': query, if (songsOnly) 'params': songsFilter},
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

  /// Filtros de la búsqueda de YouTube Music para Artistas y Álbumes (los
  /// mismos `params` que manda la web al tocar esos chips).
  static const artistsFilter = 'EgWKAQIgAWoKEAkQChAFEAMQBA=='; // l10n-ignore
  static const albumsFilter = 'EgWKAQIYAWoKEAkQChAFEAMQBA=='; // l10n-ignore

  /// Busca artistas o álbumes (anónimo).
  Future<List<YtCollection>> searchCollections(String query, YtCollectionKind kind) async {
    if (query.trim().isEmpty) return const [];
    final response = await _dio.post<Map<String, dynamic>>(
      '/search',
      queryParameters: {'key': _apiKey},
      data: {..._context, 'query': query, 'params': kind == YtCollectionKind.artist ? artistsFilter : albumsFilter},
    );
    final data = response.data;
    return data == null ? const [] : parseCollectionResults(data, kind);
  }

  Future<Map<String, dynamic>?> _browse(String browseId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/browse',
      queryParameters: {'key': _apiKey},
      data: {..._context, 'browseId': browseId},
    );
    return response.data;
  }

  /// Página de un artista (anónimo): canciones más escuchadas y álbumes.
  Future<ArtistPage?> artist(String browseId) async {
    final data = await _browse(browseId);
    return data == null ? null : parseArtistPage(data);
  }

  /// Título, artista y duración de un video (para importar listas que solo
  /// traen el videoId, como las de Google Takeout). null si no se pudo.
  Future<YtMusicSearchResult?> videoDetails(String videoId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/player',
        queryParameters: {'key': _apiKey},
        data: {..._context, 'videoId': videoId},
      );
      final details = response.data?['videoDetails'] as Map?;
      if (details == null) return null;
      final seconds = int.tryParse('${details['lengthSeconds'] ?? ''}');
      final thumbs = (details['thumbnail'] as Map?)?['thumbnails'] as List?;
      final author = (details['author'] as String? ?? '').replaceAll(RegExp(r'\s*-\s*Topic$'), '');
      return YtMusicSearchResult(
        videoId: videoId,
        title: details['title'] as String? ?? tx.sinTitulo,
        artist: author.isEmpty ? unknownArtist : author,
        durationMs: seconds == null ? null : seconds * 1000,
        thumbnailUrl: thumbs == null || thumbs.isEmpty ? null : (thumbs.last as Map)['url'] as String?,
      );
    } catch (error) {
      debugPrint('=== YTM: sin datos del video $videoId: $error ===');
      return null;
    }
  }

  /// Cola de `/next` (anónimo): sirve para el radio de un tema y para las
  /// pistas de una playlist de YouTube Music.
  Future<List<YtMusicSearchResult>> _next(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/next',
      queryParameters: {'key': _apiKey},
      data: {..._context, ...body},
    );
    final data = response.data;
    return data == null ? const [] : parseNextTracks(data);
  }

  /// Canciones relacionadas con [videoId] (su "radio"). Lo único
  /// que se le dice a YouTube es ese videoId: el historial no sale del teléfono.
  Future<List<YtMusicSearchResult>> related(String videoId) async {
    final tracks = await _next({'videoId': videoId, 'playlistId': 'RDAMVM$videoId'});
    return [
      for (final t in tracks)
        if (t.videoId != videoId) t,
    ];
  }

  /// Pistas de una playlist de YouTube Music (sin el prefijo `VL`).
  Future<List<YtMusicSearchResult>> playlistTracks(String playlistId) => _next({'playlistId': playlistId});

  /// Géneros y estados de ánimo ("Para empezar", anónimo).
  Future<List<YtMood>> moods() async {
    final data = await _browse('FEmusic_moods_and_genres');
    return data == null ? const [] : parseMoods(data);
  }

  /// Carruseles de playlists de un género o estado de ánimo.
  Future<List<YtShelf>> moodCategory(String params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/browse',
      queryParameters: {'key': _apiKey},
      data: {..._context, 'browseId': 'FEmusic_moods_and_genres_category', 'params': params},
    );
    final data = response.data;
    return data == null ? const [] : parseMoodCategory(data);
  }

  /// Página de un álbum (anónimo): sus pistas.
  Future<AlbumPage?> album(String browseId) async {
    final data = await _browse(browseId);
    return data == null ? null : parseAlbumPage(data);
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
          final parsed = _parseItem(Map<String, dynamic>.from(renderer), fallbackArtist: cardArtist);
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
    final run = jsonListAt(card, const ['title', 'runs'])?.whereType<Map>().firstOrNull;
    final pageType = jsonAt(run, const [
      'navigationEndpoint',
      'browseEndpoint',
      'browseEndpointContextSupportedConfigs',
      'browseEndpointContextMusicConfig',
      'pageType',
    ]);
    return pageType == 'MUSIC_PAGE_TYPE_ARTIST' ? jsonStringAt(run, const ['text']) : null;
  }

  YtMusicSearchResult? _parseItem(Map<String, dynamic> renderer, {String? fallbackArtist}) {
    try {
      final videoId = _findVideoId(renderer);
      if (videoId == null) return null;

      final flexColumns = renderer['flexColumns'] as List?;
      final title = _extractText(flexColumns, 0);
      final subtitleRuns = _extractRuns(flexColumns, 1);
      final subtitle = subtitleRuns == null ? null : parseSubtitleRuns(subtitleRuns);

      final thumbnails = jsonListAt(renderer, const ['thumbnail', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails']);
      final thumbnailUrl = jsonStringAt(thumbnails?.lastOrNull, const ['url']);

      return YtMusicSearchResult(
        videoId: videoId,
        title: (title == null || title.isEmpty) ? tx.sinTitulo : title,
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
    return _extractRuns(flexColumns, index)?.map((run) => jsonStringAt(run, const ['text']) ?? '').join();
  }

  List<dynamic>? _extractRuns(List? flexColumns, int index) {
    final runs = jsonListAt(flexColumns, [index, 'musicResponsiveListItemFlexColumnRenderer', 'text', 'runs']);
    if (runs == null || runs.isEmpty) return null;
    return runs;
  }

  // ---------------------------------------------------------------------
  // Reproducción: varias "formas" de pedir el audio, en el orden
  // de `ytPlayerClients` (el de respaldo de Echo, más las que descifran con
  // el solver de yt-dlp en una WebView). Cada URL se verifica pidiendo el
  // final del archivo: algunas formas solo dejan bajar el primer minuto.
  // ---------------------------------------------------------------------

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
        options: Options(responseType: ResponseType.plain, headers: {'User-Agent': safariUserAgent}),
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
      debugPrint('=== YTM visitorData: ${found == null ? "NO encontrado" : tx.obtenidoOk} ===');
      _visitorData = found;
      return found;
    } catch (error) {
      debugPrint('=== YTM visitorData: falló: $error ===');
      return null;
    }
  }

  /// `visitorData` anónimo (lo usan también otras partes, como los
  /// subtítulos de las letras).
  Future<String?> visitorData() => _getVisitorData();

  /// Respuesta cruda de `/player` con [client], sin descifrar ni verificar
  /// nada (por ejemplo, para leer los subtítulos). null si falló.
  Future<Map<String, dynamic>?> rawPlayer(String videoId, YtPlayerClient client) async {
    final visitor = await _getVisitorData();
    try {
      final response = await _playerDio.post<Map<String, dynamic>>(
        'https://${client.host}/youtubei/v1/player',
        queryParameters: {'prettyPrint': 'false'},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-YouTube-Client-Name': client.id,
            'X-YouTube-Client-Version': client.version,
            'X-Goog-Visitor-Id': ?visitor,
            'User-Agent': client.userAgent,
          },
        ),
        data: {
          'context': {'client': client.context(visitor)},
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
        },
      );
      return response.data;
    } catch (error) {
      debugPrint('=== YTM: /player crudo [${client.label}] falló: $error ===');
      return null;
    }
  }

  /// Resuelve una URL del archivo de audio entero para [videoId] (para
  /// descargar: sin las formas HLS, que son segmentos).
  Future<String?> getAudioStreamUrl(String videoId) async => (await resolveStream(
    videoId,
    skipClients: {
      for (final client in ytPlayerClients)
        if (client.useHls) client.label,
    },
  ))?.url;

  /// true si el último [resolveStream] falló por falta de conexión (y no
  /// porque YouTube rechazara a todas las formas).
  bool lastResolveWasOffline = false;

  /// Formas que fallaron hace poco: se saltean un rato (salvo que no quede
  /// ninguna otra). Compartido entre todos los clientes de la app.
  static final Map<String, DateTime> _benchedUntil = {};
  static const _benchTime = Duration(minutes: 30);

  /// Prueba las formas en orden hasta que una entregue el audio completo.
  /// [skipClients] excluye formas que ya fallaron con esta canción. Con
  /// [lowQuality] (ahorro de datos) se elige el formato de menor bitrate.
  /// Cada intento queda en [attempts] (si se pasa): quien llama clasifica si
  /// fue culpa de la canción o de la forma y lo anota en la Salud del
  /// Extractor. Solo las fallas de la forma la dejan "en el banco".
  /// [order] reordena las formas (por éxitos recientes); las que no estén van al final.
  Future<YtStream?> resolveStream(
    String videoId, {
    Set<String> skipClients = const {},
    bool lowQuality = false,
    List<StreamAttempt>? attempts,
    List<String>? order,
    bool Function(String reason)? isContentProblem,
  }) async {
    lastResolveWasOffline = false;
    final visitorData = await _getVisitorData();
    final now = DateTime.now();
    int rank(YtPlayerClient c) {
      final i = order?.indexOf(c.label) ?? -1;
      return i < 0 ? 1 << 20 : i;
    }

    // Las formas retiradas (rotas según InnerTubeX) no entran en la cadena automática.
    final candidates = [
      for (final client in ytPlayerClients)
        if (!client.isRetired && !skipClients.contains(client.label)) client,
    ]..sort((a, b) => rank(a).compareTo(rank(b)));
    final rested = [
      for (final client in candidates)
        if (!(_benchedUntil[client.label]?.isAfter(now) ?? false)) client,
    ];

    var offline = visitorData == null;
    for (final client in rested.isEmpty ? candidates : rested) {
      final attempt = await tryClient(videoId, client, lowQuality: lowQuality);
      attempts?.add(attempt);
      if (attempt.ok) {
        _benchedUntil.remove(client.label);
        return YtStream(
          url: attempt.url!,
          client: client.label,
          userAgent: client.userAgent,
          isHls: attempt.isHls,
          contentLength: attempt.contentLength,
        );
      }
      if (attempt.offline) continue;
      offline = false;
      // Una canción con restricción de edad o no disponible no "rompe" la forma.
      if (!(isContentProblem?.call(attempt.reason!) ?? false)) {
        _benchedUntil[client.label] = DateTime.now().add(_benchTime);
      }
    }
    lastResolveWasOffline = offline;
    return null;
  }

  /// Prueba una sola forma, sin registrar nada (la usa también "Probar todas
  /// las formas ahora" de la Salud del Extractor).
  Future<StreamAttempt> tryClient(
    String videoId,
    YtPlayerClient client, {
    String? visitorData,
    bool lowQuality = false,
    bool retried = false,
  }) async {
    final watch = Stopwatch()..start();
    StreamAttempt fail(String reason) {
      debugPrint('=== YTM stream [${client.label}]: $reason ===');
      return StreamAttempt(client.label, reason: reason, elapsed: watch.elapsed);
    }

    // En la PC, el reproductor (mpv vía just_audio_media_kit) toma la lista
    // HLS de YouTube como una lista de archivos sueltos y falla.
    if (client.useHls && !kIsWeb && !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      return fail(tx.enLaPcTodaviaNoSe);
    }
    visitorData ??= await _getVisitorData();
    // Cuenta opcional: solo en las formas que la admiten (la de la web de YouTube Music).
    final session = client.loginSupported ? YtSessionHolder.current : null;
    if (session?.visitorData != null) visitorData = session!.visitorData;
    // Reproductor incrustado: su visitorData y sus encryptedHostFlags salen de la página embed.
    String? hostFlags;
    if (client.embedded) {
      final embed = await _embedConfig(videoId);
      if (embed == null) return fail(tx.noSePudoLeerLaPagina);
      visitorData = embed.visitorData;
      hostFlags = embed.hostFlags;
    }
    PlayerScript? player;
    if (client.needsPlayerScript) {
      if (!_solver.isSupported) return fail(tx.enEsteDispositivoNoSePuede);
      player = await _playerScripts.current();
      if (player == null) return fail(tx.noSePudoUbicarElReproductor);
    }

    // PO tokens (reglas de InnerTubeX 0.10.0): el de la URL de googlevideo ("GVS")
    // va ligado al VIDEO; el del pedido /player, cuando hace falta, a la sesión (visitorData).
    // Antes Kiji ligaba el de la URL a la sesión y YouTube cortaba el audio al minuto.
    String? gvsToken;
    String? playerToken;
    if (client.usesPoToken && _poTokens.isSupported) {
      gvsToken = await _poTokens.tokenFor(videoId);
      if (client.playerSessionToken && visitorData != null) {
        playerToken = await _poTokens.tokenFor(Uri.decodeComponent(visitorData));
      }
    }

    final Map<String, dynamic>? data;
    try {
      final response = await _playerDio.post<Map<String, dynamic>>(
        'https://${client.host}/youtubei/v1/player',
        queryParameters: {'prettyPrint': 'false'},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Format-Version': '1',
            'X-YouTube-Client-Name': client.id,
            'X-YouTube-Client-Version': client.version,
            'X-Origin': 'https://${client.host}',
            'Referer': 'https://${client.host}/',
            'X-Goog-Visitor-Id': ?visitorData,
            'User-Agent': client.userAgent,
            ...?session?.authHeaders(),
          },
        ),
        data: {
          'context': {
            'client': client.context(visitorData),
            if (session?.dataSyncId != null) 'user': {'onBehalfOfUser': session!.dataSyncId},
          },
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
          if (player != null)
            'playbackContext': {
              'contentPlaybackContext': {
                'signatureTimestamp': player.signatureTimestamp,
                if (client.embedded) 'html5Preference': 'HTML5_PREF_WANTS', // l10n-ignore
                'encryptedHostFlags': ?hostFlags,
              },
            },
          if (client.embedded) 'thirdParty': {'embedUrl': 'https://www.youtube.com/embed/$videoId'},
          if (playerToken != null) 'serviceIntegrityDimensions': {'poToken': playerToken},
        },
      );
      data = response.data;
    } catch (error) {
      final offline = _isOffline(error);
      debugPrint('=== YTM stream [${client.label}]: falló el pedido: $error ===');
      // Algunos visitorData vienen fallados: YouTube responde 400
      // "Precondition check failed" a todo. Se pide uno nuevo y se reintenta.
      if (!retried && error is DioException && error.response?.statusCode == 400) {
        debugPrint('=== YTM stream: visitorData rechazado, pidiendo uno nuevo ===');
        _visitorData = null;
        return tryClient(videoId, client, lowQuality: lowQuality, retried: true);
      }
      return StreamAttempt(
        client.label,
        reason: offline ? tx.sinConexion : tx.youtubeRechazoElPedido(_status(error)),
        offline: offline,
        elapsed: watch.elapsed,
      );
    }
    if (data == null) return fail(tx.youtubeRespondioVacio);

    final playability = data['playabilityStatus'] as Map?;
    final formats = sortAudioFormats(
      jsonListAt(data, const ['streamingData', 'adaptiveFormats']) ?? const [],
      lowQuality: lowQuality,
    );
    if (formats.isEmpty) {
      return fail('${playability?['status'] ?? tx.sinEstado}: ${playability?['reason'] ?? tx.sinFormatosDeAudio}');
    }
    if (client.useHls) return _tryHls(data, client, lowQuality, watch, fail);
    final format = formats.first;

    var url = format['url'] as String?;
    String? signature;
    var signatureParam = 'signature';
    if (url == null) {
      final cipher = (format['signatureCipher'] ?? format['cipher']) as String?;
      if (cipher == null) return fail(tx.elFormatoNoTraeUrlNi);
      final params = Uri.splitQueryString(cipher);
      url = params['url'];
      signature = params['s'];
      signatureParam = params['sp'] ?? 'signature';
      if (url == null || signature == null) return fail(tx.laFirmaCifradaVinoIncompleta);
      if (player == null) return fail(tx.formatoCifradoEnUnaFormaQue);
    }

    if (player != null) {
      final uri = Uri.parse(url);
      final n = uri.queryParameters['n'];
      final answers = await _solver.solve(playerHash: player.hash, playerJs: player.load, n: [?n], sig: [?signature]);
      if (signature != null && answers.sig[signature] == null) {
        return fail(tx.noSePudoDescifrarLaFirma(answers.error ?? tx.sinRespuesta));
      }
      if (n != null && answers.n[n] == null) {
        return fail(tx.noSePudoTransformarElParametro(answers.error ?? tx.sinRespuesta));
      }
      url = uri
          .replace(
            queryParameters: {
              ...uri.queryParameters,
              if (n != null) 'n': answers.n[n]!,
              if (signature != null) signatureParam: answers.sig[signature]!,
            },
          )
          .toString();
    }

    if (gvsToken != null) {
      final uri = Uri.parse(url);
      url = uri.replace(queryParameters: {...uri.queryParameters, 'pot': gvsToken}).toString();
    }

    final check = await _checkWholeFile(url, client.userAgent, int.tryParse('${format['contentLength']}'));
    if (check != null) return fail(check);
    debugPrint('=== YTM stream [${client.label}]: audio completo listo (${watch.elapsedMilliseconds} ms) ===');
    return StreamAttempt(
      client.label,
      url: url,
      elapsed: watch.elapsed,
      contentLength: int.tryParse('${format['contentLength']}'),
    );
  }

  /// visitorData y encryptedHostFlags de la página `embed` (como si el video estuviera en otra
  /// página). Con el visitor propio de Kiji, YouTube responde "no disponible" a todo.
  Future<({String visitorData, String? hostFlags})?> _embedConfig(String videoId) async {
    try {
      final response = await _playerDio.get<String>(
        'https://www.youtube.com/embed/$videoId?html5=1',
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': chromeUserAgent,
            'Referer': 'https://www.reddit.com/',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        ),
      );
      final html = response.data ?? '';
      final visitor = RegExp(r'"visitorData"\s*:\s*"([^"]+)"').firstMatch(html)?.group(1);
      if (visitor == null) return null;
      final flags = RegExp(r'"encryptedHostFlags"\s*:\s*"([^"]+)"').firstMatch(html)?.group(1);
      return (visitorData: visitor, hostFlags: flags);
    } catch (error) {
      debugPrint('=== YTM stream [WEB_EMBEDDED_PLAYER]: no se pudo leer la página embed: ${error.runtimeType} ===');
      return null;
    }
  }

  /// Forma HLS: la lista de solo audio, verificando el primer y el último
  /// segmento.
  Future<StreamAttempt> _tryHls(
    Map<String, dynamic> data,
    YtPlayerClient client,
    bool lowQuality,
    Stopwatch watch,
    StreamAttempt Function(String) fail,
  ) async {
    final manifest = jsonStringAt(data, const ['streamingData', 'hlsManifestUrl']);
    if (manifest == null) return fail(tx.youtubeNoEntregoLaListaHls);
    Future<Response<String>> text(String url) => _playerDio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': client.userAgent},
        validateStatus: (_) => true,
      ),
    );
    try {
      final master = await text(manifest);
      if (master.statusCode != 200) return fail(tx.laListaHlsNoRespondeHttp(master.statusCode));
      final audio = pickHlsAudio(master.data ?? '', lowQuality: lowQuality);
      if (audio == null) return fail(tx.laListaHlsNoTraeAudio);
      final playlist = await text(audio);
      final segments = (playlist.data ?? '').split('\n').where((l) => l.startsWith('http')).toList();
      if (playlist.statusCode != 200 || segments.isEmpty) return fail(tx.laListaDeAudioHlsVino);
      for (final segment in [segments.first, segments.last]) {
        final response = await _playerDio.get<List<int>>(
          segment,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'User-Agent': client.userAgent},
            validateStatus: (_) => true,
          ),
        );
        if (response.statusCode != 200) return fail(tx.unSegmentoHlsNoBajaHttp(response.statusCode));
      }
      final duration = hlsDuration(playlist.data ?? '');
      debugPrint(
        '=== YTM stream [${client.label}]: lista HLS lista, ${segments.length} segmentos, '
        '${duration.inSeconds} s (${watch.elapsedMilliseconds} ms) ===',
      );
      return StreamAttempt(client.label, url: audio, isHls: true, duration: duration, elapsed: watch.elapsed);
    } catch (error) {
      return _isOffline(error) ? fail(tx.sinConexion) : fail(tx.laListaHlsFallo('$error'.split('\n').first));
    }
  }

  /// Duración de una lista HLS: la suma de sus `#EXTINF` (en la PC, mpv no
  /// la informa).
  @visibleForTesting
  static Duration hlsDuration(String playlist) {
    var seconds = 0.0;
    for (final match in RegExp(r'#EXTINF:([\d.]+)').allMatches(playlist)) {
      seconds += double.tryParse(match.group(1)!) ?? 0;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// URL de la lista de solo audio dentro de una lista HLS maestra: la de más
  /// calidad (o la más liviana, con [lowQuality]).
  @visibleForTesting
  static String? pickHlsAudio(String master, {bool lowQuality = false}) {
    final options = <(int, String)>[];
    for (final line in master.split('\n')) {
      if (!line.startsWith('#EXT-X-MEDIA') || !line.contains('TYPE=AUDIO')) continue;
      final uri = RegExp(r'URI="([^"]+)"').firstMatch(line)?.group(1);
      if (uri == null) continue;
      // El GROUP-ID es el itag: 233 ≈ 48 kbps, 234 ≈ 128 kbps.
      final itag = int.tryParse(RegExp(r'GROUP-ID="(\d+)"').firstMatch(line)?.group(1) ?? '') ?? 0;
      options.add((itag, uri));
    }
    if (options.isEmpty) return null;
    options.sort((a, b) => lowQuality ? a.$1.compareTo(b.$1) : b.$1.compareTo(a.$1));
    return options.first.$2;
  }

  /// Verifica que se pueda bajar el FINAL del archivo (no solo el comienzo).
  /// Devuelve el motivo si no se puede, o null si está todo bien.
  Future<String?> _checkWholeFile(String url, String userAgent, int? length) async {
    final range = length != null && length > 4096 ? 'bytes=${length - 2048}-${length - 1}' : 'bytes=0-1023';
    try {
      final response = await _playerDio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'User-Agent': userAgent, 'Range': range},
          validateStatus: (_) => true,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final status = response.statusCode ?? 0;
      if (status == 200 || status == 206) return null;
      if (status == 403 && length != null && length > 4096) {
        return tx.youtubeSoloDejaBajarElPrimer;
      }
      return tx.elAudioNoRespondeHttp(status);
    } catch (error) {
      return _isOffline(error) ? tx.sinConexion : tx.elAudioNoResponde(error);
    }
  }

  static bool _isOffline(Object error) =>
      error is DioException &&
      (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.error is SocketException);

  static String _status(Object error) => error is DioException && error.response != null
      ? 'HTTP ${error.response!.statusCode}' // l10n-ignore
      : '$error'.split('\n').first;

  /// Formatos de audio de `streamingData`, de mayor a menor bitrate (con
  /// [lowQuality], de menor a mayor: el primero es el más liviano).
  @visibleForTesting
  static List<Map> sortAudioFormats(List formats, {bool lowQuality = false}) {
    int bitrate(Map f) => (f['bitrate'] as int?) ?? 0;
    return formats.whereType<Map>().where((f) => ((f['mimeType'] as String?) ?? '').startsWith('audio/')).toList()
      ..sort((a, b) => lowQuality ? bitrate(a).compareTo(bitrate(b)) : bitrate(b).compareTo(bitrate(a)));
  }

  @visibleForTesting
  static void resetBenchForTest() => _benchedUntil.clear();
}

/// Resultado de probar una forma.
class StreamAttempt {
  const StreamAttempt(
    this.client, {
    this.url,
    this.reason,
    this.offline = false,
    this.isHls = false,
    this.duration,
    this.elapsed = Duration.zero,
    this.contentLength,
  });

  final bool isHls;

  /// Tamaño del archivo de audio, si YouTube lo dijo.
  final int? contentLength;

  /// Duración que dice la lista HLS (null en las demás formas).
  final Duration? duration;

  final String client;
  final String? url;

  /// Motivo exacto de la falla (null si anduvo).
  final String? reason;
  final bool offline;
  final Duration elapsed;

  bool get ok => url != null;
}
