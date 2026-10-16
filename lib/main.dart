import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'app.dart';
import 'features/system_media/data/system_media_controls_factory.dart';
import 'providers/system_media_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Errores asíncronos que nadie capturó (por ejemplo, el proxy de la caché
  // de just_audio cuando se corta la red): se registran y la app sigue. El
  // reproductor se entera por su propio canal de errores (Modo de Gracia).
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('=== ERROR NO CAPTURADO: $error ===');
    debugPrint('$stackTrace');
    return true;
  };

  // Windows y Linux: just_audio no trae motor propio; usa media_kit (libmpv).
  // En Android/iOS/macOS no hace nada.
  JustAudioMediaKit.ensureInitialized(windows: true, linux: true);

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
