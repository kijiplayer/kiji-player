import 'dart:math';
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
import 'package:kiji_player/providers/playback_provider.dart';
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

/// En pausa con [_t('a')]; anota qué se le pidió.
class _PausedPlayback extends PlaybackNotifier {
  final calls = <String>[];
  @override
  PlaybackState build() => PlaybackState(
    track: _t('a'),
    isPlaying: false,
    position: Duration.zero,
    duration: const Duration(minutes: 3),
    shuffleEnabled: false,
    isInitialized: true,
    queue: [_t('a'), _t('b')],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
  @override
  Future<void> skipKeepingPause() async => calls.add('saltar sin sonar');
  @override
  Future<void> nextTrack() async => calls.add('siguiente');
  @override
  Future<void> play() async => calls.add('play');
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

  test('La racha de tomates vuelve a 0 si pasan 10 min sin tirar (los tomates sueltos no abuchean)', () async {
    var now = DateTime(2026, 11, 11, 8);
    final c = make(clock: () => now);
    await c.read(theaterProvider.notifier).loaded;
    final n = c.read(theaterProvider.notifier);
    for (var i = 0; i < 4; i++) {
      expect(n.tomato(_t('a')), TomatoResult.counted, reason: 'uno cada 11 min: nunca 3 seguidos');
      now = now.add(const Duration(minutes: 11));
    }
    expect(c.read(theaterProvider).booedOff, isEmpty);
    expect(c.read(theaterProvider).songs['yt-a']!.tomatoes, 4, reason: '"Tu Teatro" los cuenta igual');
    n.tomato(_t('a'));
    now = now.add(const Duration(minutes: 9));
    n.tomato(_t('a'));
    now = now.add(const Duration(minutes: 9));
    expect(n.tomato(_t('a')), TomatoResult.booedOff);
    await n.saved;
    // Al reabrir sigue abucheada.
    final again = make();
    await again.read(theaterProvider.notifier).loaded;
    expect(again.read(theaterProvider).booedOff, {'yt-a'});
  });

  test('Datos guardados antes de la racha: 3 tomates o más sigue abucheada', () {
    expect(TheaterEntry.fromJson('yt-v', {'title': 'Vieja', 'tomatoes': 3})!.booed, isTrue);
    expect(TheaterEntry.fromJson('yt-w', {'title': 'Vieja', 'tomatoes': 2})!.booed, isFalse);
    expect(TheaterEntry.fromJson('yt-x', {'title': 'Nueva', 'tomatoes': 5, 'booed': false})!.booed, isFalse);
  });

  test('Sacudida: hacen falta 3 golpes fuertes y separados en menos de 1 s (caminar o el bolsillo no)', () {
    var now = DateTime(2026, 11, 11, 8);
    final d = ShakeDetector(clock: () => now);
    void step(int ms) => now = now.add(Duration(milliseconds: ms));
    // Caminar / bolsillo: muchos movimientos de 12–20 m/s².
    for (var i = 0; i < 200; i++) {
      step(20);
      expect(d.add(i.isEven ? 18 : 4, 6, 3), isFalse);
    }
    // Un golpe fuerte que se mantiene no cuenta como 3.
    for (var i = 0; i < 10; i++) {
      step(20);
      expect(d.add(30, 0, 0), isFalse);
    }
    d.add(0, 0, 0);
    // Dos golpes y una pausa larga: tampoco.
    step(200);
    expect(d.add(30, 0, 0), isFalse);
    step(100);
    d.add(0, 0, 0);
    step(1200);
    expect(d.add(30, 0, 0), isFalse);
    // Tres golpes claros, cada uno separado: sí.
    var shook = false;
    for (var i = 0; i < 3; i++) {
      step(150);
      shook = d.add(0, 28, 0) || shook;
      step(150);
      d.add(0, 2, 0);
    }
    expect(shook, isTrue);
    // Y enseguida, nada (espera entre una sacudida y otra).
    for (var i = 0; i < 3; i++) {
      step(100);
      expect(d.add(0, 28, 0), isFalse);
      step(100);
      d.add(0, 2, 0);
    }
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

  test('El cartel de Tu Teatro se lee en los tres estilos (4,5:1 o más)', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
    }

    addTearDown(() => KijiLook.style = KijiStyle.nocturne);
    for (final style in KijiStyle.values) {
      KijiLook.style = style;
      expect(ratio(KijiColors.theaterPosterInk, KijiColors.theaterPosterPaper), greaterThanOrEqualTo(4.5), reason: '${style.name}: tinta');
      expect(ratio(KijiColors.theaterPosterAccent, KijiColors.theaterPosterPaper), greaterThanOrEqualTo(4.5), reason: '${style.name}: dorado/rojo');
    }
  });

  test('Premio «más odiada del mes»: solo cuenta lo de este mes', () async {
    var now = DateTime(2026, 10, 20);
    final c = make(clock: () => now);
    await c.read(theaterProvider.notifier).loaded;
    final n = c.read(theaterProvider.notifier);
    for (var i = 0; i < 4; i++) {
      n.tomato(_t('vieja'));
    }
    now = DateTime(2026, 11, 3);
    n.tomato(_t('nueva'));
    n.tomato(_t('nueva'));
    expect(c.read(theaterProvider).mostHatedOfMonth(DateTime(2026, 11, 12))?.id, 'yt-nueva');
    expect(c.read(theaterProvider).mostHatedOfMonth(DateTime(2026, 12, 1)), isNull);
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

  testWidgets('El tercer tomate en pausa saltea la canción sin hacerla sonar', (tester) async {
    final playback = _PausedPlayback();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _Settings(const AppSettings())),
          playbackProvider.overrideWith(() => playback),
          theaterProvider.overrideWith(() => TheaterNotifier(directory: () async => dir)),
          favoritesProvider.overrideWith(_Favorites.new),
        ],
        child: MaterialApp(home: Scaffold(body: TheaterButtons(track: _t('a')))),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('theater-tomato')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(playback.calls, ['saltar sin sonar']);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
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
      expect(find.text('EN CARTELERA'), findsOneWidget);
      for (final title in ['LAS MÁS ABUCHEADAS DE LA TEMPORADA', 'TOP APLAUDIDAS', 'LOS PREMIOS DEL PÚBLICO']) {
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
