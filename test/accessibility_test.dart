import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/downloads/data/auto_downloads.dart';
import 'package:kiji_player/features/downloads/presentation/batch_download_progress.dart';
import 'package:kiji_player/features/favorites/favorites.dart';
import 'package:kiji_player/features/local_library/presentation/local_library_screen.dart';
import 'package:kiji_player/features/lyrics/domain/screen_mode.dart';
import 'package:kiji_player/features/lyrics/data/screen_mode_impl.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/theater/data/theater_store.dart';
import 'package:kiji_player/features/theater/presentation/theater_effects.dart';
import 'package:kiji_player/features/theater/presentation/theater_screen.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/screens/player/player_screen.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

// Datos inventados.
const _track = Track(
  id: 'yt-inventada',
  title: 'Una canción inventada con un título largo',
  artist: 'Grupo Inventado',
  coverColor: Color(0xFF3A6EA5),
  audioUrl: '',
  source: TrackSource.youtube,
);

class _Playback extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
    track: _track,
    isPlaying: false,
    position: Duration(seconds: 30),
    duration: Duration(minutes: 3),
    shuffleEnabled: false,
    isInitialized: true,
    queue: [],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
}

class _Mode implements ScreenMode {
  @override
  Future<void> setFullScreen(bool on) async {}
}

class _Favorites extends FavoritesNotifier {
  @override
  Map<String, Track> build() => const {};
}

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

/// Texto agrandado al 130 % (Ajustes del teléfono).
Widget _big(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
    child: child,
  ),
);

void main() {
  tearDown(() {
    KijiLook.style = KijiStyle.nocturne;
    KijiColors.palette = KijiPalette.nocturne;
  });

  testWidgets('Pestañas de la Biblioteca: 48 px para tocar y con nombre para los lectores', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryTabs(selected: LibraryTab.songs, onChanged: (_) {}, counts: const {LibraryTab.songs: 3}),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('🍅 y 🌹: 48 px y con nombre', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk))],
        child: const MaterialApp(home: Scaffold(body: Center(child: TheaterButtons(track: _track)))),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  for (final style in KijiStyle.values) {
    testWidgets('Texto al 130 % en ${style.name}: reproductor, pestañas, descarga de varias y Tu Teatro sin desbordes', (
      tester,
    ) async {
      KijiLook.style = style;
      KijiColors.palette = KijiPalette.forStyle(style);
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
      addTearDown(() => FlutterError.onError = previous);

      final container = ProviderContainer(overrides: [
        playbackProvider.overrideWith(_Playback.new),
        settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
        screenModeProvider.overrideWithValue(_Mode()),
        favoritesProvider.overrideWith(_Favorites.new),
        theaterProvider.overrideWith(() => TheaterNotifier(directory: _noDisk)),
        batchProgressProvider.overrideWithValue(
          const BatchProgress(done: 2, failed: 1, total: 12, fraction: 0.3, waitingReason: 'Con el ahorro de datos, esperan al WiFi.'),
        ),
      ]);
      addTearDown(container.dispose);
      for (final screen in <Widget>[
        const PlayerScreen(),
        Scaffold(
          body: Column(
            children: [
              LibraryTabs(selected: LibraryTab.albums, onChanged: (_) {}, counts: const {LibraryTab.songs: 1200}),
              const BatchDownloadProgress(),
            ],
          ),
        ),
        const TheaterScreen(),
      ]) {
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: MaterialApp(home: _big(screen))),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      container.read(theaterProvider.notifier).tomato(_track);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(home: _big(const TheaterScreen()))));
      await tester.pump();
      FlutterError.onError = previous;
      expect(errors.where((e) => e.contains('overflowed')), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
