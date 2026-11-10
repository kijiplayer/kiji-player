import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../yt_music/data/ytm_client.dart';
import '../domain/imported.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// De dónde es un enlace de playlist pegado.
enum LinkSource { youtube, spotify, appleMusic, soundcloud }

/// Un enlace público de playlist reconocido.
class PlaylistLink {
  const PlaylistLink(this.source, this.url, {this.id});

  final LinkSource source;
  final String url;

  /// El id de la playlist (YouTube y Spotify).
  final String? id;

  String get label => switch (source) {
    LinkSource.youtube => 'YouTube Music', // l10n-ignore
    LinkSource.spotify => 'Spotify', // l10n-ignore
    LinkSource.appleMusic => 'Apple Music', // l10n-ignore
    LinkSource.soundcloud => 'SoundCloud', // l10n-ignore
  };
}

/// Reconoce un enlace público de playlist (o null si no es uno que Kiji sepa leer).
PlaylistLink? parsePlaylistLink(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return null;
  final host = uri.host.toLowerCase();
  if (host.endsWith('youtube.com') || host == 'youtu.be') {
    final list = uri.queryParameters['list'];
    return list == null || list.isEmpty ? null : PlaylistLink(LinkSource.youtube, uri.toString(), id: list);
  }
  if (host == 'open.spotify.com') {
    final i = uri.pathSegments.indexOf('playlist');
    if (i < 0 || i + 1 >= uri.pathSegments.length) return null;
    return PlaylistLink(LinkSource.spotify, uri.toString(), id: uri.pathSegments[i + 1]);
  }
  if (host == 'music.apple.com' && uri.pathSegments.contains('playlist')) {
    return PlaylistLink(LinkSource.appleMusic, uri.toString());
  }
  if ((host == 'soundcloud.com' || host == 'm.soundcloud.com') && uri.pathSegments.contains('sets')) {
    return PlaylistLink(LinkSource.soundcloud, uri.replace(host: 'soundcloud.com').toString());
  }
  return null;
}

/// Una playlist leída de la página pública: nombre y canciones (título, artista y duración).
typedef LinkPlaylist = ({String? name, List<ImportedSong> songs});

/// Lee la playlist de [link] y la devuelve como un [ImportBundle] para buscar cada canción en
/// YouTube Music. Solo se consulta el enlace pegado (sin iniciar sesión ni claves). Si la página no
/// se puede leer, tira [ImportFormatException] con un mensaje simple.
Future<ImportBundle> fetchLinkBundle(PlaylistLink link, {Dio? dio, YtMusicClient? youtube}) async {
  final LinkPlaylist playlist;
  try {
    if (link.source == LinkSource.youtube) {
      final results = await (youtube ?? YtMusicClient()).playlistTracks(link.id!);
      playlist = (
        name: null,
        songs: [
          for (final r in results)
            ImportedSong(videoId: r.videoId, title: r.title, artist: r.artist, durationMs: r.durationMs, thumbnailUrl: r.thumbnailUrl),
        ],
      );
    } else {
      final client = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15)));
      final url = link.source == LinkSource.spotify ? 'https://open.spotify.com/embed/playlist/${link.id}' : link.url;
      final response = await client.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          // Un navegador común: estas páginas son públicas y no piden nada más.
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/128.0', 'Accept-Language': 'en'}, // l10n-ignore
        ),
      );
      final html = response.data ?? '';
      playlist = switch (link.source) {
        LinkSource.spotify => parseSpotifyEmbed(html),
        LinkSource.appleMusic => parseAppleMusicPage(html),
        LinkSource.soundcloud => parseSoundCloudPage(html),
        LinkSource.youtube => (name: null, songs: const <ImportedSong>[]),
      };
    }
  } on ImportFormatException {
    rethrow;
  } catch (error) {
    debugPrint('=== IMPORTAR: no se pudo leer el enlace de ${link.label}: ${error.runtimeType} ===');
    throw ImportFormatException(tx.noSePudoLeerEseEnlace);
  }
  final songs = [for (final s in playlist.songs) if (s.isUsable) s];
  if (songs.isEmpty) throw ImportFormatException(tx.noSePudoLeerEseEnlace);
  debugPrint('=== IMPORTAR: ${songs.length} canciones del enlace de ${link.label} ===');
  return ImportBundle(source: link.label, playlists: [ImportedPlaylist(playlist.name ?? link.label, songs)]);
}

/// Recorre [node] y devuelve los mapas que cumplen [test] (para JSON de forma desconocida).
List<Map<String, dynamic>> _findMaps(Object? node, bool Function(Map<String, dynamic> m) test) {
  final found = <Map<String, dynamic>>[];
  void walk(Object? n) {
    if (n is Map) {
      final m = n.cast<String, dynamic>();
      if (test(m)) found.add(m);
      m.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(node);
  return found;
}

String? _scriptContent(String html, RegExp start) {
  final match = start.firstMatch(html);
  if (match == null) return null;
  final end = html.indexOf('</script>', match.end);
  return end < 0 ? null : html.substring(match.end, end);
}

String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
int? _int(Object? v) => v is num ? v.toInt() : null;

/// Spotify (página "embed" pública): el JSON de `__NEXT_DATA__` trae `trackList` con título,
/// artistas (`subtitle`) y duración en ms.
@visibleForTesting
LinkPlaylist parseSpotifyEmbed(String html) {
  final json = _scriptContent(html, RegExp(r'<script[^>]*id="__NEXT_DATA__"[^>]*>'));
  if (json == null) return (name: null, songs: const []);
  final data = jsonDecode(json);
  final entity = _findMaps(data, (m) => m['trackList'] is List).firstOrNull;
  if (entity == null) return (name: null, songs: const []);
  return (
    name: _str(entity['name']) ?? _str(entity['title']),
    songs: [
      for (final t in (entity['trackList'] as List).whereType<Map>())
        ImportedSong(
          title: _str(t['title']),
          artist: _str(t['subtitle'])?.replaceAll(' ', ' '),
          durationMs: _int(t['duration']),
        ),
    ],
  );
}

/// Apple Music (página pública): las canciones salen de los datos que trae la página
/// (`title`, `artistName`, `duration` en ms); si no, del JSON-LD (`track`, duración ISO 8601).
@visibleForTesting
LinkPlaylist parseAppleMusicPage(String html) {
  String? name;
  final songs = <ImportedSong>[];
  final serialized = _scriptContent(html, RegExp(r'<script[^>]*id="serialized-server-data"[^>]*>'));
  if (serialized != null) {
    try {
      final data = jsonDecode(serialized);
      for (final m in _findMaps(data, (m) => _str(m['title']) != null && _str(m['artistName']) != null)) {
        songs.add(ImportedSong(title: _str(m['title']), artist: _str(m['artistName']), durationMs: _int(m['duration'])));
      }
    } catch (error) {
      debugPrint('=== IMPORTAR: Apple Music sin datos de la página: ${error.runtimeType} ===');
    }
  }
  // El nombre (y, si los datos de la página no alcanzaron, las canciones) del JSON-LD.
  final fromPage = songs.isNotEmpty;
  {
    for (final match in RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>').allMatches(html)) {
      final end = html.indexOf('</script>', match.end);
      if (end < 0) continue;
      try {
        final data = jsonDecode(html.substring(match.end, end));
        for (final pl in _findMaps(data, (m) => m['track'] is List)) {
          name ??= _str(pl['name']);
          if (fromPage) continue;
          for (final t in (pl['track'] as List).whereType<Map>()) {
            final by = t['byArtist'];
            songs.add(
              ImportedSong(
                title: _str(t['name']),
                artist: by is Map ? _str(by['name']) : by is List && by.isNotEmpty && by.first is Map ? _str(by.first['name']) : null,
                durationMs: isoDurationMs(_str(t['duration'])),
              ),
            );
          }
        }
      } catch (error) {
        debugPrint('=== IMPORTAR: Apple Music sin JSON-LD legible: ${error.runtimeType} ===');
      }
    }
  }
  return (name: name, songs: songs);
}

/// "PT3M25S" → 205000. null si no se entiende.
int? isoDurationMs(String? text) {
  if (text == null) return null;
  final m = RegExp(r'^P(?:T)?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?$').firstMatch(text);
  if (m == null || (m[1] == null && m[2] == null && m[3] == null)) return null;
  final seconds = int.parse(m[1] ?? '0') * 3600 + int.parse(m[2] ?? '0') * 60 + double.parse(m[3] ?? '0');
  return (seconds * 1000).round();
}

/// SoundCloud (página pública): `window.__sc_hydration` trae la playlist. Las primeras canciones
/// vienen completas (título, usuario y duración); las demás solo con su id y no se pueden leer sin
/// claves, así que quedan afuera.
@visibleForTesting
LinkPlaylist parseSoundCloudPage(String html) {
  final start = html.indexOf('window.__sc_hydration = ');
  if (start < 0) return (name: null, songs: const []);
  final from = start + 'window.__sc_hydration = '.length;
  final end = html.indexOf(';</script>', from);
  if (end < 0) return (name: null, songs: const []);
  final data = jsonDecode(html.substring(from, end));
  final playlist = _findMaps(data, (m) => m['hydratable'] == 'playlist').firstOrNull?['data'];
  if (playlist is! Map) return (name: null, songs: const []);
  return (
    name: _str(playlist['title']),
    songs: [
      for (final t in (playlist['tracks'] as List? ?? const []).whereType<Map>())
        if (_str(t['title']) != null)
          ImportedSong(
            title: _str(t['title']),
            artist: t['user'] is Map ? _str((t['user'] as Map)['username']) : null,
            durationMs: _int(t['duration']),
          ),
    ],
  );
}
