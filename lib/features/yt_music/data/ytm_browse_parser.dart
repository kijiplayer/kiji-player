import '../domain/subtitle_parser.dart';
import 'ytm_client.dart';
import 'package:kiji_player/l10n/l10n.dart';

import '../../../utils/json_access.dart';

/// Un artista, un álbum o una playlist de YouTube Music (resultado de búsqueda o carrusel).
enum YtCollectionKind { artist, album, playlist }

class YtCollection {
  const YtCollection({
    required this.browseId,
    required this.title,
    required this.kind,
    this.subtitle = '',
    this.thumbnailUrl,
  });

  /// `UC…` para artistas, `MPREb_…` para álbumes; para playlists, el id sin `VL`.
  final String browseId;
  final String title;
  final YtCollectionKind kind;

  /// "Daft Punk · 2001" para álbumes; vacío para artistas.
  final String subtitle;
  final String? thumbnailUrl;
}

class ArtistPage {
  const ArtistPage({required this.name, required this.songs, required this.albums, this.thumbnailUrl});

  final String name;
  final List<YtMusicSearchResult> songs;
  final List<YtCollection> albums;
  final String? thumbnailUrl;
}

class AlbumPage {
  const AlbumPage({
    required this.title,
    required this.artist,
    required this.tracks,
    this.subtitle = '',
    this.thumbnailUrl,
  });

  final String title;
  final String artist;
  final String subtitle;
  final List<YtMusicSearchResult> tracks;
  final String? thumbnailUrl;
}

// ---------------------------------------------------------------------------
// Ayudas para recorrer el JSON de YouTube Music (cambia seguido: todo es
// tolerante a campos que falten).
// ---------------------------------------------------------------------------

String _runsText(Object? textObject) {
  final runs = (textObject as Map?)?['runs'] as List?;
  if (runs == null) return '';
  return runs.whereType<Map>().map((r) => r['text'] ?? '').join();
}

String? _lastThumbnail(Object? node) {
  // Busca la primera lista "thumbnails" y devuelve la más grande (la última).
  String? found;
  void walk(Object? n) {
    if (found != null) return;
    if (n is Map) {
      final list = n['thumbnails'];
      if (list is List && list.isNotEmpty && list.last is Map) {
        found = (list.last as Map)['url'] as String?;
        return;
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(node);
  return found;
}

String? _pageType(Map? browseEndpoint) => jsonStringAt(
  browseEndpoint,
  const ['browseEndpointContextSupportedConfigs', 'browseEndpointContextMusicConfig', 'pageType'],
);

List<String> _flexTexts(Map renderer) => [
      for (final column in (renderer['flexColumns'] as List? ?? const []).whereType<Map>())
        _runsText((column['musicResponsiveListItemFlexColumnRenderer'] as Map?)?['text']),
    ];

List<dynamic>? _flexRuns(Map renderer, int index) {
  final columns = (renderer['flexColumns'] as List? ?? const []).whereType<Map>().toList();
  if (index >= columns.length) return null;
  return ((columns[index]['musicResponsiveListItemFlexColumnRenderer'] as Map?)?['text'] as Map?)?['runs']
      as List?;
}

String? _videoId(Map renderer) {
  final fromPlaylist = (renderer['playlistItemData'] as Map?)?['videoId'] as String?;
  if (fromPlaylist != null) return fromPlaylist;
  final overlay = ((((renderer['overlay'] as Map?)?['musicItemThumbnailOverlayRenderer'] as Map?)?['content']
          as Map?)?['musicPlayButtonRenderer'] as Map?)?['playNavigationEndpoint'] as Map?;
  return (overlay?['watchEndpoint'] as Map?)?['videoId'] as String?;
}

int? _durationMs(String text) {
  if (!RegExp(r'^\d{1,2}(:\d{2}){1,2}$').hasMatch(text.trim())) return null;
  var seconds = 0;
  for (final part in text.trim().split(':')) {
    seconds = seconds * 60 + int.parse(part);
  }
  return seconds * 1000;
}

/// Todas las filas de canción (`musicResponsiveListItemRenderer` con videoId).
/// [fallbackArtist]: para los álbumes, donde cada pista no repite el artista.
List<YtMusicSearchResult> _songRows(Object? root, {String? fallbackArtist, String? album, String? thumbnail}) {
  final songs = <YtMusicSearchResult>[];
  final seen = <String>{};
  void walk(Object? n) {
    if (n is Map) {
      final r = n['musicResponsiveListItemRenderer'];
      if (r is Map) {
        final id = _videoId(r);
        if (id != null && seen.add(id)) {
          final texts = _flexTexts(r);
          final runs = _flexRuns(r, 1);
          final parsed = runs == null ? null : parseSubtitleRuns(runs);
          final fixed = [
            for (final c in (r['fixedColumns'] as List? ?? const []).whereType<Map>())
              _runsText((c['musicResponsiveListItemFixedColumnRenderer'] as Map?)?['text']),
          ];
          final artist = parsed?.artist ?? fallbackArtist ?? unknownArtist;
          songs.add(YtMusicSearchResult(
            videoId: id,
            title: texts.isEmpty || texts.first.isEmpty ? tx.sinTitulo : texts.first,
            artist: artist,
            album: album ?? (texts.length > 3 && texts[3].isNotEmpty ? texts[3] : parsed?.album),
            durationMs: parsed?.durationMs ?? (fixed.isEmpty ? null : _durationMs(fixed.first)),
            thumbnailUrl: _lastThumbnail(r['thumbnail']) ?? thumbnail,
          ));
        }
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(root);
  return songs;
}

// ---------------------------------------------------------------------------
// Lectores
// ---------------------------------------------------------------------------

/// Resultados de buscar con el filtro Artistas o Álbumes.
List<YtCollection> parseCollectionResults(Map<String, dynamic> json, YtCollectionKind kind) {
  final wanted = _pageTypes[kind];
  final results = <YtCollection>[];
  final seen = <String>{};
  void walk(Object? n) {
    if (n is Map) {
      final r = n['musicResponsiveListItemRenderer'];
      if (r is Map) {
        final endpoint = (r['navigationEndpoint'] as Map?)?['browseEndpoint'] as Map?;
        final id = _collectionId(endpoint?['browseId'] as String?, kind);
        if (id != null && _pageType(endpoint) == wanted && seen.add(id)) {
          final texts = _flexTexts(r);
          results.add(YtCollection(
            browseId: id,
            title: texts.isEmpty ? tx.sinTitulo : texts.first,
            kind: kind,
            subtitle: texts.length > 1 ? _collectionSubtitle(kind, texts[1]) : '',
            thumbnailUrl: _lastThumbnail(r['thumbnail']),
          ));
        }
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(json['contents']);
  walk(json['continuationContents']);
  return results;
}

const _pageTypes = {
  YtCollectionKind.artist: 'MUSIC_PAGE_TYPE_ARTIST',
  YtCollectionKind.album: 'MUSIC_PAGE_TYPE_ALBUM',
  YtCollectionKind.playlist: 'MUSIC_PAGE_TYPE_PLAYLIST',
};

/// Las playlists se abren con su id sin el `VL` de la página.
String? _collectionId(String? browseId, YtCollectionKind kind) =>
    kind == YtCollectionKind.playlist && browseId != null && browseId.startsWith('VL') ? browseId.substring(2) : browseId;

/// "Álbum • Grupo • 2001" → "Grupo · 2001" (sin el tipo). Las playlists no traen
/// el tipo delante ("Autor • 2 M de visualizaciones"); los artistas no llevan subtítulo.
String _collectionSubtitle(YtCollectionKind kind, String text) => switch (kind) {
  YtCollectionKind.artist => '',
  YtCollectionKind.album => text.split(' • ').skip(1).join(' · '),
  YtCollectionKind.playlist => text.split(' • ').join(' · '),
};

/// El resultado principal de una búsqueda sin filtro (la tarjeta grande de
/// YouTube Music): una canción o video, o un artista, álbum o playlist.
class YtTopResult {
  const YtTopResult.song(YtMusicSearchResult this.song) : collection = null;
  const YtTopResult.collection(YtCollection this.collection) : song = null;

  final YtMusicSearchResult? song;
  final YtCollection? collection;
}

YtTopResult? parseTopResult(Map<String, dynamic> json) {
  Map? card;
  void walk(Object? n) {
    if (card != null) return;
    if (n is Map) {
      final found = n['musicCardShelfRenderer'];
      if (found is Map) {
        card = found;
        return;
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(json['contents']);
  final top = card;
  if (top == null) return null;
  final title = _runsText(top['title']);
  if (title.isEmpty) return null;
  final runs = (top['title'] as Map?)?['runs'] as List?;
  final endpoint = runs?.whereType<Map>().firstOrNull?['navigationEndpoint'] as Map?;
  final thumbnail = _lastThumbnail(top['thumbnail']);

  final videoId = jsonStringAt(endpoint, const ['watchEndpoint', 'videoId']);
  if (videoId != null) {
    final subtitle = parseSubtitleRuns((top['subtitle'] as Map?)?['runs'] as List? ?? const []);
    return YtTopResult.song(
      YtMusicSearchResult(
        videoId: videoId,
        title: title,
        artist: subtitle.artist ?? unknownArtist,
        album: subtitle.album,
        durationMs: subtitle.durationMs,
        thumbnailUrl: thumbnail,
      ),
    );
  }
  final browse = endpoint?['browseEndpoint'] as Map?;
  final type = _pageType(browse);
  final kind = _pageTypes.entries.where((e) => e.value == type).firstOrNull?.key;
  final id = kind == null ? null : _collectionId(browse?['browseId'] as String?, kind);
  if (kind == null || id == null) return null; // perfiles, pódcasts, etc.
  return YtTopResult.collection(
    YtCollection(
      browseId: id,
      title: title,
      kind: kind,
      subtitle: _collectionSubtitle(kind, _runsText(top['subtitle'])),
      thumbnailUrl: thumbnail,
    ),
  );
}

/// Marca para pedir la página siguiente de una búsqueda (null si no hay más).
/// Viene en `nextContinuationData` del estante de resultados, tanto en la
/// primera página (`contents`) como en las siguientes (`continuationContents`).
String? parseSearchContinuation(Map<String, dynamic> json) {
  String? found;
  void walk(Object? n) {
    if (found != null) return;
    if (n is Map) {
      final token = jsonStringAt(n, const ['nextContinuationData', 'continuation']);
      if (token != null && token.isNotEmpty) {
        found = token;
        return;
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(json['contents']);
  walk(json['continuationContents']);
  return found;
}

/// Página de un artista: nombre, sus canciones más escuchadas y sus álbumes.
ArtistPage parseArtistPage(Map<String, dynamic> json) {
  final header = json['header'] as Map? ?? const {};
  final headerRenderer = (header['musicImmersiveHeaderRenderer'] ??
      header['musicVisualHeaderRenderer'] ??
      header.values.whereType<Map>().firstOrNull) as Map?;
  final name = _runsText(headerRenderer?['title']);

  final albums = <YtCollection>[];
  final seen = <String>{};
  void walk(Object? n) {
    if (n is Map) {
      final r = n['musicTwoRowItemRenderer'];
      if (r is Map) {
        final endpoint = (r['navigationEndpoint'] as Map?)?['browseEndpoint'] as Map?;
        final id = endpoint?['browseId'] as String?;
        if (id != null && _pageType(endpoint) == 'MUSIC_PAGE_TYPE_ALBUM' && seen.add(id)) {
          albums.add(YtCollection(
            browseId: id,
            title: _runsText(r['title']),
            kind: YtCollectionKind.album,
            subtitle: _runsText(r['subtitle']),
            thumbnailUrl: _lastThumbnail(r['thumbnailRenderer']),
          ));
        }
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(json['contents']);
  return ArtistPage(
    name: name.isEmpty ? unknownArtist : name,
    songs: _songRows(json['contents'], fallbackArtist: name.isEmpty ? null : name),
    albums: albums,
    thumbnailUrl: _lastThumbnail(headerRenderer?['thumbnail']),
  );
}

/// Página de un álbum: título, artista y pistas (que heredan el artista).
AlbumPage parseAlbumPage(Map<String, dynamic> json) {
  Map? header;
  void findHeader(Object? n) {
    if (header != null) return;
    if (n is Map) {
      final h = n['musicResponsiveHeaderRenderer'] ?? n['musicDetailHeaderRenderer'];
      if (h is Map) {
        header = h;
        return;
      }
      n.values.forEach(findHeader);
    } else if (n is List) {
      n.forEach(findHeader);
    }
  }

  findHeader(json);
  final title = _runsText(header?['title']);
  final strapline = _runsText(header?['straplineTextOne']);
  final artist = strapline.isNotEmpty ? strapline : (extractArtist(_runsText(header?['subtitle'])) ?? unknownArtist);
  final thumbnail = _lastThumbnail(header?['thumbnail']);
  return AlbumPage(
    title: title.isEmpty ? tx.sinTitulo : title,
    artist: artist,
    subtitle: _runsText(header?['subtitle']).replaceAll(' • ', ' · '),
    thumbnailUrl: thumbnail,
    tracks: _songRows(json['contents'], fallbackArtist: artist, album: title, thumbnail: thumbnail),
  );
}

// ---------------------------------------------------------------------------
// Recomendaciones: radio de un tema, playlists y "Para empezar".
// ---------------------------------------------------------------------------

/// Canciones de la cola de `/next` (`playlistPanelVideoRenderer`): el radio de
/// un tema ("relacionadas") o las pistas de una playlist de YouTube Music.
List<YtMusicSearchResult> parseNextTracks(Map<String, dynamic> json) {
  final tracks = <YtMusicSearchResult>[];
  final seen = <String>{};
  void walk(Object? n) {
    if (n is Map) {
      final r = n['playlistPanelVideoRenderer'];
      if (r is Map) {
        final id = r['videoId'] as String?;
        if (id != null && seen.add(id)) {
          final runs = ((r['longBylineText'] as Map?)?['runs'] as List? ?? const []).whereType<Map>().toList();
          String? linked(String type) {
            final names = [
              for (final run in runs)
                if (_pageType((run['navigationEndpoint'] as Map?)?['browseEndpoint'] as Map?) == type)
                  '${run['text']}',
            ];
            return names.isEmpty ? null : names.join(', ');
          }

          final first = runs.isEmpty ? '' : '${runs.first['text']}'.trim();
          tracks.add(YtMusicSearchResult(
            videoId: id,
            title: _runsText(r['title']).isEmpty ? tx.sinTitulo : _runsText(r['title']),
            artist: linked('MUSIC_PAGE_TYPE_ARTIST') ?? (first.isEmpty ? unknownArtist : first),
            album: linked('MUSIC_PAGE_TYPE_ALBUM'),
            durationMs: _durationMs(_runsText(r['lengthText'])),
            thumbnailUrl: _lastThumbnail(r['thumbnail']),
          ));
        }
        return;
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(json);
  return tracks;
}

/// Un género o un estado de ánimo de YouTube Music ("Para empezar").
class YtMood {
  const YtMood({required this.title, required this.params, required this.isGenre, this.color});

  final String title;

  /// `params` para `browse` con `FEmusic_moods_and_genres_category`.
  final String params;
  final bool isGenre;

  /// Color de la franja (ARGB), si YouTube lo manda.
  final int? color;
}

/// Una playlist de YouTube Music (tarjeta de un carrusel).
class YtPlaylistCard {
  const YtPlaylistCard({required this.playlistId, required this.title, this.subtitle = '', this.thumbnailUrl});

  /// Sin el prefijo `VL` (sirve para `/next`).
  final String playlistId;
  final String title;
  final String subtitle;
  final String? thumbnailUrl;
}

/// Un carrusel con título ("Mezclas de cafetería") y sus playlists.
class YtShelf {
  const YtShelf({required this.title, required this.playlists});
  final String title;
  final List<YtPlaylistCard> playlists;
}

/// Página "Estados de ánimo y géneros": primero los ánimos, después los géneros.
List<YtMood> parseMoods(Map<String, dynamic> json) {
  final moods = <YtMood>[];
  var gridIndex = 0;
  void walk(Object? n) {
    if (n is Map) {
      final grid = n['gridRenderer'];
      if (grid is Map) {
        final isGenre = gridIndex++ > 0;
        for (final item in (grid['items'] as List? ?? const []).whereType<Map>()) {
          final b = item['musicNavigationButtonRenderer'];
          if (b is! Map) continue;
          final endpoint = (b['clickCommand'] as Map?)?['browseEndpoint'] as Map?;
          final params = endpoint?['params'] as String?;
          final title = _runsText(b['buttonText']);
          if (params == null || title.isEmpty) continue;
          moods.add(YtMood(
            title: title,
            params: params,
            isGenre: isGenre,
            color: ((b['solid'] as Map?)?['leftStripeColor'] as num?)?.toInt(),
          ));
        }
        return;
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(json);
  return moods;
}

/// Página de un ánimo o género: carruseles de playlists.
List<YtShelf> parseMoodCategory(Map<String, dynamic> json) {
  final shelves = <YtShelf>[];
  void walk(Object? n) {
    if (n is Map) {
      final shelf = n['musicCarouselShelfRenderer'];
      if (shelf is Map) {
        final title = _runsText(((shelf['header'] as Map?)?['musicCarouselShelfBasicHeaderRenderer'] as Map?)?['title']);
        final cards = <YtPlaylistCard>[];
        for (final item in (shelf['contents'] as List? ?? const []).whereType<Map>()) {
          final r = item['musicTwoRowItemRenderer'];
          if (r is! Map) continue;
          final endpoint = (r['navigationEndpoint'] as Map?)?['browseEndpoint'] as Map?;
          final browseId = endpoint?['browseId'] as String?;
          if (browseId == null || _pageType(endpoint) != 'MUSIC_PAGE_TYPE_PLAYLIST') continue;
          cards.add(YtPlaylistCard(
            playlistId: browseId.startsWith('VL') ? browseId.substring(2) : browseId,
            title: _runsText(r['title']),
            subtitle: _runsText(r['subtitle']),
            thumbnailUrl: _lastThumbnail(r['thumbnailRenderer']),
          ));
        }
        if (cards.isNotEmpty) shelves.add(YtShelf(title: title, playlists: cards));
        return;
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(json);
  return shelves;
}

/// Las canciones de una página (playlist, "Me gusta" de la cuenta).
List<YtMusicSearchResult> parseSongRows(Map<String, dynamic> json) => _songRows(json);

/// Playlists de la biblioteca de la cuenta (tarjetas con su `browseId` "VL…"): (id, nombre).
List<({String id, String name})> parseLibraryPlaylists(Map<String, dynamic> json) {
  final out = <({String id, String name})>[];
  final seen = <String>{};
  void walk(Object? n) {
    if (n is Map) {
      final card = n['musicTwoRowItemRenderer'];
      if (card is Map) {
        final browseId = jsonStringAt(card, const ['navigationEndpoint', 'browseEndpoint', 'browseId']);
        final title = _runsText(card['title']);
        // "VLLM" es "Me gusta" (va aparte); las demás, las playlists de la cuenta.
        if (browseId != null && browseId.startsWith('VL') && browseId != 'VLLM' && title.isNotEmpty && seen.add(browseId)) {
          out.add((id: browseId.substring(2), name: title));
        }
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(json);
  return out;
}
