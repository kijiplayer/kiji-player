import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/favorites/favorites.dart';
import 'package:kiji_player/features/history/listening_history.dart';
import 'package:kiji_player/features/recommendations/domain/home_feed.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/theater/data/theater_store.dart';
import 'package:kiji_player/features/theater/presentation/theater_effects.dart';
import 'package:kiji_player/features/theater/presentation/theater_screen.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

Track _t(String id, {String artist = 'Banda Inventada'}) => Track(
  id: 'yt-$id',
  title: 'Canción $id',
  artist: artist,
  coverColor: const Color(0xFF3A6EA5),
  audioUrl: '',
  source: TrackSource.youtube,
);

class _Favorites extends FavoritesNotifier {
  @override
  Map<String, Track> build() => const {};
  @override
  void toggle(Track track) {
    state = {...state}..update(track.id, (_) => track, ifAbsent: () => track);
  }
}

class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kiji_teatro_'));
  tearDown(() {
    for (var i = 0; i < 20; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        sleep(const Duration(milliseconds: 50));
      }
    }
  });

  ProviderContainer make({DateTime Function()? clock}) {
    final c = ProviderContainer(overrides: [
      theaterProvider.overrideWith(() => TheaterNotifier(directory: () async => dir, clock: clock)),
      favoritesProvider.overrideWith(_Favorites.new),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('Tomates: con el tercero la canción se va (y queda fuera de las recomendaciones)', () async {
    final c = make();
    await c.read(theaterProvider.notifier).loaded;
    final n = c.read(theaterProvider.notifier);
    expect(n.tomato(_t('a')), TomatoResult.counted);
    expect(n.tomato(_t('a')), TomatoResult.counted);
    expect(n.tomato(_t('a')), TomatoResult.booedOff);
    expect(c.read(theaterProvider).booedOff, {'yt-a'});
    n.forgive('yt-a');
    expect(c.read(theaterProvider).booedOff, isEmpty, reason: '"perdonar" la vuelve a recomendar');
  });

  test('Una rosa aplaude y cuenta como "me gusta"', () async {
    final c = make();
    await c.read(theaterProvider.notifier).loaded;
    c.read(theaterProvider.notifier).rose(_t('b'));
    expect(c.read(favoritesProvider).containsKey('yt-b'), isTrue);
    expect(c.read(theaterProvider).songs['yt-b']!.roses, 1);
  });

  test('Tu Teatro: top 5, el artista más abucheado y el peor día (y se guarda en el dispositivo)', () async {
    var now = DateTime(2026, 11, 9, 20);
    final c = make(clock: () => now);
    await c.read(theaterProvider.notifier).loaded;
    final n = c.read(theaterProvider.notifier);
    for (var i = 0; i < 6; i++) {
      for (var k = 0; k <= i; k++) {
        n.tomato(_t('$i', artist: i.isEven ? 'Coro Ficticio' : 'Ana Inventada'));
      }
    }
    now = DateTime(2026, 11, 10, 9);
    n.tomato(_t('x', artist: 'Ana Inventada'));
    final s = c.read(theaterProvider);
    expect(s.topTomatoes().map((e) => e.id), ['yt-5', 'yt-4', 'yt-3', 'yt-2', 'yt-1']);
    expect(s.totalTomatoes, 22);
    expect(s.mostBooedArtist, ('Ana Inventada', 13));
    expect(s.worstDay, (DateTime(2026, 11, 9), 21));
    await n.saved;
    expect(File(p.join(dir.path, 'theater.json')).existsSync(), isTrue);
    // Al reabrir, sigue igual.
    final again = make();
    await again.read(theaterProvider.notifier).loaded;
    expect(again.read(theaterProvider).totalTomatoes, 22);
  });

  test('Inicio no recomienda una canción abucheada', () {
    final booed = _t('mala'), ok = _t('buena');
    final feed = HomeFeedLogic.build(
      seeds: HomeSeeds(becauseOf: _t('semilla')),
      related: {
        'yt-semilla': [booed, ok],
      },
      history: [HistoryEntry(track: booed, playCount: 9, lastPlayed: DateTime(2026, 11, 1))],
      liked: const [],
      booed: {'yt-mala'},
    );
    expect([for (final t in [...feed.because, ...feed.mix, ...feed.discover]) t.id], isNot(contains('yt-mala')));
    expect(feed.because.map((t) => t.id), ['yt-buena']);
  });

  testWidgets('Los botones 🍅 y 🌹 siguen el ajuste (encendido de fábrica)', (tester) async {
    expect(const AppSettings().theaterReactions, isTrue);
    for (final on in [true, false]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(() => _Settings(AppSettings(theaterReactions: on)))],
          child: MaterialApp(home: Scaffold(body: TheaterButtons(track: _t('a')))),
        ),
      );
      expect(find.byKey(const Key('theater-tomato')), on ? findsOneWidget : findsNothing);
      expect(find.byTooltip('Tirar una rosa'), on ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });

  for (final style in KijiStyle.values) {
    testWidgets('Tu Teatro en ${style.name}: las tarjetas se dibujan sin desbordes', (tester) async {
      KijiLook.style = style;
      KijiColors.palette = KijiPalette.forStyle(style);
      addTearDown(() {
        KijiLook.style = KijiStyle.nocturne;
        KijiColors.palette = KijiPalette.nocturne;
      });
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(overrides: [
        theaterProvider.overrideWith(() => TheaterNotifier(directory: () async => dir)),
        favoritesProvider.overrideWith(_Favorites.new),
      ]);
      addTearDown(c.dispose);
      for (var i = 0; i < 5; i++) {
        c.read(theaterProvider.notifier)
          ..tomato(_t('$i'))
          ..rose(_t('r$i'));
      }
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: TheaterScreen())));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Top Tomateadas'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Top Aplaudidas'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
