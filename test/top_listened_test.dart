import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/history/listening_history.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/screens/home/top_listened.dart';

Track _track(String id, String title) => Track(
  id: id,
  title: title,
  artist: 'Banda Inventada',
  coverColor: const Color(0xFF555555),
  audioUrl: '',
  source: TrackSource.youtube,
);

HistoryEntry _entry(String id, String title, int count, int day) =>
    HistoryEntry(track: _track(id, title), lastPlayed: DateTime(2026, 10, day), playCount: count);

void main() {
  test('el top ordena por veces (empate: la más reciente) y deja afuera la que suena', () {
    final entries = [
      _entry('a', 'Canción A', 3, 1),
      _entry('b', 'Canción B', 9, 2),
      _entry('c', 'Canción C', 3, 5),
      _entry('d', 'Canción D', 12, 3),
    ];
    final top = HistoryLogic.top(entries, excludeId: 'd');
    expect([for (final e in top) e.track.id], ['b', 'c', 'a']);
    expect(top.first.playCount, 9);
  });

  test('"calculado en esta PC" en Windows y "en tu teléfono" en Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(calculatedHereNote(), 'calculado en esta PC');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(calculatedHereNote(), 'calculado en tu teléfono');
    debugDefaultTargetPlatformOverride = null;
  });

  for (final (name, width) in [('celular angosto', 340.0), ('PC', 1100.0)]) {
    testWidgets('el top muestra puesto, portada y veces, sin desbordes ($name)', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final entries = [
        _entry('a', 'Un título inventado bastante largo para ver cómo se corta', 42, 1),
        for (var i = 2; i <= 6; i++) _entry('t$i', 'Canción $i', 7 - i, i),
      ];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: TopListened(entries: entries),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('42 VECES'), findsOneWidget, reason: 'la #1, destacada');
      expect(find.text('1'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('1 vez'), findsOneWidget, reason: 'la #6 se escuchó una vez');
    });
  }
}
