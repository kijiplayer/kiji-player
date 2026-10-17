// Reproduce de verdad cada forma que resuelve (Tarea Z1), en silencio: arranca,
// salta cerca del final y verifica que avance. Usa checkPlays, lo mismo que el
// botón "Probar todas las formas ahora".
//
// SOLO EN PC: flutter test integration_test/extractor_playback_test.dart -d windows
// NUNCA en el celular real: `flutter test` desinstala la app y borra sus datos
//. En el celular se usa el botón de la app.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:kiji_player/features/yt_music/data/playback_probe.dart';
import 'package:kiji_player/features/yt_music/data/yt_clients.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized(windows: true, linux: true);

  testWidgets('las formas que resuelven suenan enteras', (tester) async {
    final client = YtMusicClient();
    var playing = 0;
    for (final form in ytPlayerClients) {
      final attempt = await client.tryClient('sWft4cMiwXQ', form); // De Música Ligera, 3:32
      if (!attempt.ok) {
        debugPrint('=== PLAY ${form.label}: no resolvió (${attempt.reason})');
        continue;
      }
      final problem = await checkPlays(attempt, form);
      if (problem == null) playing++;
      debugPrint('=== PLAY ${form.label}: ${problem ?? 'suena entera'}');
    }
    expect(playing, greaterThanOrEqualTo(3));
  }, timeout: const Timeout(Duration(minutes: 8)));
}
