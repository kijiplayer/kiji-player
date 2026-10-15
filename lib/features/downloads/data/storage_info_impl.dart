import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/storage_info.dart';

/// Elige la implementación de [StorageInfo] según la plataforma.
StorageInfo createStorageInfo() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidStorageInfo();
  }
  // Windows/Linux/macOS: pendiente para la Tarea X.
  return const UnknownStorageInfo();
}

/// Android: pregunta a `StatFs` mediante el canal `kiji/storage`
/// (implementado en `MainActivity.kt`).
class AndroidStorageInfo implements StorageInfo {
  static const _channel = MethodChannel('kiji/storage');

  @override
  Future<int?> freeBytes(String path) async {
    try {
      return await _channel.invokeMethod<int>('freeBytes', {'path': path});
    } catch (error) {
      debugPrint('=== DESCARGAS: no se pudo leer el espacio libre: $error ===');
      return null;
    }
  }
}

/// Plataformas donde todavía no sabemos preguntar el espacio libre.
class UnknownStorageInfo implements StorageInfo {
  const UnknownStorageInfo();

  @override
  Future<int?> freeBytes(String path) async => null;
}
