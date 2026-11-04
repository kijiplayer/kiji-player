import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/screen_mode.dart';

/// PC: la ventana a pantalla completa (`window_manager`). Teléfono: modo inmersivo (las barras del
/// sistema aparecen al deslizar desde el borde y se vuelven a esconder).
class PlatformScreenMode implements ScreenMode {
  @override
  Future<void> setFullScreen(bool on) async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        await windowManager.setFullScreen(on);
      } else {
        await SystemChrome.setEnabledSystemUIMode(on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
      }
    } catch (error) {
      debugPrint('=== LETRAS: no se pudo cambiar la pantalla completa: $error ===');
    }
  }
}

final screenModeProvider = Provider<ScreenMode>((ref) => PlatformScreenMode());
