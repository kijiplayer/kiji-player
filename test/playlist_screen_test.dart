import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/downloads/domain/download_failure.dart';
import 'package:kiji_player/features/downloads/domain/downloaded_track.dart';
import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/features/playlists/presentation/playlist_screens.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/downloads_provider.dart';
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

/// Una descargada (a) y una con error (c): así aparecen los cuatro filtros.
class _SomeDownloads extends DownloadsNotifier {
  @override
  DownloadsState build() => DownloadsState(
    loaded: true,
    completed: {
      'a': DownloadedTrack(
        videoId: 'a',
        title: 'Canción a',
        artist: 'Artista',
        coverColor: const Color(0xFF7C5CFF),
        fileName: 'a.m4a',
        sizeBytes: 100,
        downloadedAt: DateTime(2026, 10, 21),
      ),
    },
    active: {
      'c': ActiveDownload(track: _t('c'), status: ActiveDownloadStatus.failed, failure: DownloadFailure.unknown),
    },
  );
}

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

  testWidgets('Buscar dentro de la playlist: sin importar mayúsculas ni tildes', (tester) async {
    Future<Directory> noDisk() async => throw const FileSystemException('sin disco en el test');
    final container = ProviderContainer(overrides: [
      playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: noDisk)),
      playbackProvider.overrideWith(_EmptyPlayback.new),
    ]);
    addTearDown(container.dispose);
    final otra = _t('b').copyWith(title: 'Río de cristal', artist: 'The Velvet Tides');
    final playlist = container.read(playlistsProvider.notifier).create('Mía', tracks: [_t('a'), otra, _t('c')]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: PlaylistScreen(playlistId: playlist.id)),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'RIO');
    await tester.pump();
    expect(find.text('Río de cristal'), findsOneWidget);
    expect(find.text('Canción a'), findsNothing);

    await tester.enterText(find.byType(TextField), 'velvet');
    await tester.pump();
    expect(find.text('Río de cristal'), findsOneWidget, reason: 'también por artista');

    await tester.tap(find.byTooltip('Borrar la búsqueda'));
    await tester.pump();
    expect(find.text('Canción a'), findsOneWidget);
    expect(find.text('Canción c'), findsOneWidget);
  });

  testWidgets('Celular angosto: los cuatro filtros de descarga se ven enteros', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Future<Directory> noDisk() async => throw const FileSystemException('sin disco en el test');
    final container = ProviderContainer(overrides: [
      playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: noDisk)),
      playbackProvider.overrideWith(_EmptyPlayback.new),
      downloadsProvider.overrideWith(_SomeDownloads.new),
    ]);
    addTearDown(container.dispose);
    final playlist =
        container.read(playlistsProvider.notifier).create('Mía', tracks: [_t('a'), _t('b'), _t('c')]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      // Letra del sistema grande: el caso más justo.
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), textScaler: TextScaler.linear(1.3)),
          child: PlaylistScreen(playlistId: playlist.id),
        ),
      ),
    ));
    await tester.pump();
    for (final label in ['Todas', 'Descargadas', 'Sin descargar', 'Con error']) {
      final chip = find.widgetWithText(ChoiceChip, label);
      expect(chip, findsOneWidget, reason: label);
      final box = tester.getRect(chip);
      expect(box.left, greaterThanOrEqualTo(0), reason: label);
      expect(box.right, lessThanOrEqualTo(390), reason: '$label se sale de la pantalla');
    }
  });
}
