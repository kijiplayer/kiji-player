import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/domain/lyrics.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_screen.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

// Archivo aparte: con testWidgets, flutter_test reemplaza el cliente HTTP por
// uno falso, y las pruebas de LRCLIB (test/lyrics_test.dart) usan red local real.

const _lrc = '''
[01:04.07] Around the world
[01:05.5][01:20.123] Repetida
[00:10.00]
''';

void main() {
  testWidgets('La línea que suena se resalta y tocar otra línea va a ese momento', (tester) async {
    final playback = _FakePlayback();
    await tester.pumpWidget(ProviderScope(
      overrides: [playbackProvider.overrideWith(() => playback)],
      child: MaterialApp(home: Scaffold(body: SyncedLyricsView(lines: parseLrc(_lrc)))),
    ));
    await tester.pump();

    expect(find.bySemanticsLabel('Ahora: Around the world'), findsOneWidget);

    playback.at(const Duration(minutes: 1, seconds: 6));
    await tester.pump();
    expect(find.bySemanticsLabel('Ahora: Repetida'), findsOneWidget);
    expect(find.bySemanticsLabel('Ahora: Around the world'), findsNothing);

    await tester.tap(find.text('Around the world'));
    expect(playback.sought, const Duration(minutes: 1, seconds: 4, milliseconds: 70));
  });
}

class _FakePlayback extends PlaybackNotifier {
  Duration? sought;

  @override
  PlaybackState build() => const PlaybackState(
        track: Track(
          id: 'yt-a',
          title: 'Around the World',
          artist: 'Daft Punk',
          coverColor: Color(0xFF7C5CFF),
          audioUrl: '',
          source: TrackSource.youtube,
        ),
        isPlaying: true,
        position: Duration(minutes: 1, seconds: 4, milliseconds: 500),
        duration: Duration(minutes: 7),
        shuffleEnabled: false,
        isInitialized: true,
        queue: [],
        currentIndex: 0,
        repeatMode: PlaybackRepeatMode.off,
      );

  void at(Duration position) => state = state.copyWith(position: position);

  @override
  Future<void> seekTo(Duration position) async => sought = position;
}
