import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/features/selection/track_selection.dart';
import 'package:kiji_player/models/track.dart';

Track _t(String id) => Track(
      id: 'yt-$id',
      title: 'Canción $id',
      artist: 'Artista',
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: '',
      source: TrackSource.youtube,
    );

void main() {
  group('TrackSelection', () {
    test('Elegir, quitar, todas y ninguna', () {
      final s = TrackSelection();
      var changes = 0;
      s.addListener(() => changes++);
      expect(s.active, isFalse);
      s.toggle('a', _t('a'));
      s.toggle('b', _t('b'));
      expect(s.length, 2);
      expect(s.tracks.map((t) => t.id), ['yt-a', 'yt-b']); // en el orden elegido
      s.toggle('a', _t('a'));
      expect(s.keys, {'b'});
      final all = {'a': _t('a'), 'b': _t('b'), 'c': _t('c')};
      s.toggleAll(all);
      expect(s.length, 3);
      s.toggleAll(all); // ya estaban todas: ninguna
      expect(s.active, isFalse);
      expect(changes, 5);
    });
  });

  test('Playlist: quitar varias y deshacer las deja en su lugar', () async {
    final dir = await Directory.systemTemp.createTemp('kiji_sel_');
    addTearDown(() => dir.delete(recursive: true));
    final c = ProviderContainer(overrides: [
      playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: () async => dir)),
    ]);
    addTearDown(c.dispose);
    c.read(playlistsProvider);
    await c.read(playlistsProvider.notifier).loaded;
    final notifier = c.read(playlistsProvider.notifier);
    final pl = notifier.create('Mía', tracks: [_t('a'), _t('b'), _t('c'), _t('d'), _t('e')]);

    final removed = notifier.removeTracksAt(pl.id, {1, 3});
    expect(removed.map((r) => r.$2.id), ['yt-b', 'yt-d']);
    expect(notifier.byId(pl.id)!.tracks.map((t) => t.id), ['yt-a', 'yt-c', 'yt-e']);

    notifier.insertTracks(pl.id, removed);
    expect(notifier.byId(pl.id)!.tracks.map((t) => t.id), ['yt-a', 'yt-b', 'yt-c', 'yt-d', 'yt-e']);
    await notifier.flush();
  });

  testWidgets('La barra: cuántas, todas, quitar y "Más" solo con una', (tester) async {
    final selection = TrackSelection();
    final all = {'a': _t('a'), 'b': _t('b')};
    Set<String>? removedKeys;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SelectionBar(
              selection: selection,
              all: all,
              remove: SelectionRemoveAction(
                label: 'Quitar de la playlist',
                icon: Icons.playlist_remove_rounded,
                onRemove: (keys, _) async => removedKeys = keys,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Quitar de la playlist'), findsNothing); // sin selección no hay barra

    selection.toggle('a', _t('a'));
    await tester.pump();
    expect(find.text('1 seleccionada'), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);

    await tester.tap(find.byTooltip('Seleccionar todas'));
    await tester.pump();
    expect(find.text('2 seleccionadas'), findsOneWidget);
    expect(find.text('Más'), findsNothing);

    await tester.tap(find.text('Quitar de la playlist'));
    await tester.pump();
    expect(removedKeys, {'a', 'b'});
    expect(selection.active, isFalse);
  });

  testWidgets('Esc cierra la selección y Ctrl+A elige todas', (tester) async {
    final selection = TrackSelection();
    final all = {'a': _t('a'), 'b': _t('b'), 'c': _t('c')};
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SelectionBar(selection: selection, all: all)),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _pulsarCtrlA(tester);
    expect(selection.active, isFalse);

    selection.toggle('b', _t('b'));
    await tester.pump();
    await _pulsarCtrlA(tester);
    expect(selection.keys, {'a', 'b', 'c'});

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(selection.active, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _pulsarCtrlA(tester);
    expect(selection.active, isFalse);
  });

  testWidgets('Esc y Ctrl+A no actúan mientras se escribe', (tester) async {
    final selection = TrackSelection();
    final all = {'a': _t('a'), 'b': _t('b')};
    selection.toggle('a', _t('a'));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const TextField(),
                SelectionBar(selection: selection, all: all),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _pulsarCtrlA(tester);
    expect(selection.keys, {'a'});
  });
}

Future<void> _pulsarCtrlA(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}
