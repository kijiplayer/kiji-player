import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/downloads/domain/downloaded_track.dart';
import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/features/playlists/presentation/playlist_screens.dart';
import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/downloads_provider.dart';
import 'package:kiji_player/providers/playback_provider.dart';

class _EmptyPlayback extends PlaybackNotifier {
  @override
  PlaybackState build() => PlaybackState.initial();
}

/// Una descargada y otra con error, para que se vean los cuatro filtros.
class _MixedDownloads extends DownloadsNotifier {
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
        sizeBytes: 10,
        downloadedAt: DateTime(2026),
      ),
    },
    active: {'b': ActiveDownload(track: _t('b'), status: ActiveDownloadStatus.failed)},
  );
}

/// Fuentes de la app, para medir el ancho real (sin ellas cada letra ocupa un cuadro enorme).
Future<void> _loadKijiFonts() async {
  final mono = FontLoader('JetBrainsMono')
    ..addFont(rootBundle.load('assets/fonts/jetbrains_mono/JetBrainsMono-Variable.ttf'));
  final title = FontLoader('SpaceGrotesk')
    ..addFont(rootBundle.load('assets/fonts/space_grotesk/SpaceGrotesk-Variable.ttf'));
  await mono.load();
  await title.load();
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

  testWidgets('En 390 px y letra grande los cuatro filtros de descarga se ven enteros', (tester) async {
    await tester.runAsync(_loadKijiFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    // Igual que TextScaler.linear(2): la letra del sistema al doble.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    Future<Directory> noDisk() async => throw const FileSystemException('sin disco en el test');
    final container = ProviderContainer(overrides: [
      playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: noDisk)),
      playbackProvider.overrideWith(_EmptyPlayback.new),
      downloadsProvider.overrideWith(_MixedDownloads.new),
    ]);
    addTearDown(container.dispose);
    final playlist = container.read(playlistsProvider.notifier).create('Linternas', tracks: [_t('a'), _t('b'), _t('c')]);

    // Reproducir / Aleatorio ya no entran en 390 px (también con letra normal). Este test mira los filtros.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final info = details.informationCollector?.call().map((node) => node.toStringDeep()).join('\n') ?? '';
      if (details.exceptionAsString().contains('overflowed') && info.contains('_ListHeader')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: PlaylistScreen(playlistId: playlist.id)),
    ));
    await tester.pump();
    expect(MediaQuery.textScalerOf(tester.element(find.byType(PlaylistScreen))).scale(1), 2);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final label in [tx.todas, tx.descargadas, tx.sinDescargar, tx.conError2]) {
      final chip = find.widgetWithText(ChoiceChip, label);
      expect(chip, findsOneWidget, reason: label);
      final rect = tester.getRect(chip);
      expect(rect.left, greaterThanOrEqualTo(0), reason: label);
      expect(rect.top, greaterThanOrEqualTo(0), reason: label);
      expect(rect.right, lessThanOrEqualTo(screen.width), reason: label);
      expect(rect.bottom, lessThanOrEqualTo(screen.height), reason: label);
      expect(rect.width, greaterThan(0), reason: label);
      expect(rect.height, greaterThan(0), reason: label);
    }
  });
}
