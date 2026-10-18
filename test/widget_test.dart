import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kiji_player/app.dart';
import 'package:kiji_player/features/extractor/data/auto_tests.dart';
import 'package:kiji_player/features/recommendations/data/home_feed_provider.dart';
import 'package:kiji_player/features/recommendations/domain/home_feed.dart';
import 'package:kiji_player/features/updates/update_checker.dart';
import 'package:kiji_player/features/yt_music/data/ytm_browse_parser.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/screens/shell/pill_nav_bar.dart';
import 'package:kiji_player/widgets/mini_player.dart';

const _testTrack = Track(
  id: 'local-1',
  title: 'Midnight Echoes',
  artist: 'Luna Nova',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '/storage/emulated/0/Music/midnight.mp3',
  source: TrackSource.local,
);

/// Sin pruebas del extractor en los tests (salen a internet).
class _NoAutoTests extends ExtractorAutoTests {
  _NoAutoTests(super.ref);
  @override
  Future<void> start() async {}
}

/// Sin consultas a GitHub en los tests.
class _NoUpdates extends UpdateNotifier {
  @override
  Future<void> checkIfDue() async {}
}

/// Simula la app recién instalada: nada guardado, nada sonando.
class EmptyPlaybackNotifier extends PlaybackNotifier {
  @override
  PlaybackState build() => PlaybackState.initial();
}

class MockPlaybackNotifier extends PlaybackNotifier {
  @override
  PlaybackState build() {
    return const PlaybackState(
      track: _testTrack,
      isPlaying: true,
      position: Duration(minutes: 1, seconds: 23),
      duration: Duration(minutes: 3, seconds: 45),
      shuffleEnabled: false,
      isInitialized: true,
      queue: [_testTrack],
      currentIndex: 0,
      repeatMode: PlaybackRepeatMode.off,
    );
  }

  @override
  Future<void> togglePlayPause() async {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  @override
  void toggleShuffle() {
    state = state.copyWith(shuffleEnabled: !state.shuffleEnabled);
  }

  @override
  void toggleRepeatMode() {
    final next = switch (state.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
  }

  @override
  Future<void> seekToProgress(double progress) async {
    final clamped = progress.clamp(0.0, 1.0);
    state = state.copyWith(
      position: Duration(
        milliseconds: (state.duration.inMilliseconds * clamped).round(),
      ),
    );
  }

  @override
  Future<void> previousTrack() async {
    state = state.copyWith(position: Duration.zero);
  }

  @override
  Future<void> nextTrack() async {
    state = state.copyWith(position: Duration.zero, isPlaying: true);
  }
}

/// Avanza la animación de una pantalla nueva sin esperar a que "termine":
/// el anillo del botón play respira mientras suena y nunca se queda quieto.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(Object notifierFactory) => ProviderScope(
      overrides: [
        playbackProvider.overrideWith(notifierFactory as PlaybackNotifier Function()),
        // Sin red en los tests: Inicio sin recomendaciones ni géneros.
        homeFeedProvider.overrideWith((ref) async => const HomeFeed()),
        moodsProvider.overrideWith((ref) async => const <YtMood>[]),
        updateProvider.overrideWith(_NoUpdates.new),
        extractorAutoTestsProvider.overrideWith(_NoAutoTests.new),
      ],
      child: const KijiApp(),
    );

void main() {
  testWidgets('Sin nada guardado arranca vacío y sin mini-player', (WidgetTester tester) async {
    await tester.pumpWidget(_app(EmptyPlaybackNotifier.new));

    expect(find.text('Elige una canción'), findsOneWidget);
    expect(find.text('Midnight Echoes'), findsNothing);
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(
      find.descendant(of: find.byType(MiniPlayer), matching: find.byType(IconButton)),
      findsNothing,
    );
  });

  testWidgets('Inicio: saludo, "Seguí donde quedaste" y mini-player con pausa', (tester) async {
    await tester.pumpWidget(_app(MockPlaybackNotifier.new));
    await tester.pump();

    expect(find.textContaining(RegExp(r'^Buen(os|as) ')), findsOneWidget);
    expect(find.text('SEGUÍ DONDE QUEDASTE'), findsOneWidget);
    final mini = find.byType(MiniPlayer);
    expect(find.descendant(of: mini, matching: find.text('Midnight Echoes')), findsOneWidget);
    expect(find.descendant(of: mini, matching: find.text('Luna Nova')), findsOneWidget);

    final pause = find.descendant(of: mini, matching: find.byIcon(Icons.pause_rounded));
    expect(pause, findsOneWidget);
    await tester.tap(pause);
    await tester.pump();
    expect(find.descendant(of: mini, matching: find.byIcon(Icons.play_arrow_rounded)), findsOneWidget);
  });

  testWidgets('El mini-player abre el reproductor Nocturne', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MockPlaybackNotifier.new));
    await tester.pump();

    await tester.tap(find.descendant(of: find.byType(MiniPlayer), matching: find.text('Midnight Echoes')));
    await _settle(tester);

    expect(find.text('REPRODUCIENDO DESDE'), findsOneWidget);
    expect(find.text('TU BIBLIOTECA'), findsOneWidget);
    expect(find.text('1:23'), findsOneWidget);
    expect(find.text('3:45'), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    expect(find.text('Cola'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await _settle(tester);
    expect(find.text('REPRODUCIENDO DESDE'), findsNothing);
  });

  testWidgets('PC (1400 px): barra lateral, buscador con Ctrl K y "A continuación"', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(MockPlaybackNotifier.new));
    await tester.pump();

    expect(find.text('TUS LISTAS'), findsOneWidget);
    expect(find.text('SALUD DEL EXTRACTOR'), findsOneWidget);
    expect(find.text('Ctrl K'), findsOneWidget);
    expect(find.text('A continuación'), findsOneWidget);
    expect(find.byType(PillNavBar), findsNothing);
    expect(find.byType(Slider), findsOneWidget); // volumen en la barra del reproductor
  });

  testWidgets('Celular (390 px): píldora abajo, sin barra lateral', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(MockPlaybackNotifier.new));
    await tester.pump();

    expect(find.byType(PillNavBar), findsOneWidget);
    expect(find.text('TUS LISTAS'), findsNothing);
    // La pestaña activa muestra ícono + texto; las otras, solo el ícono.
    expect(find.descendant(of: find.byType(PillNavBar), matching: find.text('Inicio')), findsOneWidget);
    expect(find.descendant(of: find.byType(PillNavBar), matching: find.text('Buscar')), findsNothing);

    await tester.tap(find.byIcon(Icons.search_rounded).last);
    await tester.pump();
    expect(find.descendant(of: find.byType(PillNavBar), matching: find.text('Buscar')), findsOneWidget);
    expect(find.text('Canciones'), findsOneWidget); // chips del buscador
  });
}
