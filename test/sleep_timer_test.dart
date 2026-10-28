import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/sleep_timer/domain/sleep_timer_logic.dart';
import 'package:kiji_player/features/sleep_timer/sleep_timer_provider.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

const _track = Track(
  id: 'yt-a',
  title: 'A',
  artist: 'Artista',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '',
  source: TrackSource.youtube,
);

/// Reproductor falso: guarda pausas y factores de volumen.
class _FakePlayback extends PlaybackNotifier {
  final fades = <double>[];
  int pauses = 0;

  @override
  PlaybackState build() => const PlaybackState(
        track: _track,
        isPlaying: true,
        position: Duration.zero,
        duration: Duration(minutes: 3),
        shuffleEnabled: false,
        isInitialized: true,
        queue: [_track, _track],
        currentIndex: 0,
        repeatMode: PlaybackRepeatMode.off,
      );

  void at(Duration position, {int index = 0}) =>
      state = state.copyWith(position: position, currentIndex: index);

  @override
  Future<void> pause({String reason = '', Duration? keepAliveFor}) async {
    pauses++;
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> setFadeFactor(double factor) async => fades.add(factor);
}

void main() {
  group('Cuánto falta', () {
    final now = DateTime(2026, 10, 16, 1);

    test('En X minutos: cuenta con el reloj', () {
      expect(
        SleepTimerLogic.remaining(
          mode: SleepTimerMode.minutes,
          now: now,
          endsAt: now.add(const Duration(minutes: 10)),
          position: Duration.zero,
          duration: Duration.zero,
          isLastInQueue: false,
        ),
        const Duration(minutes: 10),
      );
    });

    test('Al terminar esta canción: lo que le falta a la canción', () {
      expect(
        SleepTimerLogic.remaining(
          mode: SleepTimerMode.endOfTrack,
          now: now,
          position: const Duration(seconds: 50),
          duration: const Duration(minutes: 1),
          isLastInQueue: false,
        ),
        const Duration(seconds: 10),
      );
    });

    test('Al terminar la cola: no se sabe hasta la última canción', () {
      Duration? left(bool last) => SleepTimerLogic.remaining(
            mode: SleepTimerMode.endOfQueue,
            now: now,
            position: const Duration(seconds: 50),
            duration: const Duration(minutes: 1),
            isLastInQueue: last,
          );
      expect(left(false), isNull);
      expect(left(true), const Duration(seconds: 10));
    });
  });

  test('El volumen baja de a poco en los últimos 30 segundos', () {
    expect(SleepTimerLogic.fadeFactor(null), 1);
    expect(SleepTimerLogic.fadeFactor(const Duration(minutes: 5)), 1);
    expect(SleepTimerLogic.fadeFactor(const Duration(seconds: 30)), 1);
    expect(SleepTimerLogic.fadeFactor(const Duration(seconds: 15)), closeTo(0.5, 0.001));
    expect(SleepTimerLogic.fadeFactor(Duration.zero), 0);
  });

  test('Formato de lo que falta', () {
    expect(SleepTimerLogic.format(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(SleepTimerLogic.format(const Duration(seconds: 9)), '0:09');
    expect(SleepTimerLogic.format(const Duration(hours: 1, minutes: 2, seconds: 5)), '1:02:05');
  });

  testWidgets('En X minutos: baja el volumen, pausa, devuelve el volumen y avisa', (tester) async {
    final playback = _FakePlayback();
    final container = ProviderContainer(overrides: [playbackProvider.overrideWith(() => playback)]);
    addTearDown(container.dispose);
    container.read(playbackProvider);

    var now = DateTime(2026, 10, 16, 1);
    final timer = container.read(sleepTimerProvider.notifier)..clock = (() => now);
    timer.start(SleepTimerMode.minutes, minutes: 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(playback.fades.last, 1, reason: 'falta 1 minuto: volumen normal');

    now = now.add(const Duration(seconds: 45)); // faltan 15 s
    await tester.pump(const Duration(milliseconds: 300));
    expect(playback.fades.last, closeTo(0.5, 0.01));
    expect(playback.pauses, 0);

    now = now.add(const Duration(seconds: 15)); // llegó
    await tester.pump(const Duration(milliseconds: 300));
    expect(playback.pauses, 1);
    expect(playback.fades.last, 1, reason: 'el volumen vuelve a la normalidad');
    expect(container.read(sleepTimerProvider), isNull);
    expect(container.read(playbackNoticeProvider)?.message, contains('Temporizador'));
  });

  testWidgets('Al terminar esta canción: pausa antes de que arranque la siguiente', (tester) async {
    final playback = _FakePlayback();
    final container = ProviderContainer(overrides: [playbackProvider.overrideWith(() => playback)]);
    addTearDown(container.dispose);
    container.read(playbackProvider);

    container.read(sleepTimerProvider.notifier).start(SleepTimerMode.endOfTrack);
    playback.at(const Duration(minutes: 2, seconds: 59, milliseconds: 800)); // faltan 0,2 s
    await tester.pump(const Duration(milliseconds: 300));
    expect(playback.pauses, 1);
    expect(container.read(sleepTimerProvider), isNull);
  });

  testWidgets('Apagar el temporizador deja la música sonando con su volumen', (tester) async {
    final playback = _FakePlayback();
    final container = ProviderContainer(overrides: [playbackProvider.overrideWith(() => playback)]);
    addTearDown(container.dispose);
    container.read(playbackProvider);

    final timer = container.read(sleepTimerProvider.notifier);
    timer.start(SleepTimerMode.endOfQueue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(sleepTimerProvider)?.remaining, isNull, reason: 'no es la última canción');

    await timer.cancel();
    expect(playback.pauses, 0);
    expect(playback.fades.last, 1);
    expect(container.read(sleepTimerProvider), isNull);
  });
}
