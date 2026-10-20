// Traducción en el dispositivo con Bergamot. SOLO EN PC:
//   flutter test integration_test/translation_test.dart -d windows
// NUNCA en el celular real. Usa texto inventado, nunca letras reales.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiji_player/features/translation/data/bergamot_engine.dart';
import 'package:kiji_player/features/translation/data/bergamot_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('en→es y pt→es (pivote) dentro del dispositivo', (tester) async {
    final models = BergamotModels();
    final engine = BergamotEngine(models);
    for (final (from, lines) in [
      ('en', ['The sun is warm today', 'We walk along the river']),
      ('pt', ['O sol está quente hoje', 'Caminhamos ao longo do rio']),
    ]) {
      final route = (await models.route(from, 'es'))!;
      final missing = await models.missingBytes(route);
      debugPrint('=== TRAD $from→es ruta=${route.map(pairKey).join(' + ')} faltan ${(missing / 1048576).toStringAsFixed(1)} MB');
      await models.install(route);
      final watch = Stopwatch()..start();
      final out = await engine.translate(route, lines);
      debugPrint('=== TRAD $from→es ${watch.elapsedMilliseconds} ms: ${out.join(' | ')}');
      expect(out, hasLength(lines.length));
      expect(out.every((l) => l.trim().isNotEmpty), isTrue);
    }
    await engine.close();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
