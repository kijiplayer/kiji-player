import 'dart:async';
import 'dart:io' as io;

import 'dart:ffi' hide Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../yt_music/data/ytm_client.dart';

/// Ventana de la PC (Windows, Linux, macOS). Kiji intercepta el cierre para apagarse en orden:
/// guarda, cierra las WebView y sale del proceso.
///
/// Por qué no se destruye la ventana como siempre: en Windows, el plugin de WebView
/// (flutter_inappwebview_windows 0.7.0-beta.3) quita sus canales en sus destructores, que corren
/// DESPUÉS de que se apaga el motor de Flutter, y Kiji terminaba con error cada vez que se cerraba
/// con una WebView abierta (violación de acceso en `FlutterDesktopMessengerSetCallback`; se ve en
/// el Visor de eventos). Saliendo del proceso una vez guardado todo, esos destructores no corren.
/// Los procesos de WebView2 se cierran solos al terminar el de Kiji.
class DesktopWindow with WindowListener {
  DesktopWindow._();

  static final instance = DesktopWindow._();

  static bool get isDesktop => !kIsWeb && (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS);

  /// Qué hacer antes de salir (guardar la cola, etc.). Lo pone la app.
  Future<void> Function()? beforeExit;

  bool _exiting = false;

  /// Tamaño mínimo de la ventana.
  static const minimumSize = Size(360, 560);

  static Future<void> init() async {
    if (!isDesktop) return;
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(instance);
    // Después del primer cuadro: recién ahí se conoce la escala de la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_applyMinimumSize()));
  }

  /// Más chica que un celular chico, los textos ya no entran. window_manager mide la ventana con su
  /// marco (bordes y barra de título), así que se suma el marco al área de Flutter.
  static Future<void> _applyMinimumSize() async {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final inside = view.physicalSize / view.devicePixelRatio;
      final outside = await windowManager.getSize();
      final frame = Size(
        (outside.width - inside.width).clamp(0, 64).toDouble(),
        (outside.height - inside.height).clamp(0, 96).toDouble(),
      );
      await windowManager.setMinimumSize(Size(minimumSize.width + frame.width, minimumSize.height + frame.height));
    } catch (error) {
      debugPrint('=== VENTANA: no se pudo poner el tamaño mínimo: $error ===');
    }
  }

  @override
  void onWindowClose() => unawaited(exit());

  /// Sale de Kiji en orden. Cada paso tiene un tiempo máximo: nada puede dejar la ventana colgada.
  Future<void> exit() async {
    if (_exiting) return;
    _exiting = true;
    debugPrint('=== VENTANA: cerrando Kiji en orden ===');
    Future<void> step(String name, Future<void> Function()? action) async {
      if (action == null) return;
      try {
        await action().timeout(const Duration(seconds: 3));
      } catch (error) {
        debugPrint('=== VENTANA: al cerrar ($name): $error ===');
      }
    }

    await step('guardar', beforeExit);
    await step('solver', YtMusicClient.sharedSolver.close);
    await step('potoken', YtMusicClient.sharedPoTokens.close);
    await step('ocultar', windowManager.hide);
    debugPrint('=== VENTANA: listo, se sale ===');
    // Un momento para que el registro llegue al disco.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _terminate();
  }

  /// Termina el proceso sin correr destructores. En Windows, `exit()` corre los destructores de
  /// C++ y de cada DLL, y alguno aborta (0xC0000409); `TerminateProcess` no corre ninguno. Todo
  /// lo importante ya se guardó y se cerró antes.
  static Never _terminate() {
    if (io.Platform.isWindows) {
      try {
        final kernel32 = DynamicLibrary.open('kernel32.dll');
        final current = kernel32.lookupFunction<IntPtr Function(), int Function()>('GetCurrentProcess'); // l10n-ignore
        final terminate = kernel32.lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
          'TerminateProcess', // l10n-ignore
        );
        terminate(current(), 0);
      } catch (error) {
        debugPrint('=== VENTANA: no se pudo terminar el proceso: $error ===');
      }
    }
    io.exit(0);
  }
}
