import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/loudness/domain/loudness.dart';
import 'package:kiji_player/widgets/nocturne/waveform_progress.dart';

/// 1 s de silencio, 1 s de un tono fuerte y 1 s de uno suave, a 8 kHz.
Int16List _pcm() {
  const rate = 8000;
  final samples = Int16List(rate * 3);
  for (var i = rate; i < rate * 3; i++) {
    final amplitude = i < rate * 2 ? 30000 : 900;
    samples[i] = (amplitude * sin(2 * pi * 220 * i / rate)).round();
  }
  return samples;
}

void main() {
  test('la envolvente sigue al volumen: silencio, fuerte y suave', () {
    final levels = envelopeFromPcm16(_pcm(), 8000);
    expect(levels.length, 75, reason: '3 s en pasos de 40 ms');
    expect(levels[10], 0, reason: 'silencio');
    expect(levels[35], greaterThan(230), reason: 'tono fuerte, cerca de 0 dB');
    expect(levels[60], inInclusiveRange(80, 140), reason: 'tono suave, unos −33 dB');
  });

  test('Loudness: relativo a la canción, interpola y sostiene los golpes', () {
    final loud = Loudness(envelopeFromPcm16(_pcm(), 8000));
    expect(loud.at(const Duration(milliseconds: 500)), 0);
    expect(loud.at(const Duration(milliseconds: 1500)), closeTo(1, 0.01));
    expect(loud.at(const Duration(milliseconds: 2500)), lessThan(0.5));
    // Justo después del tono fuerte todavía se ve el golpe (baja en ~120 ms).
    expect(loud.at(const Duration(milliseconds: 2010)), greaterThan(0.5));
    expect(loud.at(const Duration(milliseconds: 2200)), lessThan(0.3), reason: 'y después baja');
    expect(loud.at(const Duration(seconds: 30)), 0, reason: 'fuera de la canción');
  });

  test('barras en vivo: cerca de la posición saltan con el volumen; lejos, como siempre', () {
    double h(int index, double level) => liveBarHeight(base: 0.5, index: index, playhead: 20, level: level);
    expect(h(20, 1), greaterThan(0.9));
    expect(h(20, 0), lessThan(0.5), reason: 'suave: casi quieta');
    expect(h(20, 1) - h(20, 0), greaterThan(h(24, 1) - h(24, 0)), reason: 'salta más cerca');
    expect(h(60, 1), closeTo(0.5, 0.001), reason: 'lejos no cambia');
  });

  testWidgets('la onda en vivo se dibuja y se detiene en pausa', (tester) async {
    final loud = Loudness(envelopeFromPcm16(_pcm(), 8000));
    Widget wave({required bool alive}) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: WaveformProgress(
                seed: 'yt-x',
                progress: 0.5,
                position: const Duration(milliseconds: 1500),
                loudness: loud,
                alive: alive,
                onSeek: (_) {},
              ),
            ),
          ),
        );
    await tester.pumpWidget(wave(alive: true));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(wave(alive: false));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
