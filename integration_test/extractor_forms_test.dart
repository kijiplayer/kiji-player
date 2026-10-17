// Prueba cada forma del extractor con canciones reales, dentro de la app
// (con la WebView real del solver). Se corre a mano, SOLO EN PC:
//   flutter test integration_test/extractor_forms_test.dart -d windows
// NUNCA en el celular real: `flutter test` desinstala la app y borra sus datos
//. En el celular se usa el botón
// "Probar todas las formas ahora" de la Salud del Extractor.
// Escribe la tabla en el log con el prefijo "=== DIAG".

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiji_player/features/yt_music/data/yt_clients.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';

const _queries = [
  'daft punk get lucky', 'bad bunny tití me preguntó', 'soda stereo de música ligera',
  'the weeknd blinding lights', 'shakira hips dont lie', 'queen bohemian rhapsody',
  'karol g provenza', 'coldplay yellow', 'rosalía despechá', 'billie eilish bad guy',
  'cerati crimen', 'dua lipa levitating', 'eminem lose yourself', 'taylor swift anti hero',
  'peso pluma ella baila sola', 'radiohead creep', 'c418 sweden', 'lil peep star shopping',
  'arctic monkeys do i wanna know', 'mana rayando el sol',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cada forma por separado con 20 canciones', (tester) async {
    final songs = int.tryParse(const String.fromEnvironment('KIJI_SONGS')) ?? _queries.length;
    final client = YtMusicClient();
    final ids = <String>[];
    for (final q in _queries.take(songs)) {
      final results = await client.search(q, songsOnly: true);
      if (results.isNotEmpty) ids.add(results.first.videoId);
    }
    final report = StringBuffer('canciones: ${ids.length}\n');
    var working = 0;
    for (final form in ytPlayerClients) {
      var ok = 0;
      final reasons = <String, int>{};
      final watch = Stopwatch()..start();
      for (final id in ids) {
        final attempt = await client.tryClient(id, form);
        if (attempt.ok) {
          ok++;
        } else {
          reasons[attempt.reason!] = (reasons[attempt.reason!] ?? 0) + 1;
        }
      }
      if (ok == ids.length) working++;
      report.writeln('${form.label}: $ok/${ids.length} (${watch.elapsed.inMilliseconds ~/ ids.length} ms c/u)');
      for (final r in reasons.entries) {
        report.writeln('    ${r.value}× ${r.key}');
      }
    }
    report.writeln('formas que funcionan con todas: $working');
    for (final line in report.toString().split('\n')) {
      debugPrint('=== DIAG $line');
    }
    expect(working, greaterThanOrEqualTo(3));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
