import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/downloads/data/storage_info_impl.dart';
import 'package:kiji_player/features/local_library/data/desktop_folder_source.dart';
import 'package:kiji_player/features/local_library/data/local_scanner.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/widgets/playback_shortcuts.dart';

import 'helpers/fake_mp3.dart';

void main() {
  group('Biblioteca en PC (carpetas elegidas)', () {
    late Directory base;
    late Directory music;

    setUp(() async {
      base = await Directory.systemTemp.createTemp('kiji_pc_');
      music = await Directory(p.join(base.path, 'Musica')).create();
    });

    tearDown(() => base.delete(recursive: true));

    test('Agregar y quitar carpetas (quitar no borra archivos)', () async {
      final song = File(p.join(music.path, 'tema.mp3'))..writeAsBytesSync([1, 2, 3]);
      final source = DesktopFolderSource(
        baseDirectory: () async => base,
        pickFolder: () async => music.path,
      );

      expect(await source.hasAccess(), isFalse);
      expect(await source.requestAccess(), isTrue);
      expect(await source.folders(), [music.path]);

      // Elegir la misma carpeta otra vez no la duplica.
      await source.requestAccess();
      expect(await source.folders(), [music.path]);

      await source.removeFolder(music.path);
      expect(await source.folders(), isEmpty);
      expect(song.existsSync(), isTrue);
    });

    test('Cancelar el selector no cambia nada', () async {
      final source = DesktopFolderSource(
        baseDirectory: () async => base,
        pickFolder: () async => null,
      );
      expect(await source.requestAccess(), isFalse);
      expect(await source.folders(), isEmpty);
    });

    test('Lee las etiquetas reales de un MP3', () async {
      File(p.join(music.path, 'archivo_feo_01.mp3'))
          .writeAsBytesSync(fakeMp3(title: 'Cancion de prueba', artist: 'Luna Nova'));
      final source = DesktopFolderSource(baseDirectory: () async => base, pickFolder: () async => music.path);
      await source.requestAccess();
      final songs = await source.loadTracks();
      expect(songs, hasLength(1));
      expect(songs.single.title, 'Cancion de prueba');
      expect(songs.single.artist, 'Luna Nova');
    });

    test('Ignora lo que no es audio y usa el nombre si no hay etiquetas', () async {
      await Directory(p.join(music.path, 'Sub')).create();
      File(p.join(music.path, 'Sub', 'Sin etiquetas.flac')).writeAsBytesSync([0, 1, 2]);
      File(p.join(music.path, 'portada.jpg')).writeAsBytesSync([0, 1, 2]);
      File(p.join(music.path, 'notas.txt')).writeAsStringSync('hola');
      final source = DesktopFolderSource(baseDirectory: () async => base, pickFolder: () async => music.path);
      await source.requestAccess();
      final songs = await source.loadTracks();
      expect(songs, hasLength(1));
      expect(songs.single.title, 'Sin etiquetas');
      expect(songs.single.artist, 'Artista desconocido');
      expect(songs.single.audioUrl, p.join(music.path, 'Sub', 'Sin etiquetas.flac'));
    });

    test('Una carpeta elegida dos veces (o anidada) no duplica canciones', () {
      File(p.join(music.path, 'a.mp3')).writeAsBytesSync([0]);
      expect(listAudioFiles([music.path, music.path]), hasLength(1));
    });
  });

  test(
    'Espacio libre en Windows (FFI real a kernel32)',
    () async {
      final free = await WindowsStorageInfo().freeBytes(Directory.systemTemp.path);
      expect(free, isNotNull);
      expect(free!, greaterThan(0));
    },
    skip: Platform.isWindows ? false : 'Solo corre en Windows',
  );

  group('Atajos de teclado', () {
    testWidgets('Espacio pausa, pero no mientras se escribe en el buscador', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [playbackProvider.overrideWith(() => _RecordingPlayback(calls))],
        child: const MaterialApp(
          home: PlaybackShortcuts(
            child: Scaffold(body: Center(child: SizedBox(width: 200, child: TextField()))),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(calls, ['toggle', 'seek 5', 'volume 0.1']);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(calls, ['toggle', 'seek 5', 'volume 0.1'], reason: 'escribiendo no se toca la música');
    });
  });
}

class _RecordingPlayback extends PlaybackNotifier {
  _RecordingPlayback(this.calls);

  final List<String> calls;

  @override
  PlaybackState build() => PlaybackState.initial();

  @override
  Future<void> togglePlayPause() async => calls.add('toggle');

  @override
  Future<void> seekBy(Duration offset) async => calls.add('seek ${offset.inSeconds}');

  @override
  Future<void> changeVolume(double delta) async => calls.add('volume $delta');
}
