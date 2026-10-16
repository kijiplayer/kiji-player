import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/storage_info.dart';

/// Elige la implementación de [StorageInfo] según la plataforma.
StorageInfo createStorageInfo() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidStorageInfo();
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    return WindowsStorageInfo();
  }
  // Linux/macOS: pendiente (statvfs por FFI).
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

/// Windows: `GetDiskFreeSpaceExW` de kernel32 por FFI (sin plugins).
class WindowsStorageInfo implements StorageInfo {
  @override
  Future<int?> freeBytes(String path) async {
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final getDiskFreeSpaceEx = kernel32.lookupFunction<
          Int32 Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>),
          int Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>,
              Pointer<Uint64>)>('GetDiskFreeSpaceExW');
      final nativePath = path.toNativeUtf16();
      final available = calloc<Uint64>();
      try {
        final ok = getDiskFreeSpaceEx(nativePath, available, nullptr, nullptr);
        return ok == 0 ? null : available.value;
      } finally {
        calloc.free(nativePath);
        calloc.free(available);
      }
    } catch (error) {
      debugPrint('=== DESCARGAS: no se pudo leer el espacio libre en Windows: $error ===');
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
