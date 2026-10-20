// En inglés y con letra grande nada se tiene que cortar: si un texto no entra, Flutter avisa
// "A RenderFlex overflowed…" y la prueba falla.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/app.dart';
import 'package:kiji_player/features/extractor/data/auto_tests.dart';
import 'package:kiji_player/features/recommendations/data/home_feed_provider.dart';
import 'package:kiji_player/features/recommendations/domain/home_feed.dart';
import 'package:kiji_player/features/settings/presentation/settings_screen.dart';
import 'package:kiji_player/features/updates/update_checker.dart';
import 'package:kiji_player/features/yt_music/data/ytm_browse_parser.dart';
import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/widgets/global_mini_player.dart';
import 'package:kiji_player/widgets/mini_player.dart';

const _track = Track(
  id: 'local-1',
  title: 'A Fairly Long Invented Song Title For Testing',
  artist: 'An Invented Artist With A Long Name',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '/storage/emulated/0/Music/test.mp3',
  source: TrackSource.local,
);

class _NoAutoTests extends ExtractorAutoTests {
  _NoAutoTests(super.ref);
  @override
  Future<void> start() async {}
}

class _NoUpdates extends UpdateNotifier {
  @override
  Future<void> checkIfDue() async {}
}

class _Playing extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
        track: _track,
        isPlaying: true,
        position: Duration(minutes: 1, seconds: 23),
        duration: Duration(minutes: 3, seconds: 45),
        shuffleEnabled: false,
        isInitialized: true,
        queue: [_track, _track],
        currentIndex: 0,
        repeatMode: PlaybackRepeatMode.off,
      );
}

Widget _app() => ProviderScope(
      overrides: [
        playbackProvider.overrideWith(_Playing.new),
        homeFeedProvider.overrideWith((ref) async => const HomeFeed()),
        moodsProvider.overrideWith((ref) async => const <YtMood>[]),
        updateProvider.overrideWith(_NoUpdates.new),
        extractorAutoTestsProvider.overrideWith(_NoAutoTests.new),
      ],
      child: const KijiApp(),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    binding.platformDispatcher.clearLocaleTestValue();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    setKijiLocale(const Locale('es'));
  });

  for (final (language, scale) in [('en', 1.0), ('en', 1.3), ('es', 1.3), ('en', 1.6), ('es', 1.6)]) {
    testWidgets('Celular en "$language" con letra x$scale: Inicio, Buscar, Biblioteca, reproductor y '
        'Configuración sin textos cortados', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340); // 360 × 780 dp, un celular chico
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      binding.platformDispatcher.localeTestValue = Locale(language);
      binding.platformDispatcher.textScaleFactorTestValue = scale;

      await tester.pumpWidget(_app());
      await _settle(tester);
      expect(kijiLanguage, language);

      for (final icon in [Icons.search_rounded, Icons.library_music_rounded, Icons.home_rounded]) {
        await tester.tap(find.byIcon(icon).last);
        await _settle(tester);
      }

      // El reproductor.
      await tester.tap(find.descendant(of: find.byType(MiniPlayer), matching: find.text(_track.title)));
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await _settle(tester);

      // Configuración entera, de arriba a abajo.
      SettingsScreen.open(kijiNavigatorKey.currentContext!);
      await _settle(tester);
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 40; i++) {
        await tester.drag(list, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 50));
      }
    });
  }

  testWidgets('Cambiar el idioma en Configuración cambia la pantalla al instante', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    binding.platformDispatcher.localeTestValue = const Locale('es');

    await tester.pumpWidget(_app());
    await _settle(tester);
    SettingsScreen.open(kijiNavigatorKey.currentContext!);
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, 'idioma');
    await _settle(tester);
    await tester.tap(find.text('Idioma').last);
    await _settle(tester);
    await tester.tap(find.text('English'));
    await _settle(tester);

    expect(kijiLanguage, 'en');
    expect(find.text('Language'), findsWidgets); // la misma pantalla, sin reiniciar
    expect(find.text('Idioma'), findsNothing);
  });
}
