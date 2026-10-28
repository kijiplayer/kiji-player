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
[01:04.07] The sun is warm today
[01:05.5][01:20.123] Repetida
[00:10.00]
''';

void main() {
  const nl = '\n';
  testWidgets('La línea que suena se resalta y tocar otra línea va a ese momento', (tester) async {
    final playback = _FakePlayback();
    await tester.pumpWidget(ProviderScope(
      overrides: [playbackProvider.overrideWith(() => playback)],
      child: MaterialApp(home: Scaffold(body: SyncedLyricsView(lines: parseLrc(_lrc)))),
    ));
    await tester.pump();

    expect(find.bySemanticsLabel('Ahora: The sun is warm today'), findsOneWidget);

    playback.at(const Duration(minutes: 1, seconds: 6));
    await tester.pump();
    expect(find.bySemanticsLabel('Ahora: Repetida'), findsOneWidget);
    expect(find.bySemanticsLabel('Ahora: The sun is warm today'), findsNothing);

    await tester.pumpAndSettle(); // termina de desplazarse hasta la línea que suena
    await tester.tap(find.text('The sun is warm today'));
    expect(playback.sought, const Duration(minutes: 1, seconds: 4, milliseconds: 70));
  });

  testWidgets('En la PC la línea que suena queda nítida y las lejanas, más transparentes y borrosas', (tester) async {
    final playback = _FakePlayback();
    final lrc = [for (var i = 0; i < 12; i++) '[00:${(i * 2).toString().padLeft(2, '0')}.00] Línea de prueba $i'].join(nl);
    await tester.pumpWidget(ProviderScope(
      overrides: [playbackProvider.overrideWith(() => playback)],
      child: MaterialApp(home: Scaffold(body: SyncedLyricsView(lines: parseLrc(lrc), depth: true))),
    ));
    playback.at(const Duration(seconds: 6)); // la línea 3
    await tester.pump();
    await tester.pumpAndSettle();
    double opacityOf(String text) =>
        tester.widget<AnimatedOpacity>(find.ancestor(of: find.text(text), matching: find.byType(AnimatedOpacity))).opacity;
    expect(opacityOf('Línea de prueba 3'), 1);
    expect(opacityOf('Línea de prueba 4'), lessThan(1));
    expect(opacityOf('Línea de prueba 7'), lessThan(opacityOf('Línea de prueba 4')));
    final blur = find.ancestor(of: find.text('Línea de prueba 7'), matching: find.byType(ImageFiltered));
    expect(blur, findsOneWidget, reason: 'las lejanas, con un leve desenfoque');
  });

  testWidgets('"Volver a la canción" vuelve a la línea que suena aunque te hayas ido muy lejos', (tester) async {
    final playback = _FakePlayback();
    // 200 líneas inventadas, una cada 2 s; la canción va por la 150.
    final lrc = [for (var i = 0; i < 200; i++) '[${(i * 2 ~/ 60).toString().padLeft(2, '0')}:${(i * 2 % 60).toString().padLeft(2, '0')}.00] Línea de prueba $i'].join('\n');
    await tester.pumpWidget(ProviderScope(
      overrides: [playbackProvider.overrideWith(() => playback)],
      child: MaterialApp(home: Scaffold(body: SyncedLyricsView(lines: parseLrc(lrc)))),
    ));
    playback.at(const Duration(seconds: 301));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Ahora: Línea de prueba 150'), findsOneWidget);

    // El usuario sube hasta el principio de la letra.
    for (var i = 0; i < 40; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Línea de prueba 0'), findsOneWidget);
    expect(find.bySemanticsLabel('Ahora: Línea de prueba 150'), findsNothing);

    await tester.tap(find.byKey(const Key('back-to-song')));
    await tester.pumpAndSettle();
    final line = tester.getRect(find.bySemanticsLabel('Ahora: Línea de prueba 150'));
    expect(line.top, inInclusiveRange(0, 600), reason: 'la línea que suena quedó a la vista');
    expect(find.byKey(const Key('back-to-song')), findsNothing, reason: 'retoma el seguimiento');
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
