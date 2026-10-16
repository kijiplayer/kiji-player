import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/yt_music/data/ytm_browse_parser.dart';

Map<String, dynamic> _runs(String text, {String? pageType}) => {
      'runs': [
        {
          'text': text,
          if (pageType != null)
            'navigationEndpoint': {
              'browseEndpoint': {
                'browseEndpointContextSupportedConfigs': {
                  'browseEndpointContextMusicConfig': {'pageType': pageType},
                },
              },
            },
        },
      ],
    };

Map<String, dynamic> _flex(String text) => {
      'musicResponsiveListItemFlexColumnRenderer': {'text': _runs(text)},
    };

Map<String, dynamic> _collectionRow(String id, String title, String subtitle, String pageType) => {
      'musicResponsiveListItemRenderer': {
        'flexColumns': [_flex(title), _flex(subtitle)],
        'thumbnail': {
          'musicThumbnailRenderer': {
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://lh3.googleusercontent.com/$id=w60-h60'},
              ],
            },
          },
        },
        'navigationEndpoint': {
          'browseEndpoint': {
            'browseId': id,
            'browseEndpointContextSupportedConfigs': {
              'browseEndpointContextMusicConfig': {'pageType': pageType},
            },
          },
        },
      },
    };

Map<String, dynamic> _songRow(String videoId, List<String> columns, {String? duration}) => {
      'musicResponsiveListItemRenderer': {
        'playlistItemData': {'videoId': videoId},
        'flexColumns': [for (final c in columns) _flex(c)],
        if (duration != null)
          'fixedColumns': [
            {
              'musicResponsiveListItemFixedColumnRenderer': {'text': _runs(duration)},
            },
          ],
      },
    };

void main() {
  test('Resultados de Artistas y Álbumes: solo el tipo pedido, sin el tipo en el texto', () {
    final json = {
      'contents': [
        _collectionRow('UC1', 'Daft Punk', 'Artista • 71 M usuarios', 'MUSIC_PAGE_TYPE_ARTIST'),
        _collectionRow('MPREb_1', 'Discovery', 'Álbum • Daft Punk • 2001', 'MUSIC_PAGE_TYPE_ALBUM'),
        _collectionRow('UC1', 'Daft Punk', 'Artista', 'MUSIC_PAGE_TYPE_ARTIST'), // repetido
      ],
    };
    final artists = parseCollectionResults(json, YtCollectionKind.artist);
    expect(artists.map((a) => a.browseId), ['UC1']);
    final albums = parseCollectionResults(json, YtCollectionKind.album);
    expect(albums.single.title, 'Discovery');
    expect(albums.single.subtitle, 'Daft Punk · 2001');
    expect(albums.single.thumbnailUrl, contains('MPREb_1'));
  });

  test('Página de artista: nombre, canciones y álbumes', () {
    final json = {
      'header': {
        'musicImmersiveHeaderRenderer': {'title': _runs('Daft Punk')},
      },
      'contents': [
        _songRow('v1', ['Instant Crush', 'Daft Punk y Julian Casablancas', '1240 M reproducciones', 'RAM']),
        {
          'musicTwoRowItemRenderer': {
            'title': _runs('Discovery'),
            'subtitle': _runs('2001'),
            'navigationEndpoint': {
              'browseEndpoint': {
                'browseId': 'MPREb_7',
                'browseEndpointContextSupportedConfigs': {
                  'browseEndpointContextMusicConfig': {'pageType': 'MUSIC_PAGE_TYPE_ALBUM'},
                },
              },
            },
          },
        },
      ],
    };
    final page = parseArtistPage(json);
    expect(page.name, 'Daft Punk');
    expect(page.songs.single.artist, 'Daft Punk y Julian Casablancas');
    expect(page.songs.single.album, 'RAM');
    expect(page.albums.single.browseId, 'MPREb_7');
  });

  test('Página de álbum: las pistas heredan el artista y traen su duración', () {
    final json = {
      'contents': {
        'header': {
          'musicResponsiveHeaderRenderer': {
            'title': _runs('Discovery'),
            'straplineTextOne': _runs('Daft Punk'),
            'subtitle': _runs('Álbum • 2001'),
          },
        },
        'tracks': [
          _songRow('t1', ['One More Time', ''], duration: '5:20'),
          _songRow('t2', ['Aerodynamic', ''], duration: '3:27'),
        ],
      },
    };
    final page = parseAlbumPage(json);
    expect(page.title, 'Discovery');
    expect(page.artist, 'Daft Punk');
    expect(page.tracks.map((t) => t.title), ['One More Time', 'Aerodynamic']);
    expect(page.tracks.first.artist, 'Daft Punk');
    expect(page.tracks.first.album, 'Discovery');
    expect(page.tracks.first.durationMs, 320000);
  });

  test('JSON vacío o raro no rompe nada', () {
    expect(parseCollectionResults({}, YtCollectionKind.album), isEmpty);
    expect(parseArtistPage({}).songs, isEmpty);
    expect(parseAlbumPage({}).title, 'Sin título');
  });
}
