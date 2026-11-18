// Todas las descargas de una COPIA de los datos de la PC cargan y suenan (nunca los originales).
// SOLO EN PC, y solo si se indica la copia:
//   flutter test integration_test/descargas_copia_test.dart -d windows --dart-define=KIJI_COPIA=<carpeta>
// <carpeta> es la que contiene `downloads/` (con su index.json). Sin KIJI_COPIA, la prueba se salta.
// Al registro solo van cuántas sonaron y el id de las que no (nunca títulos ni letras).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:kiji_player/features/downloads/data/downloads_repository.dart';

const _copy = String.fromEnvironment('KIJI_COPIA');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cada descarga de la copia carga y avanza', (tester) async {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: true);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('descargas de la copia'))));
    await tester.runAsync(() async {
      final repo = DownloadsRepository(baseDirectory: () async => Directory(_copy));
      final all = await repo.all();
      final player = AudioPlayer();
      await player.setVolume(0);
      final failed = <String>[];
      var withLyrics = 0;
      for (final track in all.values) {
        if (track.lyricsFileName != null) withLyrics++;
        final file = await repo.fileFor(track.videoId);
        try {
          if (file == null || file.path.endsWith('.lrc')) throw StateError('sin audio');
          await player.setFilePath(file.path).timeout(const Duration(seconds: 15));
          player.play().ignore();
          await Future<void>.delayed(const Duration(milliseconds: 900));
          if (player.position < const Duration(milliseconds: 300)) throw StateError('no avanza');
          await player.pause();
        } catch (error) {
          failed.add('${track.videoId} (${error.runtimeType})');
        }
      }
      await player.dispose();
      debugPrint('=== COPIA: ${all.length - failed.length} de ${all.length} suenan ($withLyrics con letra) ===');
      expect(failed, isEmpty);
    });
  }, skip: _copy.isEmpty);
}
