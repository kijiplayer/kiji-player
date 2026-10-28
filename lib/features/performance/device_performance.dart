import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lo que importa del equipo para el "Modo alto rendimiento". Se mira en el dispositivo; nada sale
/// de él.
class DeviceInfo {
  const DeviceInfo({this.totalRamBytes = 0, this.lowRam = false, this.cores = 0, this.maxRefresh = 60});

  /// 0 si no se sabe.
  final int totalRamBytes;

  /// Android lo marca como "de poca memoria".
  final bool lowRam;
  final int cores;

  /// La frecuencia más alta de la pantalla (Hz).
  final double maxRefresh;

  static const _gb = 1024 * 1024 * 1024;

  /// Gama baja: Android lo dice, tiene menos de 4 GB de RAM o 4 núcleos o menos.
  bool get lowEnd => lowRam || (totalRamBytes > 0 && totalRamBytes < 4 * _gb) || (cores > 0 && cores <= 4);
}

const _channel = MethodChannel('kiji/display');

final deviceInfoProvider = FutureProvider<DeviceInfo>((ref) async {
  final cores = Platform.numberOfProcessors;
  if (kIsWeb || !Platform.isAndroid) return DeviceInfo(cores: cores);
  try {
    final info = await _channel.invokeMapMethod<String, Object?>('deviceInfo') ?? const {};
    return DeviceInfo(
      totalRamBytes: (info['totalRam'] as num?)?.toInt() ?? 0,
      lowRam: info['lowRam'] == true,
      cores: cores,
      maxRefresh: (info['maxRefresh'] as num?)?.toDouble() ?? 60,
    );
  } catch (error) {
    debugPrint('=== RENDIMIENTO: no se pudo leer el equipo: $error ===');
    return DeviceInfo(cores: cores);
  }
});

/// Android: pide (o deja de pedir) la frecuencia más alta de la pantalla. En la PC, Flutter ya
/// dibuja a la frecuencia del monitor.
Future<void> applyHighRefreshRate(bool on) async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final hz = await _channel.invokeMethod<double>('setHighRefreshRate', on);
    debugPrint(
      on
          ? '=== RENDIMIENTO: pantalla a ${hz?.round() ?? '?'} Hz (alto rendimiento) ==='
          : '=== RENDIMIENTO: alto rendimiento apagado; la frecuencia la elige el sistema ===',
    );
  } catch (error) {
    debugPrint('=== RENDIMIENTO: no se pudo cambiar la frecuencia de la pantalla: $error ===');
  }
}
