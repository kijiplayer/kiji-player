// Sonido en la PC con el reproductor real (just_audio + mpv), SOLO EN PC:
//   flutter test integration_test/sonido_pc_test.dart -d windows
// Suena un tono inventado (sin música real) en volumen 0 y revisa que el ecualizador, los bajos,
// la velocidad y el tono lleguen a mpv sin trabar la reproducción.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_media_kit/mediakit_player.dart';
import 'package:kiji_player/features/equalizer/data/equalizer_engine.dart';
import 'package:kiji_player/features/equalizer/domain/equalizer_model.dart';

/// 2 minutos de un tono estéreo inventado.
File _tone(Directory dir) {
  const rate = 44100, seconds = 120;
  const samples = rate * seconds;
  final data = ByteData(44 + samples * 4);
  void str(int o, String s) => s.codeUnits.asMap().forEach((i, c) => data.setUint8(o + i, c));
  str(0, 'RIFF');
  data.setUint32(4, 36 + samples * 4, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 2, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 4, Endian.little)
    ..setUint16(32, 4, Endian.little)
    ..setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples * 4, Endian.little);
  for (var i = 0; i < samples; i++) {
    final v = (math.sin(2 * math.pi * 220 * i / rate) * 8000).round();
    data
      ..setInt16(44 + i * 4, v, Endian.little)
      ..setInt16(46 + i * 4, v, Endian.little);
  }
  return File('${dir.path}/tono.wav')..writeAsBytesSync(data.buffer.asUint8List());
}

Future<String> _af() async => await MediaKitPlayer.live.first.debugProperty('af') ?? '';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ecualizador, bajos, velocidad y tono en vivo con el reproductor real', (tester) async {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: true);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('sonido'))));
    await tester.runAsync(() async {
      final dir = Directory.systemTemp.createTempSync('kiji_sonido_');
      final player = AudioPlayer();
      await player.setVolume(0);
      await player.setFilePath(_tone(dir).path);
      unawaited(player.play());
      await Future<void>.delayed(const Duration(seconds: 2));
      final engine = MpvSoundEngine();

      Future<int> advance(Duration wait) async {
        final start = player.position;
        await Future<void>.delayed(wait);
        return (player.position - start).inMilliseconds;
      }

      // Ecualizador y bajos.
      await engine.apply(const SoundMix(enabled: true, gains: [0, 4, 0, 0, 0, 0, 0, 0, 0, -3], bass: 0.5));
      expect(await _af(), contains('equalizer'));
      final normal = await advance(const Duration(seconds: 2));
      debugPrint('=== PRUEBA: con ecualizador avanzó $normal ms en 2 s; af=${await _af()} ===');
      expect(normal, inInclusiveRange(1600, 2400), reason: 'los filtros no traban la música');

      // Moverlo como al arrastrar un control: 15 cambios seguidos.
      for (var i = 0; i < 15; i++) {
        await engine.apply(SoundMix(enabled: true, gains: [for (var b = 0; b < 10; b++) (i + b) % 7 - 3.0]));
      }
      expect(await advance(const Duration(seconds: 2)), inInclusiveRange(1600, 2400));

      // Velocidad 1.5x (sin tocar el tono): más rápido, sin filtros de más.
      await player.setSpeed(1.5);
      final fast = await advance(const Duration(seconds: 2));
      debugPrint('=== PRUEBA: a 1.5x avanzó $fast ms en 2 s ===');
      expect(fast, inInclusiveRange(2500, 3500));

      // Tono +2 semitonos a velocidad normal: el tempo sigue igual.
      await player.setSpeed(1);
      await player.setPitch(math.pow(2, 2 / 12).toDouble());
      expect(await _af(), allOf(contains('scaletempo'), contains('equalizer')));
      final pitched = await advance(const Duration(seconds: 2));
      debugPrint('=== PRUEBA: con tono +2 avanzó $pitched ms en 2 s; af=${await _af()} ===');
      expect(pitched, inInclusiveRange(1600, 2400));

      // Un reproductor nuevo (como el de la mezcla) arranca con los efectos puestos.
      final second = AudioPlayer();
      await second.setVolume(0);
      await second.setFilePath('${dir.path}/tono.wav');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final secondAf = await MediaKitPlayer.live.last.debugProperty('af');
      debugPrint('=== PRUEBA: el segundo reproductor tiene af=$secondAf ===');
      expect(secondAf, contains('equalizer'));

      // "Efectos" apagado: sin filtros.
      await player.setPitch(1);
      await engine.apply(const SoundMix(enabled: false, gains: [4]));
      expect(await _af(), isEmpty);
      await second.dispose();
      await player.dispose();
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
