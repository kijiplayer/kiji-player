import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/sleep_timer/domain/sleep_timer_logic.dart';
import 'package:kiji_player/features/sleep_timer/presentation/sleep_timer_sheet.dart';
import 'package:kiji_player/features/sleep_timer/presentation/timer_waveform.dart';
import 'package:kiji_player/features/sleep_timer/sleep_timer_provider.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/widgets/nocturne/waveform_progress.dart';

Track _t(String id) => Track(
      id: 'yt-$id',
      title: 'Canción $id',
      artist: 'Artista',
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: '',
      source: TrackSource.youtube,
    );

/// Una canción de 1:18, sonando.
class _FakePlayback extends PlaybackNotifier {
  int pauses = 0;
  final seeks = <double>[];

  @override
  PlaybackState build() => PlaybackState(
        track: _t('a'),
        isPlaying: true,
        position: const Duration(seconds: 77),
        duration: const Duration(seconds: 78),
        shuffleEnabled: false,
        isInitialized: true,
        queue: [_t('a')],
        currentIndex: 0,
        repeatMode: PlaybackRepeatMode.off,
      );

  void at(Duration position) => state = state.copyWith(position: position);

  @override
  Future<void> pause() async {
    pauses++;
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> setFadeFactor(double factor) async {}

  @override
  Future<void> seekToProgress(double progress) async => seeks.add(progress);
}

void main() {
  test('momento ya pasado y valor inicial del selector', () {
    expect(SleepTimerLogic.alreadyPassed(const Duration(seconds: 10), const Duration(seconds: 30)), isTrue);
    expect(SleepTimerLogic.alreadyPassed(const Duration(seconds: 30), const Duration(seconds: 30)), isFalse);
    expect(SleepTimerLogic.alreadyPassed(const Duration(seconds: 30), const Duration(milliseconds: 30900)), isFalse);
    // Canción de 3:00 en 0:10: 1 minuto antes del final.
    expect(SleepTimerLogic.defaultDialogPosition(const Duration(minutes: 3), const Duration(seconds: 10)),
        const Duration(minutes: 2));
    // Canción de 1:18 en 1:10: un poco después de donde va, sin pasarse.
    expect(SleepTimerLogic.defaultDialogPosition(const Duration(seconds: 78), const Duration(seconds: 70)),
        const Duration(seconds: 75));
    expect(SleepTimerLogic.defaultDialogPosition(const Duration(seconds: 78), const Duration(seconds: 77)),
        const Duration(seconds: 78));
  });

  testWidgets('el selector va de 0:00 al final (antes: solo 1:17 a 1:18)', (tester) async {
    Duration? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked =
              await showExactMomentDialog(context, const Duration(seconds: 78), const Duration(seconds: 77)),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 0);
    expect(slider.max, 78);

    for (var i = 0; i < 20; i++) {
      await tester.tap(find.text('−5 s'));
    }
    await tester.pumpAndSettle();
    expect(find.text('0:00'), findsOneWidget);
    expect(find.textContaining('Ese momento ya pasó'), findsOneWidget);
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(picked, Duration.zero);
  });

  testWidgets('un momento que ya pasó no pausa de golpe: espera a que la canción vuelva ahí', (tester) async {
    final playback = _FakePlayback();
    final container = ProviderContainer(overrides: [playbackProvider.overrideWith(() => playback)]);
    addTearDown(container.dispose);
    container.read(playbackProvider);

    container.read(sleepTimerProvider.notifier).startAtPosition(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 300));
    expect(playback.pauses, 0);
    expect(container.read(sleepTimerProvider)!.waitingForTarget, isTrue);

    // Vuelve atrás (o se repite): se arma.
    playback.at(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(sleepTimerProvider)!.waitingForTarget, isFalse);
    expect(playback.pauses, 0);

    playback.at(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 300));
    expect(playback.pauses, 1);
  });

  testWidgets('marcar en la onda: el toque elige la pausa (no salta) y aparece la luna', (tester) async {
    final playback = _FakePlayback();
    await tester.pumpWidget(ProviderScope(
      overrides: [playbackProvider.overrideWith(() => playback)],
      child: const MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 300, child: TimerWaveform())))),
    ));
    final element = tester.element(find.byType(TimerWaveform));
    final container = ProviderScope.containerOf(element);
    expect(find.byKey(const Key('waveform-moon')), findsNothing);

    // Sin modo marcar, tocar la onda salta.
    await tester.tapAt(tester.getTopLeft(find.byType(WaveformProgress)) + const Offset(150, 20));
    await tester.pump();
    expect(playback.seeks, hasLength(1));

    container.read(sleepTimerMarkingProvider.notifier).state = true;
    await tester.pump();
    expect(find.text('Tocá la onda donde querés que se pause'), findsOneWidget);
    await tester.tapAt(tester.getTopLeft(find.byType(WaveformProgress)) + const Offset(75, 20));
    await tester.pump(const Duration(milliseconds: 300));

    expect(playback.seeks, hasLength(1), reason: 'en modo marcar no salta');
    final timer = container.read(sleepTimerProvider)!;
    expect(timer.mode, SleepTimerMode.atPosition);
    expect(timer.targetPosition!.inSeconds, closeTo(19.5, 1));
    expect(container.read(sleepTimerMarkingProvider), isFalse);
    expect(find.byKey(const Key('waveform-moon')), findsOneWidget);
    expect(sleepMarkerFraction(timer, playback.state), closeTo(0.25, 0.02));

    await container.read(sleepTimerProvider.notifier).cancel();
    await tester.pump();
    expect(find.byKey(const Key('waveform-moon')), findsNothing);
  });
}
