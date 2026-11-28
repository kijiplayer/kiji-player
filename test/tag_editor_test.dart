// Editor de etiquetas (0.9): escribe en una copia, la comprueba y recién ahí reemplaza el
// original. Si algo falla, el original queda igual. Archivos: 1 s de silencio, inventados.
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/local_library/data/tag_editor.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kiji_etiquetas'));
  tearDown(() => dir.deleteSync(recursive: true));

  File copyOf(String fixture) => File('test/fixtures/$fixture').copySync(p.join(dir.path, fixture));

  for (final fixture in ['silencio.mp3', 'silencio.flac']) {
    test('$fixture: título, artista, álbum y portada quedan guardados', () async {
      final file = copyOf(fixture);
      final cover = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 0xFF, 0xD9]); // «JPEG» inventado
      final result = await writeTags(
        file.path,
        TagChanges(title: 'Glass Harbor', artist: 'The Velvet Tides', album: 'Canciones Inventadas', cover: cover),
      );
      expect(result, TagEditResult.saved);
      final read = readMetadata(file, getImage: true);
      expect(read.title, 'Glass Harbor');
      expect(read.artist, 'The Velvet Tides');
      expect(read.album, 'Canciones Inventadas');
      expect(read.pictures, isNotEmpty);
      expect(dir.listSync().where((e) => e.path.endsWith('.kiji-tmp')), isEmpty, reason: 'sin copias sueltas');
    });
  }

  test('Un formato que no se escribe (.ogg) no se toca', () async {
    final file = File(p.join(dir.path, 'audio.ogg'))..writeAsBytesSync([1, 2, 3]);
    expect(await writeTags(file.path, const TagChanges(title: 'x')), TagEditResult.unsupported);
    expect(file.readAsBytesSync(), [1, 2, 3]);
  });

  test('Si el archivo no es audio de verdad, falla sin romper el original', () async {
    final file = File(p.join(dir.path, 'roto.mp3'))..writeAsBytesSync(List.filled(64, 7));
    final before = file.readAsBytesSync();
    final result = await writeTags(file.path, const TagChanges(title: 'Paper Lanterns'));
    expect(result, isNot(TagEditResult.saved));
    expect(file.readAsBytesSync(), before, reason: 'el original queda como estaba');
    expect(dir.listSync().where((e) => e.path.endsWith('.kiji-tmp')), isEmpty);
  });
}
