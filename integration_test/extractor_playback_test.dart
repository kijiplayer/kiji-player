// Salud del Extractor 2.0 en Windows (Tarea Z8): prueba cada camino del motor B con una canción
// de control y la prueba del ÚLTIMO byte, y además reproduce de verdad (en silencio) una canción
// con la fuente por pedazos, saltando cerca del final.
//
// SOLO EN PC: flutter test integration_test/extractor_playback_test.dart -d windows
// NUNCA en el celular real: `flutter test` desinstala la app y borra sus datos
//. En el celular se usa el botón de la app.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:kiji_player/features/extractor/data/engines.dart';
import 'package:kiji_player/features/extractor/data/extractor_tester.dart';
import 'package:kiji_player/features/extractor/data/path_health.dart';
import 'package:kiji_player/features/extractor/data/stream_resolver.dart';
import 'package:kiji_player/features/stream_cache/data/chunked_source.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized(windows: true, linux: true);

  testWidgets('al menos 3 caminos pasan la prueba del último byte, y uno suena entero', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kiji_salud_pc');
    final health = PathHealth(directory: () async => dir.path);
    final client = YtMusicClient();
    final results = await ExtractorTester(client: client, health: health).runAll(
      onResult: (r) => debugPrint('=== SALUD ${r.path}: ${r.ok ? 'OK' : 'FALLA (${r.reason})'} '
          '${r.elapsed.inMilliseconds} ms, ${r.control} ==='),
    );
    debugPrint('=== ${healthSummary(results)} ===');

    // Reproducción real con la fuente por pedazos (sin sonido): arranca y llega cerca del final.
    final resolver = StreamResolver(engines: [KijiEngine(client)], health: health);
    final outcome = await resolver.resolve(controlVideos.first.$1);
    expect(outcome.stream, isNotNull);
    final player = AudioPlayer();
    await player.setVolume(0);
    final duration = await player.setAudioSource(ChunkedYtSource(stream: outcome.stream!, refresh: (_) async => null));
    await player.seek(duration! - const Duration(seconds: 8));
    await player.play();
    await Future<void>.delayed(const Duration(seconds: 5));
    final reached = player.position;
    debugPrint('=== PLAY ${outcome.stream!.path}: llegó a ${reached.inSeconds} de ${duration.inSeconds} s ===');
    expect(reached, greaterThan(duration - const Duration(seconds: 7)));
    await player.dispose();

    expect(results.where((r) => r.ok).length, greaterThanOrEqualTo(3));
  }, timeout: const Timeout(Duration(minutes: 8)));
}
