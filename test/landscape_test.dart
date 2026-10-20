// Celular horizontal: el mini-reproductor y las pestañas van en una sola fila para dejar ver el
// contenido, sin textos cortados.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/app.dart';
import 'package:kiji_player/features/extractor/data/auto_tests.dart';
import 'package:kiji_player/features/recommendations/data/home_feed_provider.dart';
import 'package:kiji_player/features/recommendations/domain/home_feed.dart';
import 'package:kiji_player/features/updates/update_checker.dart';
import 'package:kiji_player/features/yt_music/data/ytm_browse_parser.dart';
import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/screens/shell/pill_nav_bar.dart';
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
        position: Duration(minutes: 1),
        duration: Duration(minutes: 3),
        shuffleEnabled: false,
        isInitialized: true,
        queue: [_track],
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

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    binding.platformDispatcher.clearLocaleTestValue();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    setKijiLocale(const Locale('es'));
  });

  for (final (language, scale) in [('es', 1.0), ('en', 1.0), ('es', 1.3), ('en', 1.3)]) {
    testWidgets('Horizontal en "$language" con letra x$scale: una sola fila abajo', (tester) async {
      tester.view.physicalSize = const Size(2400, 1080); // 800 × 360 dp
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      binding.platformDispatcher.localeTestValue = Locale(language);
      binding.platformDispatcher.textScaleFactorTestValue = scale;

      await tester.pumpWidget(_app());
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final mini = tester.getRect(find.byType(MiniPlayer));
      final pill = tester.getRect(find.byType(PillNavBar));
      expect((mini.center.dy - pill.center.dy).abs(), lessThan(20), reason: 'en la misma fila');
      expect(pill.left, greaterThan(mini.right - 1), reason: 'la pestaña a la derecha');
      final top = mini.top < pill.top ? mini.top : pill.top;
      expect(360 - top, lessThan(100), reason: 'la barra de abajo deja ver el contenido');

      for (final icon in [Icons.search_rounded, Icons.library_music_rounded, Icons.home_rounded]) {
        await tester.tap(find.byIcon(icon).last);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    });
  }

  testWidgets('Vertical sigue como antes: mini-reproductor arriba de las pestañas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.getRect(find.byType(MiniPlayer)).bottom, lessThan(tester.getRect(find.byType(PillNavBar)).top));
  });
}
