import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_icon.dart';

/// Android (`AppIcon.kt`, alias del lanzador) y Windows (runner, `WM_SETICON`): mismo canal.
class ChannelAppIconChanger extends AppIconChanger {
  const ChannelAppIconChanger({this.channel = const MethodChannel('kiji/icon'), required this.appliesOnExit});

  final MethodChannel channel;

  @override
  final bool appliesOnExit;

  @override
  bool get supported => true;

  @override
  Future<String> current() async {
    try {
      return await channel.invokeMethod<String>('current') ?? defaultAppIcon;
    } catch (error) {
      debugPrint('=== ICONO: no se pudo saber el ícono actual: ${error.runtimeType} ===');
      return defaultAppIcon;
    }
  }

  @override
  Future<bool> apply(String variant) async {
    try {
      final ok = await channel.invokeMethod<bool>('apply', variant) ?? false;
      debugPrint('=== ICONO: $variant ${ok ? 'puesto' : 'no se pudo poner'} ===');
      return ok;
    } catch (error) {
      debugPrint('=== ICONO: no se pudo cambiar a $variant: ${error.runtimeType} ===');
      return false;
    }
  }
}

class UnsupportedAppIconChanger extends AppIconChanger {
  const UnsupportedAppIconChanger();
  @override
  bool get supported => false;
  @override
  bool get appliesOnExit => false;
  @override
  Future<String> current() async => defaultAppIcon;
  @override
  Future<bool> apply(String variant) async => false;
}

final appIconChangerProvider = Provider<AppIconChanger>((ref) {
  if (kIsWeb) return const UnsupportedAppIconChanger();
  if (Platform.isAndroid) return const ChannelAppIconChanger(appliesOnExit: true);
  if (Platform.isWindows) return const ChannelAppIconChanger(appliesOnExit: false);
  return const UnsupportedAppIconChanger();
});
