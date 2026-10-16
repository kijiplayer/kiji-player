import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/queue/domain/queue_operations.dart';
import 'package:kiji_player/features/queue/presentation/queue_screen.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

Track _t(String title) => Track(
      id: 'yt-$title',
      title: title,
      artist: 'Artista',
      coverColor: const Color(0xFF3DF5FF),
      audioUrl: '',
      source: TrackSource.youtube,
    );

/// Reproductor falso: aplica las mismas operaciones puras que el real, sin
/// audio de verdad.
class _FakePlayback extends PlaybackNotifier {
  @override
  PlaybackState build() => PlaybackState(
        track: _t('Uno'),
        isPlaying: true,
        position: Duration.zero,
        duration: Duration.zero,
        shuffleEnabled: false,
        isInitialized: true,
        queue: [_t('Uno'), _t('Dos'), _t('Tres')],
        currentIndex: 0,
        repeatMode: PlaybackRepeatMode.off,
      );

  void _apply(QueueSnapshot q) =>
      state = state.copyWith(queue: q.tracks, currentIndex: q.currentIndex, track: q.current);

  QueueSnapshot get _q => QueueSnapshot(state.queue, state.currentIndex);

  @override
  void moveInQueue(int from, int to) => _apply(_q.move(from, to));

  @override
  Future<RemovedFromQueue?> removeFromQueue(int index) async {
    final removed = RemovedFromQueue(
      track: state.queue[index],
      index: index,
      wasCurrent: index == state.currentIndex,
      position: Duration.zero,
      wasPlaying: true,
    );
    _apply(_q.remove(index));
    return removed;
  }

  @override
  Future<void> undoRemove(RemovedFromQueue removed) async =>
      _apply(_q.insert(removed.index, removed.track, wasCurrent: removed.wasCurrent));
}

List<String> _titlesOnScreen(WidgetTester tester) => [
      for (final title in ['Uno', 'Dos', 'Tres'])
        if (find.text(title).evaluate().isNotEmpty) title,
    ];

void main() {
  testWidgets('Quitar una canción ofrece Deshacer y la devuelve a su lugar', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [playbackProvider.overrideWith(_FakePlayback.new)],
      child: const MaterialApp(home: QueueScreen()),
    ));

    expect(find.text('2 canciones después de esta'), findsOneWidget);
    expect(_titlesOnScreen(tester), ['Uno', 'Dos', 'Tres']);

    await tester.tap(find.byTooltip('Quitar de la cola').at(1)); // "Dos"
    await tester.pumpAndSettle();

    expect(find.text('Dos'), findsNothing);
    expect(find.text('Se quitó «Dos» de la cola'), findsOneWidget);
    expect(find.text('1 canción después de esta'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(find.text('Dos'), findsOneWidget);
    expect(find.text('2 canciones después de esta'), findsOneWidget);
  });

  testWidgets('Cola vacía muestra un mensaje claro', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        playbackProvider.overrideWith(_EmptyPlayback.new),
      ],
      child: const MaterialApp(home: QueueScreen()),
    ));
    expect(find.text('La cola está vacía'), findsOneWidget);
  });
}

class _EmptyPlayback extends PlaybackNotifier {
  @override
  PlaybackState build() => PlaybackState.initial();
}
