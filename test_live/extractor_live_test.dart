// Prueba EN VIVO del extractor contra YouTube real (GitHub Actions la corre una vez por día).
// No va en test/ para que `flutter test` siga sin salir a internet. A mano:
//   flutter test test_live/extractor_live_test.dart
// Deja un resumen en build/extractor_live.md (la Action lo usa para abrir el issue si falla).
//
// Sin WebView (en un servidor no hay): se prueban la búsqueda y las formas que no necesitan el
// solver ni el PO token (hoy, VISIONOS), con las canciones de control, pidiendo el ÚLTIMO byte
// del audio (así se detectan las formas que cortan en el primer minuto).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/extractor/data/extractor_tester.dart';
import 'package:kiji_player/features/yt_music/data/yt_clients.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';

void main() {
  final lines = <String>[];
  void log(String line) {
    lines.add(line);
    // ignore: avoid_print
    print(line);
  }

  tearDownAll(() {
    final out = File('build/extractor_live.md')..parent.createSync(recursive: true);
    out.writeAsStringSync('${lines.join('\n')}\n');
  });

  final client = YtMusicClient();
  final direct = [
    for (final c in ytPlayerClients)
      if (!c.isRetired && !c.useHls && !c.needsPlayerScript && !c.usesPoToken) c,
  ];

  test('La búsqueda de YouTube Music devuelve canciones', () async {
    final results = await client.search('Bohemian Rhapsody Queen', songsOnly: true);
    log('### Búsqueda');
    log('- "Bohemian Rhapsody Queen": ${results.length} resultados'
        '${results.isEmpty ? '' : ' (primero: ${results.first.title} · ${results.first.artist}, ${results.first.videoId})'}');
    expect(results, isNotEmpty, reason: 'La búsqueda no devolvió canciones: puede haber cambiado la respuesta.');
    expect(results.first.videoId, matches(RegExp(r'^[\w-]{11}$')));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Las formas sin WebView dan el audio entero de las canciones de control', () async {
    expect(direct, isNotEmpty, reason: 'No queda ninguna forma que funcione sin WebView en yt_clients.dart.');
    log('### Audio (formas sin WebView: ${direct.map((c) => c.label).join(', ')})');
    log('| Canción de control | Forma | Resultado |');
    log('|---|---|---|');
    var ok = 0;
    for (final (videoId, name) in controlVideos) {
      var songOk = false;
      for (final c in direct) {
        final attempt = await client.tryClient(videoId, c);
        log('| $name (`$videoId`) | ${c.label} | ${attempt.ok ? '✅ entera (${attempt.contentLength ?? '?'} bytes, ${attempt.elapsed.inMilliseconds} ms)' : '❌ ${attempt.reason}'} |');
        if (attempt.ok) songOk = true;
      }
      if (songOk) ok++;
    }
    log('');
    log('Canciones de control que se pueden bajar enteras: $ok de ${controlVideos.length}.');
    // Una sola puede fallar por algo de esa canción; si fallan dos o más, se rompió algo.
    expect(ok, greaterThanOrEqualTo(controlVideos.length - 1),
        reason: 'YouTube no está dando el audio entero: ver docs/EXTRACTOR.md.');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
