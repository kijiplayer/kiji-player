import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/downloads/data/download_service.dart';
import 'package:kiji_player/features/downloads/data/playlist_download.dart';
import 'package:kiji_player/features/downloads/domain/downloaded_track.dart';
import 'package:kiji_player/features/playlists/domain/playlist.dart';
import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/features/playlists/presentation/playlist_actions.dart';
import 'package:kiji_player/features/playlists/presentation/playlist_screens.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/downloads_provider.dart';

Track _yt(String id, {int seconds = 200}) => Track(
      id: 'yt-$id',
      title: 'Tema $id',
      artist: 'Artista inventado',
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: '',
      source: TrackSource.youtube,
      durationMs: seconds * 1000,
    );

const _local = Track(
  id: 'local-1',
  title: 'Archivo propio',
  artist: 'Yo',
  coverColor: Color(0xFF3DF5FF),
  audioUrl: '/storage/emulated/0/Music/propio.mp3',
  source: TrackSource.local,
);

/// Descargas falsas: nada sale a internet; el test decide cuándo termina cada una.
class _FakeDownloads extends DownloadsNotifier {
  bool wifi = true;
  final paused = <String>[];

  @override
  DownloadsState build() => DownloadsState(
        loaded: true,
        completed: {
          'ya': DownloadedTrack(
            videoId: 'ya',
            title: 'Ya bajada',
            artist: 'Artista inventado',
            coverColor: const Color(0xFF7C5CFF),
            fileName: 'ya.m4a',
            sizeBytes: 10,
            downloadedAt: DateTime(2026),
          ),
        },
      );

  @override
  Future<DownloadCheck> check(Track track) async => wifi
      ? const DownloadCheck(estimate: DownloadEstimate(url: 'x', extension: 'm4a', sizeBytes: 100))
      : const DownloadCheck(blockedReason: 'Sin WiFi', waitingForWifi: true);

  @override
  void start(Track track, DownloadEstimate estimate) {
    state = state.copyWith(active: {
      ...state.active,
      track.youtubeVideoId!: ActiveDownload(track: track, status: ActiveDownloadStatus.downloading, total: 100),
    });
  }

  @override
  void pause(String videoId) {
    paused.add(videoId);
    state = state.copyWith(active: Map.of(state.active)..remove(videoId));
  }

  @override
  Future<void> cancel(String videoId) async {
    state = state.copyWith(active: Map.of(state.active)..remove(videoId));
  }

  void finish(String videoId) {
    final track = state.active[videoId]!.track;
    state = state.copyWith(
      active: Map.of(state.active)..remove(videoId),
      completed: {
        ...state.completed,
        videoId: DownloadedTrack(
          videoId: videoId,
          title: track.title,
          artist: track.artist,
          coverColor: track.coverColor,
          fileName: '$videoId.m4a',
          sizeBytes: 100,
          downloadedAt: DateTime(2026),
        ),
      },
    );
  }

  void fail(String videoId) {
    _setStatus(videoId, ActiveDownloadStatus.failed);
  }

  void _setStatus(String videoId, ActiveDownloadStatus status) {
    final d = state.active[videoId]!;
    state = state.copyWith(active: {...state.active, videoId: d.copyWith(status: status)});
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('El plan saltea descargadas, archivos propios y repetidas, y estima el tamaño', () {
    final plan = planPlaylistDownload([_yt('a'), _yt('ya'), _local, _yt('a'), _yt('b', seconds: 100)], {'ya'});
    expect([for (final t in plan.toDownload) t.youtubeVideoId], ['a', 'b']);
    expect(plan.alreadyDownloaded, 1);
    expect(plan.notFromYouTube, 1);
    expect(plan.estimatedBytes, (200 + 100) * estimatedBytesPerSecond);
  });

  test('Texto para compartir: una línea por canción, con enlace si es de YouTube', () {
    final text = playlistShareText(Playlist(
      id: 'p',
      name: 'Para la ruta',
      tracks: [_yt('abc'), _local],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ));
    expect(text, startsWith('«Para la ruta» (2 canciones)'));
    expect(text, contains('1. Artista inventado – Tema abc https://music.youtube.com/watch?v=abc'));
    expect(text, contains('2. Yo – Archivo propio'));
    expect(text, isNot(contains('/storage/')));
  });

  group('Cola de la playlist', () {
    late ProviderContainer container;
    late _FakeDownloads downloads;
    late PlaylistDownloadsNotifier batch;

    setUp(() {
      container = ProviderContainer(overrides: [downloadsProvider.overrideWith(_FakeDownloads.new)]);
      container.listen(playlistDownloadsProvider, (_, _) {});
      downloads = container.read(downloadsProvider.notifier) as _FakeDownloads;
      batch = container.read(playlistDownloadsProvider.notifier);
    });
    tearDown(() => container.dispose());

    PlaylistDownloadState status() => container.read(playlistDownloadsProvider)['p']!;

    test('De a dos, con progreso total, y sigue sola hasta el final', () async {
      final plan = planPlaylistDownload([_yt('a'), _yt('b'), _yt('c'), _yt('ya')], {'ya'});
      batch.start('p', plan);
      await _settle();
      expect(container.read(downloadsProvider).active.keys, ['a', 'b']);
      expect(status().total, 3);

      downloads.finish('a');
      await _settle();
      await _settle();
      expect(status().done, 1);
      expect(container.read(downloadsProvider).active.keys.toSet(), {'b', 'c'});

      downloads.fail('b');
      downloads.finish('c');
      await _settle();
      expect(status().done, 2);
      expect(status().failed, 1);
      expect(status().finished, isTrue);
    });

    test('Pausar no borra lo bajado y Seguir retoma las mismas', () async {
      batch.start('p', planPlaylistDownload([_yt('a'), _yt('b'), _yt('c')], {}));
      await _settle();
      batch.pause('p');
      expect(downloads.paused.toSet(), {'a', 'b'});
      expect(status().paused, isTrue);
      expect(status().failed, 0, reason: 'pausar no es un error');
      expect(container.read(downloadsProvider).active, isEmpty);

      batch.resume('p');
      await _settle();
      expect(container.read(downloadsProvider).active.keys, ['a', 'b']);
    });

    test('Sin WiFi (con "solo con WiFi") queda en pausa y avisa', () async {
      downloads.wifi = false;
      batch.start('p', planPlaylistDownload([_yt('a')], {}));
      await _settle();
      expect(status().paused, isTrue);
      expect(status().message, 'Sin WiFi');
      expect(container.read(downloadsProvider).active, isEmpty);

      downloads.wifi = true;
      batch.resume('p');
      await _settle();
      expect(container.read(downloadsProvider).active.keys, ['a']);
    });

    test('Cancelar corta todo', () async {
      batch.start('p', planPlaylistDownload([_yt('a'), _yt('b'), _yt('c')], {}));
      await _settle();
      await batch.cancel('p');
      expect(container.read(playlistDownloadsProvider), isEmpty);
      expect(container.read(downloadsProvider).active, isEmpty);
    });
  });

  testWidgets('El ⋯ grande de la playlist tiene todas las opciones', (tester) async {
    final playlist = Playlist(
      id: 'p1',
      name: 'Para la ruta',
      tracks: [_yt('a'), _local],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final container = ProviderContainer(overrides: [
      playlistsProvider.overrideWith(() => _OnePlaylist(playlist)),
      downloadsProvider.overrideWith(_FakeDownloads.new),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: PlaylistScreen(playlistId: playlist.id)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    for (final option in [
      'Reproducir', 'Aleatorio', 'Editar', 'Cambiar foto', 'Fijar arriba', 'Descargar toda la playlist', //
      'Compartir', 'Exportar', 'Borrar la playlist',
    ]) {
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(option)), findsOneWidget, reason: option);
    }
  });
}

/// Una playlist fija en memoria (sin disco).
class _OnePlaylist extends PlaylistsNotifier {
  _OnePlaylist(this.playlist);
  final Playlist playlist;

  @override
  List<Playlist> build() => [playlist];
}
