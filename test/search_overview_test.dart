import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/yt_music/data/ytm_browse_parser.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';
import 'package:kiji_player/features/yt_music/presentation/search_screen.dart';

Map<String, dynamic> _endpoint(String id, String pageType) => {
  'browseEndpoint': {
    'browseId': id,
    'browseEndpointContextSupportedConfigs': {
      'browseEndpointContextMusicConfig': {'pageType': pageType},
    },
  },
};

Map<String, dynamic> _card(Map<String, dynamic> endpoint, String title, String subtitle) => {
  'contents': {
    'sectionListRenderer': {
      'contents': [
        {
          'musicCardShelfRenderer': {
            'title': {
              'runs': [
                {'text': title, 'navigationEndpoint': endpoint},
              ],
            },
            'subtitle': {
              'runs': [
                {'text': subtitle},
              ],
            },
            'thumbnail': {
              'musicThumbnailRenderer': {
                'thumbnail': {
                  'thumbnails': [
                    {'url': 'https://example.com/chica'},
                    {'url': 'https://example.com/grande'},
                  ],
                },
              },
            },
          },
        },
      ],
    },
  },
};

YtMusicSearchResult _song(String id) => YtMusicSearchResult(videoId: id, title: 'Canción $id', artist: 'Grupo Inventado');

YtCollection _collection(String id, YtCollectionKind kind) => YtCollection(browseId: id, title: 'Cosa $id', kind: kind);

void main() {
  group('Resultado principal', () {
    test('una canción: con su videoId, la portada más grande y la duración', () {
      final top = parseTopResult(
        _card({
          'watchEndpoint': {'videoId': 'video1'},
        }, 'Canción Inventada', 'Canción • Grupo Inventado • 3:25'),
      );
      expect(top?.song?.videoId, 'video1');
      expect(top?.song?.title, 'Canción Inventada');
      expect(top?.song?.durationMs, 205000);
      expect(top?.song?.thumbnailUrl, 'https://example.com/grande');
      expect(top?.collection, isNull);
    });

    test('un artista, un álbum o una playlist (sin el VL del id)', () {
      final artist = parseTopResult(
        _card(_endpoint('UCx', 'MUSIC_PAGE_TYPE_ARTIST'), 'Grupo Inventado', 'Artista • 1 M usuarios'),
      );
      expect(artist?.collection?.kind, YtCollectionKind.artist);
      expect(artist?.collection?.subtitle, '');

      final album = parseTopResult(
        _card(_endpoint('MPREb_x', 'MUSIC_PAGE_TYPE_ALBUM'), 'Disco Inventado', 'Álbum • Grupo Inventado • 2020'),
      );
      expect(album?.collection?.kind, YtCollectionKind.album);
      expect(album?.collection?.subtitle, 'Grupo Inventado · 2020');

      final playlist = parseTopResult(
        _card(_endpoint('VLPLinventada', 'MUSIC_PAGE_TYPE_PLAYLIST'), 'Lista Inventada', 'Autora • 2 M'),
      );
      expect(playlist?.collection?.kind, YtCollectionKind.playlist);
      expect(playlist?.collection?.browseId, 'PLinventada');
      expect(playlist?.collection?.subtitle, 'Autora · 2 M');
    });

    test('perfiles, pódcasts o sin tarjeta: no hay resultado principal', () {
      expect(parseTopResult(_card(_endpoint('UCy', 'MUSIC_PAGE_TYPE_USER_CHANNEL'), 'Perfil', '')), isNull);
      expect(parseTopResult({}), isNull);
    });
  });

  test('pestaña Todo: el principal no se repite y cada sección muestra unos pocos', () {
    final overview = SearchOverview.from(
      top: YtTopResult.song(_song('s1')),
      songs: [for (var i = 1; i <= 8; i++) _song('s$i')],
      artists: [for (var i = 1; i <= 5; i++) _collection('a$i', YtCollectionKind.artist)],
      albums: const [],
      playlists: [_collection('p1', YtCollectionKind.playlist)],
    );
    expect(overview.songs.map((s) => s.videoId), ['s2', 's3', 's4', 's5']);
    expect(overview.artists, hasLength(3));
    expect(overview.albums, isEmpty);
    expect(overview.playlists.single.browseId, 'p1');

    final byArtist = SearchOverview.from(
      top: YtTopResult.collection(_collection('a1', YtCollectionKind.artist)),
      artists: [_collection('a1', YtCollectionKind.artist), _collection('a2', YtCollectionKind.artist)],
    );
    expect(byArtist.artists.map((a) => a.browseId), ['a2']);
    expect(const SearchOverview().isEmpty, isTrue);
  });
}
