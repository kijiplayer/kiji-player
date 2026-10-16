import '../domain/subtitle_parser.dart';
import 'ytm_client.dart';

/// Un artista o un álbum de YouTube Music (resultado de búsqueda o carrusel).
enum YtCollectionKind { artist, album }

class YtCollection {
  const YtCollection({
    required this.browseId,
    required this.title,
    required this.kind,
    this.subtitle = '',
    this.thumbnailUrl,
  });

  /// `UC…` para artistas, `MPREb_…` para álbumes.
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

String? _pageType(Map? browseEndpoint) => ((browseEndpoint?['browseEndpointContextSupportedConfigs']
        as Map?)?['browseEndpointContextMusicConfig'] as Map?)?['pageType'] as String?;

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
            title: texts.isEmpty || texts.first.isEmpty ? 'Sin título' : texts.first,
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
  final wanted = kind == YtCollectionKind.artist ? 'MUSIC_PAGE_TYPE_ARTIST' : 'MUSIC_PAGE_TYPE_ALBUM';
  final results = <YtCollection>[];
  final seen = <String>{};
  void walk(Object? n) {
    if (n is Map) {
      final r = n['musicResponsiveListItemRenderer'];
      if (r is Map) {
        final endpoint = (r['navigationEndpoint'] as Map?)?['browseEndpoint'] as Map?;
        final id = endpoint?['browseId'] as String?;
        if (id != null && _pageType(endpoint) == wanted && seen.add(id)) {
          final texts = _flexTexts(r);
          results.add(YtCollection(
            browseId: id,
            title: texts.isEmpty ? 'Sin título' : texts.first,
            kind: kind,
            // "Álbum · Daft Punk · 2001" → "Daft Punk · 2001" (sin el tipo).
            subtitle: kind == YtCollectionKind.album && texts.length > 1
                ? texts[1].split(' • ').skip(1).join(' · ')
                : '',
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
  return results;
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
    title: title.isEmpty ? 'Sin título' : title,
    artist: artist,
    subtitle: _runsText(header?['subtitle']).replaceAll(' • ', ' · '),
    thumbnailUrl: thumbnail,
    tracks: _songRows(json['contents'], fallbackArtist: artist, album: title, thumbnail: thumbnail),
  );
}
