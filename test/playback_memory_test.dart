import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/playback_memory/data/playback_memory_store.dart';
import 'package:kiji_player/features/playback_memory/domain/playback_snapshot.dart';
import 'package:kiji_player/models/track.dart';

const _local = Track(
  id: 'local-42',
  title: 'Canción local',
  artist: 'Artista',
  coverColor: Color(0xFF3DF5FF),
  audioUrl: '/storage/emulated/0/Music/cancion.mp3',
  source: TrackSource.local,
  album: 'Álbum',
  durationMs: 200000,
);

const _youtube = Track(
  id: 'yt-abc123',
  title: 'Canción de YouTube',
  artist: 'Otro artista',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: 'https://rr1---sn.googlevideo.com/videoplayback?expire=1',
  source: TrackSource.youtube,
  thumbnailUrl: 'https://i.ytimg.com/vi/abc123/hq.jpg',
);

void main() {
  late Directory dir;
  late PlaybackMemoryStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kiji_memoria_');
    store = PlaybackMemoryStore(directory: () async => dir);
  });

  tearDown(() => dir.delete(recursive: true));

  test('Track local conserva todos sus datos al serializar', () {
    final restored = Track.fromJson(_local.toJson());
    expect(restored.id, _local.id);
    expect(restored.audioUrl, _local.audioUrl);
    expect(restored.coverColor.toARGB32(), _local.coverColor.toARGB32());
    expect(restored.album, 'Álbum');
    expect(restored.durationMs, 200000);
  });

  test('Track de YouTube no guarda la URL (vence) pero sí el videoId', () {
    final restored = Track.fromJson(_youtube.toJson());
    expect(restored.audioUrl, isEmpty);
    expect(restored.youtubeVideoId, 'abc123');
    expect(restored.thumbnailUrl, _youtube.thumbnailUrl);
  });

  test('Guardar y cargar devuelve la misma cola, índice y modos', () async {
    await store.save(
      const PlaybackSnapshot(
        queue: [_local, _youtube],
        currentIndex: 1,
        positionMs: 83000,
        repeatMode: 'all',
        shuffleEnabled: true,
      ),
    );

    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.queue.map((t) => t.id), ['local-42', 'yt-abc123']);
    expect(loaded.currentIndex, 1);
    expect(loaded.positionMs, 83000);
    expect(loaded.repeatMode, 'all');
    expect(loaded.shuffleEnabled, isTrue);
    expect(File('${dir.path}/playback_state.json.tmp').existsSync(), isFalse);
  });

  test('Sin archivo de guardado devuelve null', () async {
    expect(await store.load(), isNull);
  });

  test('Un guardado dañado se borra y se arranca vacío', () async {
    final file = File('${dir.path}/playback_state.json');
    await file.writeAsString('{"version": 1, "queue": [');

    expect(await store.load(), isNull);
    expect(file.existsSync(), isFalse);
  });

  test('Un índice fuera de rango cuenta como guardado dañado', () async {
    final file = File('${dir.path}/playback_state.json');
    await file.writeAsString(
      '{"version": 1, "queue": [], "currentIndex": 3, "positionMs": 0}',
    );

    expect(await store.load(), isNull);
    expect(file.existsSync(), isFalse);
  });
}
