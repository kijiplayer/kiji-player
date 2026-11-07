import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/downloads/data/cover_upgrade.dart';
import 'package:kiji_player/features/downloads/data/downloads_repository.dart';
import 'package:kiji_player/features/downloads/domain/downloaded_track.dart';

DownloadedTrack _track(String id, String? thumb) => DownloadedTrack(
  videoId: id,
  title: 'Canción $id',
  artist: 'Grupo Inventado',
  coverColor: Colors.teal,
  fileName: '$id.m4a',
  sizeBytes: 100,
  downloadedAt: DateTime(2026, 10, 1),
  thumbnailFileName: thumb,
  durationMs: 1000,
);

void main() {
  test('Solo mejora las portadas viejas, de a una, y anota el archivo nuevo', () async {
    final downloaded = <String>[];
    final replaced = <String, String>{};
    final upgrade = CoverUpgrade(
      coverUrlFor: (id) async => 'https://lh3.googleusercontent.com/$id=w120-h120',
      download: (id, url) async {
        downloaded.add(id);
        return '$id.hq.jpg';
      },
      replace: (id, name) async => replaced[id] = name,
      pause: Duration.zero,
    );
    final done = await upgrade.run([_track('a', 'a.jpg'), _track('b', 'b.hq.jpg'), _track('c', null)]);
    expect(done, 2);
    expect(downloaded, ['a', 'c'], reason: 'la de alta calidad ya está');
    expect(replaced, {'a': 'a.hq.jpg', 'c': 'c.hq.jpg'});
  });

  test('Sin internet: tras 3 fallas seguidas deja el resto para la próxima', () async {
    var asked = 0;
    final upgrade = CoverUpgrade(
      coverUrlFor: (id) async {
        asked++;
        return null;
      },
      download: (id, url) async => fail('no tiene que bajar nada'),
      replace: (id, name) async => fail('no tiene que reemplazar nada'),
      pause: Duration.zero,
    );
    expect(await upgrade.run([for (var i = 0; i < 10; i++) _track('v$i', 'v$i.jpg')]), 0);
    expect(asked, 3);
  });

  test('El índice cambia la portada y borra la vieja, sin tocar el audio', () async {
    final dir = Directory.systemTemp.createTempSync('kiji_portadas_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final repository = DownloadsRepository(baseDirectory: () async => dir);
    await repository.add(_track('a', 'a.jpg'));
    final old = File(await repository.pathFor('a.jpg'))..writeAsBytesSync([1]);
    final audio = File(await repository.pathFor('a.m4a'))..writeAsBytesSync([2]);
    File(await repository.pathFor('a.hq.jpg')).writeAsBytesSync([3]);

    final updated = await repository.replaceThumbnail('a', 'a.hq.jpg');
    expect(updated?.thumbnailFileName, 'a.hq.jpg');
    expect(old.existsSync(), isFalse);
    expect(audio.existsSync(), isTrue);
    // Al volver a leer el índice queda la nueva.
    final again = await DownloadsRepository(baseDirectory: () async => dir).all();
    expect(again['a']?.thumbnailFileName, 'a.hq.jpg');
  });
}
