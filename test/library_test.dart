import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/downloads/data/auto_downloads.dart';
import 'package:kiji_player/features/downloads/presentation/batch_download_progress.dart';

import 'package:kiji_player/features/local_library/domain/library_order.dart';
import 'package:kiji_player/features/local_library/presentation/local_library_screen.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

Track _t(String id, String title, String artist, int seconds, {bool local = false}) => Track(
  id: id,
  title: title,
  artist: artist,
  coverColor: const Color(0xFF3A6EA5),
  audioUrl: local ? 'C:/musica/$id.mp3' : '',
  source: local ? TrackSource.local : TrackSource.youtube,
  durationMs: seconds * 1000,
);

void main() {
  // Datos inventados.
  final songs = [
    _t('yt-1', 'Zafiro', 'Banda Inventada', 200),
    _t('yt-2', 'Ámbar', 'Coro Ficticio', 0),
    _t('local-1', 'Bruma', 'Ana Inventada', 120, local: true),
    _t('local-2', 'avena', 'Ana Inventada', 90, local: true),
  ];

  test('Biblioteca: el orden de siempre, por título (sin tildes), artista y duración', () {
    List<String> ids(List<Track> l) => [for (final t in l) t.id];
    expect(ids(arrangeLibrarySongs(songs)), ['yt-1', 'yt-2', 'local-1', 'local-2']);
    expect(ids(arrangeLibrarySongs(songs, sort: 'title')), ['yt-2', 'local-2', 'local-1', 'yt-1']);
    expect(ids(arrangeLibrarySongs(songs, sort: 'artist')), ['local-2', 'local-1', 'yt-1', 'yt-2']);
    expect(ids(arrangeLibrarySongs(songs, sort: 'duration')), ['local-2', 'local-1', 'yt-1', 'yt-2'],
        reason: 'la de duración desconocida, al final');
    expect(ids(arrangeLibrarySongs(songs, filter: 'downloaded')), ['yt-1', 'yt-2']);
    expect(ids(arrangeLibrarySongs(songs, filter: 'local', sort: 'title')), ['local-2', 'local-1']);
    expect(songs.first.id, 'yt-1', reason: 'no toca la lista original');
  });

  test('Orden, filtro y vista se recuerdan; un valor raro vuelve al de fábrica', () {
    final s = AppSettings.fromJson(
      const AppSettings().copyWith(librarySort: 'artist', libraryFilter: 'local', libraryView: 'grid').toJson(),
    );
    expect((s.librarySort, s.libraryFilter, s.libraryView), ('artist', 'local', 'grid'));
    final bad = AppSettings.fromJson({'librarySort': 'raro', 'libraryFilter': 3, 'libraryView': 'mosaico'});
    expect((bad.librarySort, bad.libraryFilter, bad.libraryView), ('recent', 'all', 'list'));
    expect(const AppSettings().playerButtonLabels, isTrue, reason: 'los nombres de los botones, de fábrica');
  });

  for (final style in KijiStyle.values) {
    testWidgets('Pestañas de la Biblioteca en ${style.name}: con su cantidad y se cambian', (tester) async {
      KijiLook.style = style;
      KijiColors.palette = KijiPalette.forStyle(style);
      addTearDown(() {
        KijiLook.style = KijiStyle.nocturne;
        KijiColors.palette = KijiPalette.nocturne;
      });
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var tab = LibraryTab.playlists;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  LibraryTabs(
                    selected: tab,
                    counts: const {LibraryTab.songs: 12, LibraryTab.downloads: 3, LibraryTab.playlists: 2},
                    onChanged: (t) => setState(() => tab = t),
                  ),
                  const StorageBar(downloads: 300, cache: 100, total: 1000),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('12'), findsOneWidget);
      await tester.tap(find.byKey(const Key('library-tab-songs')));
      await tester.pump();
      expect(tab, LibraryTab.songs);
      expect(
        find.bySemanticsLabel(RegExp('Canciones')).evaluate().isNotEmpty ||
            find.text('Canciones').evaluate().isNotEmpty,
        isTrue,
      );
      final selected = tester.widget<Semantics>(
        find.ancestor(of: find.byKey(const Key('library-tab-songs')), matching: find.byType(Semantics)).first,
      );
      expect(selected.properties.selected, isTrue);
    });
  }

  for (final style in KijiStyle.values) {
    testWidgets('Descarga de varias en ${style.name}: cuántas van, el avance y por qué esperan', (tester) async {
      KijiLook.style = style;
      KijiColors.palette = KijiPalette.forStyle(style);
      addTearDown(() {
        KijiLook.style = KijiStyle.nocturne;
        KijiColors.palette = KijiPalette.nocturne;
      });
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            batchProgressProvider.overrideWithValue(
              const BatchProgress(done: 1, failed: 1, total: 4, fraction: 0.6, waitingReason: 'Con el ahorro de datos, esperan al WiFi.'),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: BatchDownloadProgress())),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Bajando: 2 de 4'), findsOneWidget);
      expect(find.text('60 %'), findsOneWidget);
      expect(find.textContaining('1 no se pudo bajar'), findsOneWidget);
    });
  }
}
