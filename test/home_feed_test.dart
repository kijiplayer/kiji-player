import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/history/listening_history.dart';
import 'package:kiji_player/features/recommendations/data/search_history.dart';
import 'package:kiji_player/features/recommendations/domain/home_feed.dart';
import 'package:kiji_player/features/yt_music/data/ytm_browse_parser.dart';
import 'package:kiji_player/models/track.dart';

Track _yt(String id, {String artist = 'Artista A'}) => Track(
      id: 'yt-$id',
      title: 'Tema $id',
      artist: artist,
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: '',
      source: TrackSource.youtube,
    );

HistoryEntry _h(Track t, {int count = 1, int minutesAgo = 0}) =>
    HistoryEntry(track: t, lastPlayed: DateTime(2026, 10, 17, 12).subtract(Duration(minutes: minutesAgo)), playCount: count);

Map<String, dynamic> _artistRun(String name) => {
      'text': name,
      'navigationEndpoint': {
        'browseEndpoint': {
          'browseId': 'UC$name',
          'browseEndpointContextSupportedConfigs': {
            'browseEndpointContextMusicConfig': {'pageType': 'MUSIC_PAGE_TYPE_ARTIST'},
          },
        },
      },
    };

void main() {
  group('Lectores de YouTube Music', () {
    test('Radio de un tema (/next): artista enlazado, duración y sin repetidos', () {
      final json = {
        'contents': {
          'tabs': [
            {
              'playlistPanelRenderer': {
                'contents': [
                  for (final id in ['v1', 'v2', 'v1'])
                    {
                      'playlistPanelVideoRenderer': {
                        'videoId': id,
                        'title': {
                          'runs': [
                            {'text': 'Canción $id'},
                          ],
                        },
                        'longBylineText': {
                          'runs': [
                            _artistRun('Banda Inventada'),
                            {'text': ' • '},
                            {'text': '1 M de visualizaciones'},
                          ],
                        },
                        'lengthText': {
                          'runs': [
                            {'text': '3:28'},
                          ],
                        },
                        'thumbnail': {
                          'thumbnails': [
                            {'url': 'chica'},
                            {'url': 'grande'},
                          ],
                        },
                      },
                    },
                ],
              },
            },
          ],
        },
      };
      final tracks = parseNextTracks(json);
      expect([for (final t in tracks) t.videoId], ['v1', 'v2']);
      expect(tracks.first.artist, 'Banda Inventada');
      expect(tracks.first.durationMs, 208000);
      expect(tracks.first.thumbnailUrl, 'grande');
    });

    test('Géneros y ánimos: primero los ánimos, después los géneros', () {
      Map<String, dynamic> button(String title, String params) => {
            'musicNavigationButtonRenderer': {
              'buttonText': {
                'runs': [
                  {'text': title},
                ],
              },
              'solid': {'leftStripeColor': 4288988671},
              'clickCommand': {
                'browseEndpoint': {'browseId': 'FEmusic_moods_and_genres_category', 'params': params},
              },
            },
          };
      final moods = parseMoods({
        'contents': [
          {
            'gridRenderer': {
              'items': [button('Calma', 'p1'), button('Energía', 'p2')],
            },
          },
          {
            'gridRenderer': {
              'items': [button('Rock', 'p3')],
            },
          },
        ],
      });
      expect([for (final m in moods) (m.title, m.isGenre)], [('Calma', false), ('Energía', false), ('Rock', true)]);
      expect(moods.first.params, 'p1');
      expect(moods.first.color, 4288988671);
    });

    test('Categoría: carruseles de playlists, sin el prefijo VL', () {
      final shelves = parseMoodCategory({
        'contents': [
          {
            'musicCarouselShelfRenderer': {
              'header': {
                'musicCarouselShelfBasicHeaderRenderer': {
                  'title': {
                    'runs': [
                      {'text': 'Para relajarse'},
                    ],
                  },
                },
              },
              'contents': [
                {
                  'musicTwoRowItemRenderer': {
                    'title': {
                      'runs': [
                        {'text': 'Mezcla tranquila'},
                      ],
                    },
                    'navigationEndpoint': {
                      'browseEndpoint': {
                        'browseId': 'VLRDCLAKxyz',
                        'browseEndpointContextSupportedConfigs': {
                          'browseEndpointContextMusicConfig': {'pageType': 'MUSIC_PAGE_TYPE_PLAYLIST'},
                        },
                      },
                    },
                  },
                },
              ],
            },
          },
        ],
      });
      expect(shelves.single.title, 'Para relajarse');
      expect(shelves.single.playlists.single.playlistId, 'RDCLAKxyz');
      expect(shelves.single.playlists.single.title, 'Mezcla tranquila');
    });
  });

  group('Inicio (lógica en el teléfono)', () {
    test('Usuario nuevo: sin semillas (Inicio muestra "Para empezar")', () {
      expect(HomeFeedLogic.seeds(const [], const []).all, isEmpty);
    });

    test('Semillas: la última que sonó, las más escuchadas y un me gusta', () {
      final a = _yt('a'), b = _yt('b', artist: 'Artista B'), c = _yt('c'), liked = _yt('l', artist: 'Otro');
      final local = Track(
        id: 'local-1',
        title: 'Archivo',
        artist: 'Yo',
        coverColor: const Color(0xFF000000),
        audioUrl: '/x.mp3',
        source: TrackSource.local,
      );
      final seeds = HomeFeedLogic.seeds(
        [_h(local, minutesAgo: 0), _h(a, minutesAgo: 1), _h(b, count: 9, minutesAgo: 5), _h(c, count: 3, minutesAgo: 9)],
        [liked],
      );
      expect(seeds.becauseOf?.id, 'yt-a', reason: 'la última de YouTube (los archivos propios no)');
      expect([for (final t in seeds.mix) t.id], ['yt-b', 'yt-c']);
      expect(seeds.discover.first.id, 'yt-l');
      expect(seeds.key, isNotEmpty);
    });

    test('Arma las secciones sin repetir y "Descubre" solo trae nuevas', () {
      final a = _yt('a'), b = _yt('b');
      final history = [_h(a, minutesAgo: 0), _h(b, count: 5, minutesAgo: 3)];
      final seeds = HomeFeedLogic.seeds(history, const []);
      final feed = HomeFeedLogic.build(
        seeds: seeds,
        history: history,
        liked: const [],
        related: {
          'yt-a': [_yt('b'), _yt('n1'), _yt('n2')], // b ya sonó: no va en "Porque escuchaste"
          'yt-b': [_yt('n1'), _yt('n3')],
        },
      );
      expect(feed.becauseOf?.id, 'yt-a');
      expect([for (final t in feed.because) t.id], ['yt-n1', 'yt-n2']);
      expect([for (final t in feed.mix) t.id].first, 'yt-b', reason: 'empieza con tus más escuchadas');
      expect(feed.mix.map((t) => t.id).toSet().length, feed.mix.length, reason: 'sin repetidas');
      final known = {for (final e in history) e.track.id};
      expect(feed.discover.where((t) => known.contains(t.id)), isEmpty);
    });
  });

  group('Búsquedas recientes', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('kiji_busq'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('Arriba la última, sin repetir, con límite, y se guardan', () async {
      final c = ProviderContainer(overrides: [
        searchHistoryProvider.overrideWith(() => SearchHistoryNotifier(directory: () async => dir.path)),
      ]);
      addTearDown(c.dispose);
      final n = c.read(searchHistoryProvider.notifier);
      n.add('rock nacional');
      n.add('Jazz');
      n.add('ROCK NACIONAL');
      n.add('   ');
      expect(c.read(searchHistoryProvider), ['ROCK NACIONAL', 'Jazz']);
      n.remove('Jazz');
      expect(c.read(searchHistoryProvider), ['ROCK NACIONAL']);
      for (var i = 0; i < 30; i++) {
        n.add('búsqueda $i');
      }
      expect(c.read(searchHistoryProvider).length, SearchHistoryNotifier.maxEntries);
      // Se guarda en segundo plano: se espera hasta 3 s (con la PC cargada tarda más).
      final file = File('${dir.path}/search_history.json');
      for (var i = 0; i < 60 && !file.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(file.existsSync(), isTrue);
    });
  });
}
