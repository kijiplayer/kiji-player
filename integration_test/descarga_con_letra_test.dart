// Una descarga con su letra al lado (<id>.lrc, desde la 0.8.2) tiene que sonar. SOLO EN PC:
//   flutter test integration_test/descarga_con_letra_test.dart -d windows
// En la 0.8.3, en Windows, mpv cargaba solo el .lrc como subtítulo externo ("Can not open external
// file …\<id>.lrc") y la descarga no sonaba. Audio y letra inventados (un tono y dos líneas).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:kiji_player/features/downloads/data/downloads_repository.dart';
import 'package:kiji_player/features/downloads/domain/downloaded_track.dart';

/// Unos segundos de un tono inventado.
Uint8List _tone({int seconds = 20}) {
  const rate = 44100;
  final samples = rate * seconds;
  final data = ByteData(44 + samples * 2);
  void str(int o, String s) => s.codeUnits.asMap().forEach((i, c) => data.setUint8(o + i, c));
  str(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    data.setInt16(44 + i * 2, (math.sin(2 * math.pi * 330 * i / rate) * 6000).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('una descarga con su .lrc al lado suena (Windows, reproductor real)', (tester) async {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: true);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('descarga con letra'))));
    await tester.runAsync(() async {
      final base = Directory.systemTemp.createTempSync('kiji_descarga_lrc_');
      final repo = DownloadsRepository(baseDirectory: () async => base);
      const id = 'n1HDBeN0pJA';
      final audio = File(await repo.pathFor('$id.wav'))..writeAsBytesSync(_tone());
      await repo.add(
        DownloadedTrack(
          videoId: id,
          title: 'Canción inventada',
          artist: 'Artista inventado',
          coverColor: const Color(0xFF7C5CFF),
          fileName: '$id.wav',
          sizeBytes: audio.lengthSync(),
          downloadedAt: DateTime(2026, 11, 18),
        ),
      );
      await repo.saveLyrics(id, '[00:00.00]Primera línea inventada\n[00:02.00]Segunda línea inventada\n');
      expect(File(await repo.pathFor('$id.lrc')).existsSync(), isTrue);

      final file = await repo.fileFor(id);
      expect(file!.path, endsWith('$id.wav'), reason: 'al reproductor va el audio, nunca el .lrc');

      final player = AudioPlayer();
      final errors = <Object>[];
      final sub = player.playbackEventStream.listen((_) {}, onError: errors.add);
      await player.setVolume(0);
      // Con el error de la 0.8.3, la carga fallaba o no terminaba nunca: con tiempo máximo.
      Object? loadError;
      try {
        await player.setFilePath(file.path).timeout(const Duration(seconds: 15));
      } catch (error) {
        loadError = error;
      }
      expect(loadError, isNull, reason: 'la descarga tiene que cargar');
      // play() termina recién al pausar: no se espera.
      player.play().ignore();
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(errors, isEmpty);
      expect(player.playing, isTrue);
      expect(player.position, greaterThan(const Duration(milliseconds: 1500)), reason: 'tiene que avanzar');
      await sub.cancel();
      await player.dispose();
      base.deleteSync(recursive: true);
    });
  });
}
