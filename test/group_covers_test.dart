import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/customize/data/track_overrides.dart';
import 'package:kiji_player/features/local_library/data/group_covers.dart';
import 'package:kiji_player/features/local_library/domain/local_groups.dart';
import 'package:kiji_player/models/track.dart';

Track _t(String id, {String? album, String dir = '/m/Noche'}) => Track(
  id: id,
  title: id,
  artist: 'Ana Inventada',
  coverColor: const Color(0xFF3A6EA5),
  audioUrl: '$dir/$id.mp3',
  source: TrackSource.local,
  album: album,
);

Uint8List _png() => Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));

void main() {
  test('La clave de álbum y de carpeta de una canción es la de su grupo', () {
    final tracks = [_t('a', album: 'Noche'), _t('b', album: 'Noche'), _t('c', dir: '/m/Otra')];
    expect(albumKeyOf(tracks.first), groupByAlbum(tracks).single.key);
    expect(folderKeyOf(tracks.last), groupByFolderPath(tracks).firstWhere((g) => g.name == 'Otra').key);
    expect(albumKeyOf(tracks.last), isNull, reason: 'sin álbum no hay clave de álbum');
  });

  test('Elegir portada: se guarda una vez, se reemplaza y se quita (y se recuerda)', () async {
    final dir = await Directory.systemTemp.createTemp('kiji_portadas_');
    addTearDown(() => dir.delete(recursive: true));
    ProviderContainer make() {
      final c = ProviderContainer(overrides: [
        trackOverridesProvider.overrideWith(() => TrackOverridesNotifier(directory: () async => dir)),
        groupCoversProvider.overrideWith(() => GroupCoversNotifier(directory: () async => dir)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    final c = make();
    c.read(groupCoversProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    const key = 'album:noche\u0000ana inventada';
    await c.read(groupCoversProvider.notifier).set(key, _png());
    final first = c.read(groupCoversProvider)[key]!;
    expect(File(p.join(dir.path, 'covers', first)).existsSync(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await c.read(groupCoversProvider.notifier).set(key, _png());
    final second = c.read(groupCoversProvider)[key]!;
    expect(second, isNot(first));
    expect(File(p.join(dir.path, 'covers', first)).existsSync(), isFalse, reason: 'la vieja se borra');

    final again = make();
    again.read(groupCoversProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(again.read(groupCoversProvider)[key], second, reason: 'se recuerda al reabrir');
    await again.read(groupCoversProvider.notifier).clear(key);
    expect(again.read(groupCoversProvider), isEmpty);
    expect(File(p.join(dir.path, 'covers', second)).existsSync(), isFalse);
  });
}
