// Experimento de la Tarea Z8 (solo PC): con el PO token de la URL ligado al VIDEO (reglas de
// InnerTubeX 0.10.0), ¿las formas web entregan el archivo entero?
// SOLO EN PC: flutter test integration_test/potoken_binding_test.dart -d windows

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiji_player/features/yt_music/data/yt_clients.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PO token ligado al video: formas web enteras', (tester) async {
    final client = YtMusicClient();
    for (final id in ['BSTsnWoslP4', 'BycLmWI97Nc', '8Xv_Hg8o1fw']) {
      for (final label in ['WEB_REMIX', 'MWEB', 'TVHTML5', 'TVHTML5_SIMPLY']) {
        final a = await client.tryClient(id, clientByLabel(label)!);
        debugPrint('=== POT $label $id: ${a.ok ? 'OK, entero' : a.reason} ===');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
