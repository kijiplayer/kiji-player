// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'features/dev_tools/dev_build.dart';
import 'features/dev_tools/frame_stats.dart';
import 'features/migrations/data_migrations.dart';
import 'features/reports/data/error_reporter.dart';
import 'features/system_media/data/system_media_controls_factory.dart';
import 'providers/system_media_provider.dart';
import 'utils/app_log.dart';
import 'utils/startup_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Registro en memoria para ver en vivo en Kiji Dev.
  AppLog.install();
  // Registro del arranque (bug de Windows): cada fase con su tiempo.
  StartupLog.start();

  // Errores asíncronos que nadie capturó (por ejemplo, el proxy de la caché
  // de just_audio cuando se corta la red): se registran y la app sigue. El
  // reproductor se entera por su propio canal de errores (Modo de Gracia).
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('=== ERROR NO CAPTURADO: $error ===');
    StartupLog.mark('error no capturado: ${error.runtimeType}');
    debugPrint('$stackTrace');
    // Registros e informes: se ofrece mandar un informe (los cortes de red no).
    ErrorReporter.instance.capture(error, stackTrace, where: 'segundo plano');
    return true;
  };
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.instance.captureFlutter(details);
  };

  // Datos de una versión anterior: se ponen al día antes de que nada los lea, con una copia
  // interna antes de tocarlos. Si algo falla, vuelven como estaban y se ofrece un informe.
  await StartupLog.guard('migraciones', () async {
    final result = await DataMigrator(await getApplicationSupportDirectory()).run();
    StartupLog.mark('datos: $result');
    if (result.outcome == MigrationOutcome.failedRestored) {
      ErrorReporter.instance.capture(result.error!, StackTrace.current, where: 'migraciones');
    }
  }, limit: const Duration(seconds: 20));

  // Windows y Linux: just_audio no trae motor propio; usa media_kit (libmpv).
  // En Android/iOS/macOS no hace nada.
  JustAudioMediaKit.ensureInitialized(windows: true, linux: true);
  StartupLog.mark('media_kit registrado');

  // Controles del sistema (notificación, pantalla de bloqueo, auriculares).
  // Se inician antes de la app para que el servicio de audio esté listo.
  // Con límite de tiempo: si se traba, la app arranca igual sin ellos.
  final systemMediaControls = await StartupLog.guard('controles del sistema', createSystemMediaControls,
          limit: const Duration(seconds: 5)) ??
      const NoSystemMediaControls();
  // Kiji Dev: medidor de cuadros en el registro (rendimiento).
  if (isDevBuild) FrameStats.start();
  StartupLog.mark('runApp');

  runApp(
    ProviderScope(
      overrides: [
        systemMediaControlsProvider.overrideWithValue(systemMediaControls),
      ],
      child: const KijiApp(),
    ),
  );
}
