// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
import 'dart:ffi';
import 'dart:io';

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
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    return LinuxStorageInfo();
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    return MacStorageInfo();
  }
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
      final getDiskFreeSpaceEx = kernel32
          .lookupFunction<
            Int32 Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>),
            int Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>)
          >('GetDiskFreeSpaceExW');
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

/// Linux: `statvfs` de la libc por FFI. En Linux de 64 bits (x86_64 y arm64, glibc o musl) la
/// estructura empieza con `f_bsize`, `f_frsize`, `f_blocks`, `f_bfree` y `f_bavail`, de 8 bytes
/// cada uno: libres para el usuario = `f_bavail × f_frsize`.
class LinuxStorageInfo implements StorageInfo {
  static const _frsizeOffset = 8;
  static const _bavailOffset = 32;

  @override
  Future<int?> freeBytes(String path) async {
    try {
      final libc = DynamicLibrary.process();
      final statvfs = libc
          .lookupFunction<Int32 Function(Pointer<Utf8>, Pointer<Uint8>), int Function(Pointer<Utf8>, Pointer<Uint8>)>(
            'statvfs',
          );
      final nativePath = path.toNativeUtf8();
      // Más grande que la estructura real (112 bytes en glibc): sobra lugar.
      final buffer = calloc<Uint8>(256);
      try {
        if (statvfs(nativePath, buffer) != 0) {
          debugPrint('=== DESCARGAS: statvfs no pudo leer $path ===');
          return null;
        }
        final data = buffer.asTypedList(256).buffer.asByteData();
        final frsize = data.getUint64(_frsizeOffset, Endian.host);
        final bavail = data.getUint64(_bavailOffset, Endian.host);
        return frsize * bavail;
      } finally {
        calloc.free(nativePath);
        calloc.free(buffer);
      }
    } catch (error) {
      debugPrint('=== DESCARGAS: no se pudo leer el espacio libre en Linux: $error ===');
      return null;
    }
  }
}

/// macOS: `df -Pk` (el `statvfs` de macOS cuenta los bloques con 32 bits y se desborda en discos
/// grandes).
class MacStorageInfo implements StorageInfo {
  @override
  Future<int?> freeBytes(String path) async {
    try {
      final result = await Process.run('df', ['-Pk', path]);
      if (result.exitCode != 0) {
        debugPrint('=== DESCARGAS: df terminó con ${result.exitCode}: ${result.stderr} ===');
        return null;
      }
      return parseDfAvailableBytes('${result.stdout}');
    } catch (error) {
      debugPrint('=== DESCARGAS: no se pudo leer el espacio libre en macOS: $error ===');
      return null;
    }
  }
}

/// Bytes disponibles en la salida de `df -Pk <ruta>` (formato POSIX: la columna "Available" de
/// la segunda línea, en bloques de 1024). null si no se entiende.
int? parseDfAvailableBytes(String output) {
  final lines = output.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.length < 2) return null;
  final columns = lines.last.trim().split(RegExp(r'\s+'));
  if (columns.length < 4) return null;
  final kilobytes = int.tryParse(columns[3]);
  return kilobytes == null ? null : kilobytes * 1024;
}

/// Plataformas donde todavía no sabemos preguntar el espacio libre.
class UnknownStorageInfo implements StorageInfo {
  const UnknownStorageInfo();

  @override
  Future<int?> freeBytes(String path) async => null;
}
