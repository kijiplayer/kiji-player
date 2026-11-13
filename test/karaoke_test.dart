import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/domain/lyrics.dart';
import 'package:kiji_player/features/lyrics/presentation/karaoke_line.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

// Letras inventadas (nunca letras reales).

class _Playback extends PlaybackNotifier {
  _Playback(this.playing);
  final bool playing;

  @override
  PlaybackState build() => PlaybackState(
    track: const Track(
      id: 'yt-inventada',
      title: 'Inventada',
      artist: 'Grupo Inventado',
      coverColor: Color(0xFF3A6EA5),
      audioUrl: '',
      source: TrackSource.youtube,
    ),
    isPlaying: playing,
    position: const Duration(seconds: 10),
    duration: const Duration(minutes: 3),
    shuffleEnabled: false,
    isInitialized: true,
    queue: const [],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );

  void at(Duration position) => state = state.copyWith(position: position);
}

Future<KaraokeLineState> _pump(WidgetTester tester, LyricLine line, {bool playing = true, bool calm = false, Duration? next}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [playbackProvider.overrideWith(() => _Playback(playing))],
    child: MaterialApp(
      home: Scaffold(
        body: DefaultTextStyle(
          style: const TextStyle(fontSize: 28, color: Colors.white),
          child: KaraokeLine(line: line, next: next, calm: calm),
        ),
      ),
    ),
  ));
  return tester.state<KaraokeLineState>(find.byType(KaraokeLine));
}

double _contrast(Color a, Color b) {
  double channel(double c) => c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) => 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final (l1, l2) = (luminance(a), luminance(b));
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

void main() {
  testWidgets('Mientras suena, la línea se llena de forma suave y se detiene al terminar', (tester) async {
    const line = LyricLine(Duration(seconds: 10), 'Una línea inventada');
    final state = await _pump(tester, line, next: const Duration(seconds: 12));
    expect(state.sung, 0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.sung, closeTo(line.text.length / 2, 1.5), reason: 'a la mitad del tiempo, a la mitad de la línea');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    expect(state.sung, line.text.length);
    await tester.pumpAndSettle(); // ya no hay nada animándose
  });

  testWidgets('En pausa no avanza', (tester) async {
    const line = LyricLine(Duration(seconds: 9), 'Pausa inventada');
    final state = await _pump(tester, line, playing: false, next: const Duration(seconds: 11));
    final before = state.sung;
    await tester.pump(const Duration(seconds: 1));
    expect(state.sung, before);
    await tester.pumpAndSettle();
  });

  testWidgets('Reducir animaciones: sin tiempos por palabra, la línea entera; con ellos, de a palabras', (tester) async {
    const plain = LyricLine(Duration(seconds: 10), 'Sin tiempos');
    expect((await _pump(tester, plain, calm: true)).sung, plain.text.length);

    final words = parseLrc('[00:09.00]<00:09.00>Uno <00:10.00>dos <00:11.00>tres<00:12.00>').single;
    final state = await _pump(tester, words, calm: true);
    // A las 10 s empieza "dos": se pinta entera apenas empieza, sin pedazos de palabra.
    expect(state.sung, 'Uno dos'.length);
    await tester.pumpAndSettle();
  });

  test('Los colores del karaoke se leen sobre el fondo de la letra en los tres estilos', () {
    final background = KijiPalette.nocturne.background; // la letra siempre va sobre el fondo oscuro
    final previous = KijiColors.palette;
    addTearDown(() => KijiColors.palette = previous);
    for (final style in KijiStyle.values) {
      KijiColors.palette = KijiPalette.forStyle(style);
      final colors = karaokeColors(Colors.white);
      expect(_contrast(colors.from, background), greaterThanOrEqualTo(4.5), reason: '${style.name}: inicio');
      expect(_contrast(colors.to, background), greaterThanOrEqualTo(4.5), reason: '${style.name}: final');
    }
  });
}
