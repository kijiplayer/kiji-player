// Motor C, solo PC: baja yt-dlp oficial a una carpeta temporal, verifica su huella y
// pide el audio de una canción de control, con la prueba del último byte.
// SOLO EN PC: flutter test integration_test/ytdlp_engine_test.dart -d windows

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiji_player/features/extractor/data/extractor_tester.dart';
import 'package:kiji_player/features/extractor/data/ytdlp_engine.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('yt-dlp verificado da audio entero', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kiji_ytdlp');
    final engine = YtDlpEngine(directory: () async => dir, accepted: () => true);
    await engine.install(onProgress: (d, t) {});
    expect(await engine.installed(), isTrue);
    final watch = Stopwatch()..start();
    final result = await engine.resolve(controlVideos.first.$1);
    debugPrint('=== MOTOR C: ${result.stream ?? result.failures} (${watch.elapsedMilliseconds} ms) ===');
    expect(result.stream, isNotNull);
    final problem = await ExtractorTester(client: YtMusicClient()).lastByteCheck(result.stream!);
    debugPrint('=== MOTOR C último byte: ${problem ?? 'OK'} ===');
    expect(problem, isNull);
    await engine.remove();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
