// Diagnóstico de descargas, solo PC: pasa una lista de videos por los motores B y C
// y muestra, para cada uno, qué camino lo resolvió o por qué falló (texto clasificado).
// SOLO EN PC: flutter test integration_test/download_diagnosis_test.dart -d windows
// Los ids se pasan con --dart-define=KIJI_IDS=id1,id2 (sin ids usa las canciones de control).

import 'dart:io';

import 'package:flutter/material.dart' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiji_player/features/extractor/data/alternatives.dart';
import 'package:kiji_player/features/extractor/data/engines.dart';
import 'package:kiji_player/features/extractor/data/extractor_tester.dart';
import 'package:kiji_player/features/extractor/data/path_health.dart';
import 'package:kiji_player/features/extractor/data/stream_resolver.dart';
import 'package:kiji_player/features/extractor/data/ytdlp_engine.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';
import 'package:kiji_player/models/track.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('diagnóstico de videos que no bajan', (tester) async {
    const raw = String.fromEnvironment('KIJI_IDS');
    final ids = raw.isEmpty ? [for (final c in controlVideos) c.$1] : raw.split(',');
    final dir = Directory.systemTemp.createTempSync('kiji_diag');
    final ytdlp = YtDlpEngine(directory: () async => dir, accepted: () => true);
    await tester.runAsync(() async {
      await ytdlp.install(onProgress: (d, t) {});
      final client = YtMusicClient();
      final resolver = StreamResolver(
        engines: [KijiEngine(client), ytdlp],
        health: PathHealth(directory: () async => dir.path),
      );
      // --dart-define=KIJI_TRACKS="id|título|artista|ms;…" para probar también "Buscar otra versión".
      const rawTracks = String.fromEnvironment('KIJI_TRACKS');
      final tracks = {
        for (final t in rawTracks.split(';').where((t) => t.isNotEmpty))
          t.split('|')[0]: Track(
            id: 'yt-${t.split('|')[0]}',
            title: t.split('|')[1],
            artist: t.split('|')[2],
            durationMs: int.parse(t.split('|')[3]),
            coverColor: const Color(0xFF7C5CFF),
            audioUrl: '',
            source: TrackSource.youtube,
          ),
      };
      final finder = AlternativeFinder(client, directory: () async => dir.path);
      for (final id in [...ids, ...tracks.keys.where((k) => !ids.contains(k))]) {
        final out = await resolver.resolve(id);
        final track = tracks[id];
        if (out.stream == null && track != null) {
          final alt = await finder.find(track);
          final again = alt == null ? null : await resolver.resolve(alt);
          debugPrint('=== DIAGNOSTICO $id: otra versión → ${alt ?? 'ninguna'} ${again?.stream ?? again?.problem?.name ?? ''} ===');
        }
        debugPrint('=== DIAGNOSTICO $id: '
            '${out.stream ?? (out.problem != null ? 'CONTENIDO ${out.problem!.name}' : 'FALLÓ')} ===');
        for (final (path, failure) in out.failures) {
          debugPrint('===    $path → $failure ===');
        }
        if (out.stream != null && !out.stream!.isHls) {
          final problem = await ExtractorTester(client: client).lastByteCheck(out.stream!);
          debugPrint('===    último byte: ${problem ?? 'OK'} ===');
        }
      }
      await ytdlp.remove();
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
