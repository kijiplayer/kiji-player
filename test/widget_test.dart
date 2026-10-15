import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kiji_player/app.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

const _testTrack = Track(
  id: 'local-1',
  title: 'Midnight Echoes',
  artist: 'Luna Nova',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '/storage/emulated/0/Music/midnight.mp3',
  source: TrackSource.local,
);

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

void main() {
  testWidgets('Sin nada guardado arranca vacío y sin mini-player', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackProvider.overrideWith(EmptyPlaybackNotifier.new),
        ],
        child: const KijiApp(),
      ),
    );

    expect(find.text('Elige una canción'), findsOneWidget);
    expect(find.text('Midnight Echoes'), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('HomeScreen muestra mini-player y estado de reproducción', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackProvider.overrideWith(MockPlaybackNotifier.new),
        ],
        child: const KijiApp(),
      ),
    );

    expect(find.text('Kiji'), findsOneWidget);
    expect(find.text('No hay contenido'), findsOneWidget);
    expect(find.text('Midnight Echoes'), findsOneWidget);
    expect(find.text('Luna Nova'), findsOneWidget);
    expect(find.text('Reproduciendo: Midnight Echoes'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();

    expect(find.text('En pausa: Midnight Echoes'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('MiniPlayer abre PlayerScreen al tocar', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackProvider.overrideWith(MockPlaybackNotifier.new),
        ],
        child: const KijiApp(),
      ),
    );

    await tester.tap(find.text('Midnight Echoes').first);
    await tester.pumpAndSettle();

    expect(find.text('1:23'), findsOneWidget);
    expect(find.text('3:45'), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Kiji'), findsOneWidget);
  });
}
