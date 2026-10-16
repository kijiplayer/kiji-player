import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/system_media/data/system_media_controls_factory.dart';
import 'providers/system_media_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Controles del sistema (notificación, pantalla de bloqueo, auriculares).
  // Se inician antes de la app para que el servicio de audio esté listo.
  final systemMediaControls = await createSystemMediaControls();

  runApp(
    ProviderScope(
      overrides: [
        systemMediaControlsProvider.overrideWithValue(systemMediaControls),
      ],
      child: const KijiApp(),
    ),
  );
}
