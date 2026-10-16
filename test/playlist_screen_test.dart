import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/features/playlists/presentation/playlist_screens.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

class _EmptyPlayback extends PlaybackNotifier {
  @override
  PlaybackState build() => PlaybackState.initial();
}

Track _t(String id) => Track(
      id: 'yt-$id',
      title: 'Canción $id',
      artist: 'Artista',
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: '',
      source: TrackSource.youtube,
    );

void main() {
  testWidgets('Quitar una canción de una playlist ofrece Deshacer', (tester) async {
    // Sin disco en testWidgets (el tiempo es simulado): queda en memoria.
    Future<Directory> noDisk() async => throw const FileSystemException('sin disco en el test');
    final container = ProviderContainer(overrides: [
      playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: noDisk)),
      playbackProvider.overrideWith(_EmptyPlayback.new),
    ]);
    addTearDown(container.dispose);
    final playlist = container.read(playlistsProvider.notifier).create('Mía', tracks: [_t('a'), _t('b')]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: PlaylistScreen(playlistId: playlist.id)),
    ));
    await tester.pump();
    expect(find.text('Mía'), findsOneWidget);
    expect(find.text('2 canciones'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar de la playlist').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800)); // el aviso termina de entrar
    expect(find.text('Canción a'), findsNothing);
    expect(find.text('Se quitó «Canción a»'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Canción a'), findsOneWidget);
    expect(container.read(playlistsProvider).single.tracks.first.id, 'yt-a');
  });
}
