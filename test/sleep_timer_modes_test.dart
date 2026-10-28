import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/queue/presentation/queue_screen.dart';
import 'package:kiji_player/features/sleep_timer/domain/sleep_timer_logic.dart';
import 'package:kiji_player/features/sleep_timer/presentation/sleep_timer_sheet.dart';
import 'package:kiji_player/features/sleep_timer/sleep_timer_provider.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

Track _t(String id) => Track(
      id: 'yt-$id',
      title: 'Canción $id',
      artist: 'Artista',
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: '',
      source: TrackSource.youtube,
    );

/// Reproductor falso con una cola a, b, c sonando "a".
class _FakePlayback extends PlaybackNotifier {
  final fades = <double>[];
  int pauses = 0;

  @override
  PlaybackState build() => PlaybackState(
        track: _t('a'),
        isPlaying: true,
        position: Duration.zero,
        duration: const Duration(minutes: 3),
        shuffleEnabled: false,
        isInitialized: true,
        queue: [_t('a'), _t('b'), _t('c')],
        currentIndex: 0,
        repeatMode: PlaybackRepeatMode.off,
      );

  void at(Duration position, {int? index}) => state = state.copyWith(
        position: position,
        currentIndex: index,
        track: index == null ? null : state.queue[index],
      );

  void removeTrack(String id) => state = state.copyWith(
        queue: state.queue.where((t) => t.id != id).toList(),
      );

  @override
  Future<void> pause({String reason = '', Duration? keepAliveFor}) async {
    pauses++;
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> setFadeFactor(double factor) async => fades.add(factor);
}

void main() {
  final now = DateTime(2026, 10, 16, 2);

  group('Lógica de los modos nuevos', () {
    test('"Hasta una canción": no se sabe cuánto falta hasta que suena esa', () {
      Duration? left(String current) => SleepTimerLogic.remaining(
            mode: SleepTimerMode.untilTrack,
            now: now,
            position: const Duration(seconds: 100),
            duration: const Duration(seconds: 130),
            isLastInQueue: false,
            currentTrackId: current,
            targetTrackId: 'yt-b',
          );
      expect(left('yt-a'), isNull);
      expect(left('yt-b'), const Duration(seconds: 30));
    });

    test('"Momento exacto": cuenta hasta ese segundo', () {
      expect(
        SleepTimerLogic.remaining(
          mode: SleepTimerMode.atPosition,
          now: now,
          position: const Duration(seconds: 50),
          duration: const Duration(minutes: 3),
          isLastInQueue: false,
          targetPosition: const Duration(seconds: 70),
        ),
        const Duration(seconds: 20),
      );
      expect(SleepTimerLogic.shouldStop(SleepTimerMode.atPosition, Duration.zero), isTrue);
      expect(SleepTimerLogic.shouldStop(SleepTimerMode.atPosition, const Duration(milliseconds: 300)), isFalse);
    });

    test('Motivos para apagarse solo', () {
      expect(
        SleepTimerLogic.cancelReason(
          mode: SleepTimerMode.untilTrack,
          queueIds: ['yt-a', 'yt-c'],
          targetTrackId: 'yt-b',
          targetTitle: 'Canción b',
        ),
        contains('Se quitó «Canción b» de la cola'),
      );
      expect(
        SleepTimerLogic.cancelReason(
          mode: SleepTimerMode.atPosition,
          queueIds: ['yt-a'],
          currentTrackId: 'yt-c',
          targetTrackId: 'yt-a',
        ),
        contains('Cambió la canción'),
      );
      expect(
        SleepTimerLogic.cancelReason(mode: SleepTimerMode.minutes, queueIds: const []),
        isNull,
      );
    });

    test('Desvanecimiento de 30 s, o menos si falta poco (sin saltos)', () {
      expect(SleepTimerLogic.fadeWindowFor(const Duration(minutes: 2)), const Duration(seconds: 30));
      final short = SleepTimerLogic.fadeWindowFor(const Duration(seconds: 10));
      expect(short, const Duration(seconds: 10));
      expect(SleepTimerLogic.fadeFactor(const Duration(seconds: 10), window: short), 1);
      expect(SleepTimerLogic.fadeFactor(const Duration(seconds: 5), window: short), closeTo(0.5, 0.001));
    });

    test('Momento por defecto: 1 minuto antes del final', () {
      expect(SleepTimerLogic.defaultTargetPosition(const Duration(minutes: 4)), const Duration(minutes: 3));
      expect(SleepTimerLogic.defaultTargetPosition(const Duration(seconds: 40)), Duration.zero);
    });

    test('El botón dice qué modo está activo si todavía no se sabe cuánto falta', () {
      expect(sleepTimerButtonLabel(null), 'Temporizador');
      expect(
        sleepTimerButtonLabel(const SleepTimerState(mode: SleepTimerMode.untilTrack)),
        'Hasta canción',
      );
      expect(
        sleepTimerButtonLabel(const SleepTimerState(
          mode: SleepTimerMode.minutes,
          remaining: Duration(minutes: 4, seconds: 5),
        )),
        '4:05',
      );
    });
  });

  group('Temporizador con el reproductor', () {
    testWidgets('Si se quita de la cola la canción elegida, se apaga y avisa', (tester) async {
      final playback = _FakePlayback();
      final container = ProviderContainer(overrides: [playbackProvider.overrideWith(() => playback)]);
      addTearDown(container.dispose);
      container.read(playbackProvider);

      container.read(sleepTimerProvider.notifier).startUntilTrack(_t('b'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(sleepTimerProvider)?.mode, SleepTimerMode.untilTrack);

      playback.removeTrack('yt-b');
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(sleepTimerProvider), isNull);
      expect(playback.pauses, 0, reason: 'la música sigue');
      expect(playback.fades.last, 1);
      expect(container.read(playbackNoticeProvider)?.message, contains('Se quitó'));
    });

    testWidgets('"Hasta esta canción": pausa al terminar la elegida, no antes', (tester) async {
      final playback = _FakePlayback();
      final container = ProviderContainer(overrides: [playbackProvider.overrideWith(() => playback)]);
      addTearDown(container.dispose);
      container.read(playbackProvider);

      container.read(sleepTimerProvider.notifier).startUntilTrack(_t('b'));
      playback.at(const Duration(minutes: 2, seconds: 59, milliseconds: 900)); // termina "a"
      await tester.pump(const Duration(milliseconds: 300));
      expect(playback.pauses, 0, reason: 'todavía no suena la elegida');

      playback.at(const Duration(minutes: 2, seconds: 59, milliseconds: 900), index: 1); // fin de "b"
      await tester.pump(const Duration(milliseconds: 300));
      expect(playback.pauses, 1);
    });

    testWidgets('Momento exacto con poco tiempo: el volumen empieza en 1 (sin saltos)', (tester) async {
      final playback = _FakePlayback();
      final container = ProviderContainer(overrides: [playbackProvider.overrideWith(() => playback)]);
      addTearDown(container.dispose);
      container.read(playbackProvider);

      playback.at(const Duration(seconds: 50));
      container.read(sleepTimerProvider.notifier).startAtPosition(const Duration(seconds: 60));
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(sleepTimerProvider)?.fadeWindow, const Duration(seconds: 10));
      expect(playback.fades.last, 1);

      playback.at(const Duration(seconds: 55));
      await tester.pump(const Duration(milliseconds: 300));
      expect(playback.fades.last, closeTo(0.5, 0.01));

      playback.at(const Duration(seconds: 60));
      await tester.pump(const Duration(milliseconds: 300));
      expect(playback.pauses, 1);
    });

    testWidgets('"En X minutos" acepta de 1 a 600', (tester) async {
      final playback = _FakePlayback();
      final container = ProviderContainer(overrides: [playbackProvider.overrideWith(() => playback)]);
      addTearDown(container.dispose);
      container.read(playbackProvider);
      final timer = container.read(sleepTimerProvider.notifier)..clock = (() => now);

      timer.start(SleepTimerMode.minutes, minutes: 9999);
      expect(container.read(sleepTimerProvider)!.endsAt, now.add(const Duration(minutes: 600)));
      timer.start(SleepTimerMode.minutes, minutes: 0);
      expect(container.read(sleepTimerProvider)!.endsAt, now.add(const Duration(minutes: 1)));
      await timer.cancel();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  testWidgets('La cola marca con una luna la canción elegida', (tester) async {
    final playback = _FakePlayback();
    await tester.pumpWidget(ProviderScope(
      overrides: [playbackProvider.overrideWith(() => playback)],
      child: const MaterialApp(home: Scaffold(body: QueueList())),
    ));
    expect(find.byIcon(Icons.bedtime_rounded), findsNothing);

    final container = ProviderScope.containerOf(tester.element(find.byType(QueueList)));
    container.read(sleepTimerProvider.notifier).startUntilTrack(_t('b'));
    await tester.pump(const Duration(milliseconds: 300));
    // Luna en el subtítulo y en el botón ⋮ de esa fila.
    expect(find.byIcon(Icons.bedtime_rounded), findsNWidgets(2));

    await container.read(sleepTimerProvider.notifier).cancel();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.bedtime_rounded), findsNothing);
  });
}
