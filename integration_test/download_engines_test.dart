// Descargas con los motores de extracción, solo PC: baja una canción de control entera con
// el servicio de descargas y comprueba que el archivo pesa lo que dijo YouTube.
// SOLO EN PC: flutter test integration_test/download_engines_test.dart -d windows

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiji_player/features/downloads/data/download_service.dart';
import 'package:kiji_player/features/downloads/data/downloads_repository.dart';
import 'package:kiji_player/features/extractor/data/engines.dart';
import 'package:kiji_player/features/extractor/data/extractor_tester.dart';
import 'package:kiji_player/features/extractor/data/path_health.dart';
import 'package:kiji_player/features/extractor/data/stream_resolver.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('una canción de control baja entera por los motores', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kiji_t4_descarga');
    await tester.runAsync(() async {
      final client = YtMusicClient();
      final service = DownloadService(
        DownloadsRepository(baseDirectory: () async => dir),
        ytClient: client,
        resolver: StreamResolver(engines: [KijiEngine(client)], health: PathHealth(directory: () async => dir.path)),
      );
      final watch = Stopwatch()..start();
      final out = await service.estimate(controlVideos.first.$1);
      expect(out.estimate, isNotNull, reason: '${out.failure?.message}');
      final estimate = out.estimate!;
      final (fileName, bytes) = await service.download(
        controlVideos.first.$1,
        estimate,
        cancelToken: CancelToken(),
        onProgress: (_, _) {},
      );
      final file = File('${dir.path}${Platform.pathSeparator}downloads${Platform.pathSeparator}$fileName');
      final onDisk = file.existsSync() ? file.lengthSync() : bytes;
      debugPrint('=== DESCARGA PC: ${estimate.path}, $bytes bytes (YouTube dijo ${estimate.sizeBytes}), '
          '${watch.elapsed.inSeconds} s ===');
      expect(bytes, estimate.sizeBytes);
      expect(onDisk, estimate.sizeBytes);
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
