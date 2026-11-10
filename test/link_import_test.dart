import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/import/data/link_import.dart';

// Páginas inventadas con la misma forma que las reales (datos inventados).
String _spotify() {
  final data = {
    'props': {
      'pageProps': {
        'state': {
          'data': {
            'entity': {
              'name': 'Lista Inventada',
              'trackList': [
                {'title': 'Glass Harbor', 'subtitle': 'The Velvet Tides', 'duration': 201000},
                {'title': 'Slow Comet', 'subtitle': 'Aurelio Fen, Mira Solenne', 'duration': 254000},
              ],
            },
          },
        },
      },
    },
  };
  return '<html><script id="__NEXT_DATA__" type="application/json">${jsonEncode(data)}</script></html>';
}

String _apple({bool withPageData = true}) {
  final page = {
    'data': [
      {
        'sections': [
          {
            'items': [
              {'title': 'Lemon Static', 'artistName': 'June Arbor', 'duration': 213000},
              {'title': 'Orbit of You', 'artistName': 'Lumen Drive', 'duration': 236000},
            ],
          },
        ],
      },
    ],
  };
  final ld = {
    '@type': 'MusicPlaylist',
    'name': 'Lista de Apple Inventada',
    'track': [
      {'@type': 'MusicRecording', 'name': 'Lemon Static', 'duration': 'PT3M33S'},
      {'@type': 'MusicRecording', 'name': 'Orbit of You', 'duration': 'PT3M56S', 'byArtist': {'name': 'Lumen Drive'}},
    ],
  };
  return '<html>'
      '${withPageData ? '<script type="application/json" id="serialized-server-data">${jsonEncode(page)}</script>' : ''}'
      '<script type="application/ld+json">${jsonEncode(ld)}</script></html>';
}

String _soundcloud() {
  final hydration = [
    {'hydratable': 'user', 'data': {'username': 'otro'}},
    {
      'hydratable': 'playlist',
      'data': {
        'title': 'Set Inventado',
        'tracks': [
          {'title': 'Neon Rainfall', 'user': {'username': 'kaiyo_lanterns'}, 'duration': 187000},
          {'id': 12345}, // solo el id: sin claves no se puede leer
        ],
      },
    },
  ];
  return '<html><script>window.__sc_hydration = ${jsonEncode(hydration)};</script></html>';
}

void main() {
  test('Reconoce los enlaces públicos de playlist (y nada más)', () {
    expect(parsePlaylistLink('https://music.youtube.com/playlist?list=PLinventada')!.id, 'PLinventada');
    expect(parsePlaylistLink('https://www.youtube.com/watch?v=abc&list=PLotra')!.source, LinkSource.youtube);
    expect(parsePlaylistLink('https://open.spotify.com/playlist/37inventada?si=x')!.id, '37inventada');
    expect(parsePlaylistLink('https://open.spotify.com/intl-es/playlist/abc')!.id, 'abc');
    expect(parsePlaylistLink('https://music.apple.com/ar/playlist/algo/pl.inventada')!.source, LinkSource.appleMusic);
    expect(parsePlaylistLink('https://m.soundcloud.com/alguien/sets/inventado')!.url, startsWith('https://soundcloud.com/'));
    for (final bad in [
      'hola',
      'https://open.spotify.com/track/123',
      'https://www.youtube.com/watch?v=abc',
      'ftp://open.spotify.com/playlist/x',
      'https://soundcloud.com/alguien/una-cancion',
    ]) {
      expect(parsePlaylistLink(bad), isNull, reason: bad);
    }
  });

  test('Spotify: nombre, títulos, artistas y duración de la página pública', () {
    final pl = parseSpotifyEmbed(_spotify());
    expect(pl.name, 'Lista Inventada');
    expect(pl.songs.map((s) => (s.title, s.artist, s.durationMs)), [
      ('Glass Harbor', 'The Velvet Tides', 201000),
      ('Slow Comet', 'Aurelio Fen, Mira Solenne', 254000),
    ]);
    expect(parseSpotifyEmbed('<html>sin datos</html>').songs, isEmpty);
  });

  test('Apple Music: de los datos de la página o, si no, del JSON-LD', () {
    final pl = parseAppleMusicPage(_apple());
    expect(pl.name, 'Lista de Apple Inventada');
    expect(pl.songs.map((s) => (s.title, s.artist, s.durationMs)), [
      ('Lemon Static', 'June Arbor', 213000),
      ('Orbit of You', 'Lumen Drive', 236000),
    ]);
    final ld = parseAppleMusicPage(_apple(withPageData: false));
    expect(ld.songs.map((s) => (s.title, s.durationMs)), [('Lemon Static', 213000), ('Orbit of You', 236000)]);
    expect(ld.songs.last.artist, 'Lumen Drive');
    expect(isoDurationMs('PT1H2M3S'), 3723000);
    expect(isoDurationMs('raro'), isNull);
  });

  test('SoundCloud: las canciones completas de la página (las que solo traen id, no)', () {
    final pl = parseSoundCloudPage(_soundcloud());
    expect(pl.name, 'Set Inventado');
    expect(pl.songs.single.title, 'Neon Rainfall');
    expect(pl.songs.single.artist, 'kaiyo_lanterns');
  });
}
