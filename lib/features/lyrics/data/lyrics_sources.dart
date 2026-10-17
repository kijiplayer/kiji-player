// Adaptado de Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos originales: lyrics/src/main/kotlin/.../lyrics/*LyricsProvider.kt y
// LyricsProviderRegistry.kt (fuentes y su orden), kugou/.../KuGou.kt (que a su vez
// viene de ViMusic, GPL-3.0), betterlyrics/.../BetterLyrics.kt,
// youlyplus/.../YouLyPlus.kt, paxsenixlyrics/.../Paxsenix.kt, unison/.../Unison.kt e
// innertube/.../YouTube.kt (`lyrics` y `transcript`).
//
// Cada fuente recibe solo el título, el artista, el álbum, la duración y (algunas) el
// id del video de YouTube, y solo cuando el usuario abre la letra.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../yt_music/data/yt_clients.dart';
import '../../yt_music/data/ytm_client.dart';
import '../domain/lyrics.dart';
import 'lrclib_client.dart';
import 'lyrics_repository.dart' show LyricsRequest;

/// Una fuente de letras.
abstract class LyricsFetcher {
  LyricsSource get source;

  /// La letra, o null si esta fuente no la tiene. Si no responde (sin
  /// conexión, servicio caído), tira [LyricsUnavailableException].
  Future<Lyrics?> fetch(LyricsRequest request);
}

String? videoIdOf(LyricsRequest request) => request.id.startsWith('yt-') ? request.id.substring(3) : null;

const kijiUserAgent = 'Kiji Player 1.0.0 (software libre, GPL-3.0)';

Dio lyricsDio() => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: {'User-Agent': kijiUserAgent},
    ));

/// Convierte errores de red en [LyricsUnavailableException] y el resto en
/// "no hay letra" (null).
Future<Lyrics?> _guard(LyricsSource source, Future<Lyrics?> Function() run) async {
  try {
    return await run();
  } on DioException catch (error) {
    final status = error.response?.statusCode;
    if (status == 404) return null;
    debugPrint('=== LETRAS: ${source.label} no respondió: ${error.type} $status ===');
    throw LyricsUnavailableException('${source.label} no respondió');
  } on LyricsUnavailableException {
    rethrow;
  } catch (error) {
    debugPrint('=== LETRAS: ${source.label} devolvió algo raro: $error ===');
    return null;
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
String lrcTime(int ms) => '[${_two(ms ~/ 60000)}:${_two((ms ~/ 1000) % 60)}.${(ms % 1000).toString().padLeft(3, '0')}]';

class LrcLibFetcher implements LyricsFetcher {
  LrcLibFetcher([LrcLibClient? client]) : _client = client ?? LrcLibClient();
  final LrcLibClient _client;
  @override
  LyricsSource get source => LyricsSource.lrclib;
  @override
  Future<Lyrics?> fetch(LyricsRequest r) async {
    final lyrics = await _client.fetch(
      title: r.title,
      artist: r.artist,
      album: r.album,
      duration: r.durationMs > 0 ? Duration(milliseconds: r.durationMs) : null,
    );
    return lyrics.isEmpty ? null : lyrics;
  }
}

/// YouLyPlus / LyricsPlus: varios servidores comunitarios; gana el primero
/// que responde con letra.
class YouLyPlusFetcher implements LyricsFetcher {
  YouLyPlusFetcher(this._dio);
  final Dio _dio;
  static const servers = [
    'https://lyricsplus.prjktla.my.id',
    'https://lyricsplus.atomix.one',
    'https://lyricsplus.binimum.org',
    'https://lyricsplus.prjktla.workers.dev',
    'https://lyricsplus-seven.vercel.app',
    'https://lyrics-plus-backend.vercel.app',
  ];
  @override
  LyricsSource get source => LyricsSource.youlyplus;

  @override
  Future<Lyrics?> fetch(LyricsRequest r) async {
    final done = Completer<Lyrics?>();
    var pending = servers.length;
    var failures = 0;
    for (final server in servers) {
      unawaited(_one(server, r).then((lyrics) {
        if (lyrics != null && !done.isCompleted) done.complete(lyrics);
      }, onError: (Object _) {
        failures++;
        return null;
      }).whenComplete(() {
        if (--pending == 0 && !done.isCompleted) {
          if (failures == servers.length) {
            done.completeError(const LyricsUnavailableException('YouLyPlus no respondió'));
          } else {
            done.complete(null);
          }
        }
      }));
    }
    return done.future;
  }

  Future<Lyrics?> _one(String server, LyricsRequest r) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$server/v2/lyrics/get',
      queryParameters: {
        'title': r.title,
        'artist': r.artist,
        'duration': r.durationMs ~/ 1000,
        'album': ?r.album,
        'id': ?videoIdOf(r),
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    final data = response.data;
    if (response.statusCode != 200 || data == null) return null;
    return lyricsFromText(data['syncedLyrics'] as String?, source) ??
        lyricsFromText(_itemsToLrc(data['lyrics']), source) ??
        lyricsFromText(data['plainLyrics'] as String?, source);
  }

  static String? _itemsToLrc(Object? items) {
    if (items is! List || items.isEmpty) return null;
    return [
      for (final item in items.whereType<Map>())
        '${lrcTime((item['time'] as num?)?.toInt() ?? 0)}'
            '${item['syllabus'] is List && (item['syllabus'] as List).isNotEmpty ? (item['syllabus'] as List).whereType<Map>().where((s) => s['isBackground'] != true).map((s) => '${s['text'] ?? ''}').join() : item['text'] ?? ''}',
    ].join('\n');
  }
}

/// PaxSenix: letras de Apple Music. Kiji se presenta con su propio nombre.
class PaxSenixFetcher implements LyricsFetcher {
  PaxSenixFetcher(this._dio);
  final Dio _dio;
  static const base = 'https://lyrics.paxsenix.org';
  @override
  LyricsSource get source => LyricsSource.paxsenix;

  @override
  Future<Lyrics?> fetch(LyricsRequest r) => _guard(source, () async {
        final search = await _dio.get<List<dynamic>>(
          '$base/apple-music/search',
          queryParameters: {'q': '${r.title} ${r.artist}'},
        );
        final results = (search.data ?? const []).whereType<Map>().toList();
        if (results.isEmpty) return null;
        final wanted = r.durationMs ~/ 1000;
        Map? best;
        var bestScore = double.infinity;
        for (final result in results.take(8)) {
          final raw = (result['duration'] as num?)?.toInt() ?? 0;
          final seconds = raw > 10000 ? raw ~/ 1000 : raw;
          if (wanted > 0 && seconds > 0 && (seconds - wanted).abs() > 8) continue;
          final score = wanted > 0 && seconds > 0 ? (seconds - wanted).abs().toDouble() : 5.0;
          if (score < bestScore) {
            bestScore = score;
            best = result;
          }
        }
        if (best == null) return null;
        final lyrics = await _dio.get<Map<String, dynamic>>(
          '$base/apple-music/lyrics',
          queryParameters: {'id': best['id']},
        );
        final data = lyrics.data;
        if (data == null) return null;
        final ttml = data['ttmlContent'] as String?;
        if (ttml != null && ttml.isNotEmpty) {
          final lines = parseTtml(ttml);
          if (lines.isNotEmpty) return Lyrics(synced: lines, source: source);
        }
        return lyricsFromText(data['elrc'] as String?, source) ??
            lyricsFromText(_contentToLrc(data['content']), source) ??
            lyricsFromText(data['plain'] as String?, source);
      });

  static String? _contentToLrc(Object? content) {
    if (content is! List || content.isEmpty) return null;
    return [
      for (final line in content.whereType<Map>())
        '${lrcTime((line['timestamp'] as num?)?.toInt() ?? 0)}'
            '${(line['text'] as List? ?? const []).whereType<Map>().map((w) => '${w['text'] ?? ''}').join(' ')}',
    ].join('\n');
  }
}

/// Unison: por id del video de YouTube y, si no, por título y artista.
class UnisonFetcher implements LyricsFetcher {
  UnisonFetcher(this._dio);
  final Dio _dio;
  static const base = 'https://unison.boidu.dev';
  @override
  LyricsSource get source => LyricsSource.unison;

  @override
  Future<Lyrics?> fetch(LyricsRequest r) => _guard(source, () async {
        Future<Lyrics?> ask(Map<String, dynamic> query) async {
          final response = await _dio.get<Map<String, dynamic>>(
            '$base/lyrics',
            queryParameters: query,
            options: Options(validateStatus: (s) => s != null && s < 500),
          );
          final data = response.data;
          if (response.statusCode != 200 || data == null || data['success'] != true) return null;
          final entry = data['data'];
          return entry is Map ? lyricsFromText(entry['lyrics'] as String?, source) : null;
        }

        final videoId = videoIdOf(r);
        return (videoId == null ? null : await ask({'v': videoId})) ??
            await ask({
              'song': r.title,
              'artist': r.artist,
              'album': ?r.album,
              if (r.durationMs > 0) 'duration': r.durationMs ~/ 1000,
            });
      });
}

/// Better Lyrics: TTML por título y artista.
class BetterLyricsFetcher implements LyricsFetcher {
  BetterLyricsFetcher(this._dio);
  final Dio _dio;
  @override
  LyricsSource get source => LyricsSource.betterlyrics;

  @override
  Future<Lyrics?> fetch(LyricsRequest r) => _guard(source, () async {
        final response = await _dio.get<Map<String, dynamic>>(
          'https://lyrics-api.boidu.dev/getLyrics',
          queryParameters: {
            's': r.title,
            'a': r.artist,
            if (r.durationMs > 0) 'd': r.durationMs ~/ 1000,
            'al': ?r.album,
          },
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
        final ttml = response.statusCode == 200 ? (response.data?['ttml'] as String?) : null;
        if (ttml == null || ttml.isEmpty) return null;
        final lines = parseTtml(ttml);
        return lines.isEmpty ? null : Lyrics(synced: lines, source: source);
      });
}

// SimpMusic (que Echo usa) no está: su API responde "This API is only available to
// SimpMusic clients", y Kiji no se hace pasar por otra app.

/// KuGou: busca la canción y su letra LRC (tolerancia de 8 s en la duración).
class KuGouFetcher implements LyricsFetcher {
  KuGouFetcher(this._dio);
  final Dio _dio;
  @override
  LyricsSource get source => LyricsSource.kugou;

  static String _cleanTitle(String title) => title
      .replaceAll(RegExp(r'\(.*\)'), '')
      .replaceAll(RegExp(r'（.*）'), '')
      .replaceAll(RegExp(r'「.*」'), '')
      .replaceAll(RegExp(r'『.*』'), '')
      .replaceAll(RegExp(r'<.*>'), '')
      .replaceAll(RegExp(r'《.*》'), '')
      .trim();

  static String _cleanArtist(String artist) =>
      artist.replaceAll(', ', '、').replaceAll(' & ', '、').replaceAll('.', '').replaceAll(RegExp(r'\(.*\)'), '').trim();

  /// Saca las líneas de créditos ("作词：…") del principio y del final.
  @visibleForTesting
  static String normalizeKuGou(String lrc) {
    final accepted = RegExp(r'^\[(\d\d):(\d\d)\.(\d{2,3})\].*');
    final banned = RegExp(r'.+\].+[:：].+');
    final lines = lrc.split(RegExp(r'\r?\n')).where(accepted.hasMatch).toList();
    // Los créditos se buscan al principio y al final (hasta 30 líneas, y
    // nunca más de la mitad de la letra).
    final limit = (lines.length ~/ 2).clamp(0, 30);
    var head = 0;
    for (var i = limit; i >= 0 && i < lines.length; i--) {
      if (banned.hasMatch(lines[i])) {
        head = i + 1;
        break;
      }
    }
    final rest = lines.sublist(head);
    var tail = rest.length;
    for (var i = rest.length - 1; i >= rest.length - limit && i >= 0; i--) {
      if (banned.hasMatch(rest[i])) tail = i;
    }
    return rest.sublist(0, tail).join('\n');
  }

  @override
  Future<Lyrics?> fetch(LyricsRequest r) => _guard(source, () async {
        final keyword = '${_cleanTitle(r.title)} - ${_cleanArtist(r.artist)}';
        final seconds = r.durationMs > 0 ? r.durationMs ~/ 1000 : -1;
        Future<Map?> firstCandidate(Map<String, dynamic> query) async {
          final response = await _dio.get<String>(
            'https://lyrics.kugou.com/search',
            queryParameters: {'ver': 1, 'man': 'yes', 'client': 'pc', ...query},
            options: Options(responseType: ResponseType.plain),
          );
          final candidates = (jsonDecode(response.data ?? '{}') as Map)['candidates'];
          return candidates is List && candidates.isNotEmpty ? candidates.first as Map : null;
        }

        Map? candidate;
        final songs = await _dio.get<String>(
          'https://mobileservice.kugou.com/api/v3/search/song',
          queryParameters: {'version': 9108, 'plat': 0, 'pagesize': 8, 'showtype': 0, 'keyword': keyword},
          options: Options(responseType: ResponseType.plain),
        );
        final info = ((jsonDecode(songs.data ?? '{}') as Map)['data'] as Map?)?['info'];
        for (final song in info is List ? info.whereType<Map>() : const <Map>[]) {
          final d = (song['duration'] as num?)?.toInt() ?? 0;
          if (seconds != -1 && (d - seconds).abs() > 8) continue;
          candidate = await firstCandidate({'hash': song['hash']});
          if (candidate != null) break;
        }
        candidate ??= await firstCandidate({'keyword': keyword, if (seconds != -1) 'duration': seconds * 1000});
        if (candidate == null) return null;
        final download = await _dio.get<String>(
          'https://lyrics.kugou.com/download',
          queryParameters: {
            'fmt': 'lrc',
            'charset': 'utf8',
            'client': 'pc',
            'ver': 1,
            'id': candidate['id'],
            'accesskey': candidate['accesskey'],
          },
          options: Options(responseType: ResponseType.plain),
        );
        final content = (jsonDecode(download.data ?? '{}') as Map)['content'] as String?;
        if (content == null || content.isEmpty) return null;
        final text = normalizeKuGou(utf8.decode(base64Decode(content)));
        // "纯音乐，请欣赏" = "música instrumental": KuGou no tiene la letra.
        if (text.contains('纯音乐')) return null;
        return lyricsFromText(text, source);
      });
}

const _ytmKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL47NlEVNIeM';
Map<String, dynamic> _webRemix() => {
      'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20260213.01.00', 'hl': 'es', 'gl': 'US'},
    };

/// Subtítulos del video de YouTube (con tiempos). `get_transcript`, el que
/// usa Echo, hoy responde "Precondition check failed"; las pistas de
/// subtítulos de `/player` (cliente ANDROID_VR) sí andan, como en yt-dlp.
class YouTubeSubtitlesFetcher implements LyricsFetcher {
  YouTubeSubtitlesFetcher(this._dio, [YtMusicClient? youtube]) : _youtube = youtube ?? YtMusicClient();
  final Dio _dio;
  final YtMusicClient _youtube;
  @override
  LyricsSource get source => LyricsSource.youtubeSubtitles;

  @override
  Future<Lyrics?> fetch(LyricsRequest r) => _guard(source, () async {
        final videoId = videoIdOf(r);
        if (videoId == null) return null;
        final player = await _youtube.rawPlayer(videoId, clientByLabel('ANDROID_VR')!);
        if (player == null) throw const LyricsUnavailableException('YouTube no respondió');
        final tracks = _dig(player, ['captions', 'playerCaptionsTracklistRenderer', 'captionTracks']);
        if (tracks is! List || tracks.isEmpty) return null;
        final track = pickCaptionTrack(tracks.whereType<Map>().toList());
        if (track == null) return null;
        final base = Uri.parse('${track['baseUrl']}');
        final response = await _dio.get<String>(
          base.replace(queryParameters: {...base.queryParameters, 'fmt': 'json3'}).toString(),
          options: Options(responseType: ResponseType.plain),
        );
        return lyricsFromText(captionsToLrc(response.data ?? ''), source);
      });

  /// La pista en el idioma en que se canta: el de los subtítulos
  /// automáticos (reconocen la voz); de ese idioma, mejor la hecha a mano.
  @visibleForTesting
  static Map? pickCaptionTrack(List<Map> tracks) {
    if (tracks.isEmpty) return null;
    final auto = tracks.where((t) => t['kind'] == 'asr').firstOrNull;
    if (auto == null) return tracks.first;
    final language = '${auto['languageCode']}'.split('-').first;
    return tracks
            .where((t) => t['kind'] != 'asr' && '${t['languageCode']}'.split('-').first == language)
            .firstOrNull ??
        auto;
  }

  /// Subtítulos `json3` a LRC: una línea por evento con texto.
  @visibleForTesting
  static String captionsToLrc(String json3) {
    if (json3.isEmpty) return '';
    final events = (jsonDecode(json3) as Map)['events'];
    if (events is! List) return '';
    final lines = <String>[];
    for (final e in events.whereType<Map>()) {
      final segs = e['segs'];
      if (segs is! List) continue;
      final text = segs
          .whereType<Map>()
          .map((s) => '${s['utf8'] ?? ''}')
          .join()
          .replaceAll('\n', ' ')
          .replaceAll('♪', '')
          .trim();
      if (text.isNotEmpty) lines.add('${lrcTime((e['tStartMs'] as num?)?.toInt() ?? 0)}$text');
    }
    return lines.join('\n');
  }
}

/// Letra de YouTube Music (texto, sin tiempos): `next` → pestaña Letra → `browse`.
class YouTubeMusicFetcher implements LyricsFetcher {
  YouTubeMusicFetcher(this._dio);
  final Dio _dio;
  @override
  LyricsSource get source => LyricsSource.youtubeMusic;

  @override
  Future<Lyrics?> fetch(LyricsRequest r) => _guard(source, () async {
        final videoId = videoIdOf(r);
        if (videoId == null) return null;
        final next = await _dio.post<Map<String, dynamic>>(
          'https://music.youtube.com/youtubei/v1/next',
          queryParameters: {'key': _ytmKey, 'prettyPrint': 'false'},
          data: {'context': _webRemix(), 'videoId': videoId},
        );
        final browseId = _dig(next.data, [
          'contents', 'singleColumnMusicWatchNextResultsRenderer', 'tabbedRenderer', 'watchNextTabbedResultsRenderer',
          'tabs', 1, 'tabRenderer', 'endpoint', 'browseEndpoint', 'browseId',
        ]);
        if (browseId is! String) return null;
        final browse = await _dio.post<Map<String, dynamic>>(
          'https://music.youtube.com/youtubei/v1/browse',
          queryParameters: {'key': _ytmKey, 'prettyPrint': 'false'},
          data: {'context': _webRemix(), 'browseId': browseId},
        );
        final sections = _dig(browse.data, ['contents', 'sectionListRenderer', 'contents']);
        if (sections is! List) return null;
        for (final section in sections) {
          final runs = _dig(section, ['musicDescriptionShelfRenderer', 'description', 'runs']);
          if (runs is List) {
            return lyricsFromText(runs.whereType<Map>().map((run) => '${run['text'] ?? ''}').join(), source);
          }
        }
        return null;
      });
}

/// Recorre un JSON por claves e índices; null si algo no está.
Object? _dig(Object? node, List<Object> path) {
  var current = node;
  for (final key in path) {
    if (key is int && current is List && key < current.length) {
      current = current[key];
    } else if (key is String && current is Map) {
      current = current[key];
    } else {
      return null;
    }
  }
  return current;
}

/// Todas las fuentes por internet, en el orden de [LyricsSource.online].
List<LyricsFetcher> defaultLyricsFetchers({Dio? dio, LrcLibClient? lrclib}) {
  final d = dio ?? lyricsDio();
  return [
    LrcLibFetcher(lrclib),
    YouLyPlusFetcher(d),
    PaxSenixFetcher(d),
    UnisonFetcher(d),
    BetterLyricsFetcher(d),
    KuGouFetcher(d),
    YouTubeSubtitlesFetcher(d),
    YouTubeMusicFetcher(d),
  ];
}
