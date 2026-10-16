import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/yt_music/domain/subtitle_parser.dart';

Map<String, dynamic> _run(String text, {String? pageType}) => {
      'text': text,
      if (pageType != null)
        'navigationEndpoint': {
          'browseEndpoint': {
            'browseEndpointContextSupportedConfigs': {
              'browseEndpointContextMusicConfig': {'pageType': pageType},
            },
          },
        },
    };

void main() {
  group('cleanArtistText', () {
    test('Quita el tipo, el álbum, las visualizaciones y la duración', () {
      expect(cleanArtistText('Canción • Daft Punk'), 'Daft Punk');
      expect(cleanArtistText('Canción • Daft Punk • Discovery • 5:20'), 'Daft Punk');
      expect(cleanArtistText('Vídeo • Will Clarke • 927 visualizaciones • 4:01'), 'Will Clarke');
      expect(cleanArtistText("Naf' Manson • 50 M de visualizaciones • 5:21"), "Naf' Manson");
      expect(cleanArtistText('Song • Rod Wave • 1:02:03'), 'Rod Wave');
    });

    test('Respeta artistas compuestos y textos ya limpios', () {
      expect(cleanArtistText('Canción • Daft Punk y Pharrell Williams'), 'Daft Punk y Pharrell Williams');
      expect(cleanArtistText('Daft Punk'), 'Daft Punk');
      expect(cleanArtistText('Luna Nova'), 'Luna Nova');
    });

    test('Sin artista en el texto: null al buscar, "Artista desconocido" al limpiar', () {
      expect(extractArtist('Canción • 4:40'), isNull);
      expect(cleanArtistText('Canción • 4:40'), 'Artista desconocido');
    });
  });

  test('parseSubtitleRuns saca artista, álbum y duración', () {
    final parsed = parseSubtitleRuns([
      _run('Canción'),
      _run(' • '),
      _run('Daft Punk', pageType: 'MUSIC_PAGE_TYPE_ARTIST'),
      _run(' • '),
      _run('Discovery', pageType: 'MUSIC_PAGE_TYPE_ALBUM'),
      _run(' • '),
      _run('5:20'),
    ]);
    expect(parsed.artist, 'Daft Punk');
    expect(parsed.album, 'Discovery');
    expect(parsed.durationMs, 320000);
  });
}
