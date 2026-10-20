// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Guarda secretos (como la clave de Gemini) **cifrados y solo en este
/// dispositivo**. Interfaz propia:
/// - Android: clave AES-GCM del Android Keystore (canal `kiji/secrets` en
///   MainActivity); la clave nunca sale del Keystore.
/// - Windows: DPAPI (`CryptProtectData`), ligado a la cuenta de Windows.
/// - Otras plataformas: no se guarda nada (devuelve false).
/// Los secretos nunca se escriben en logs.
abstract class SecretStore {
  bool get isSupported;
  Future<bool> write(String name, String value);
  Future<String?> read(String name);
  Future<void> delete(String name);
}

SecretStore createSecretStore() {
  if (kIsWeb) return const _NoSecrets();
  if (Platform.isAndroid) return _FileSecretStore(_AndroidKeystoreCipher());
  if (Platform.isWindows) return _FileSecretStore(_DpapiCipher());
  return const _NoSecrets();
}

abstract class _Cipher {
  Future<List<int>> encrypt(List<int> plain);
  Future<List<int>> decrypt(List<int> data);
}

class _FileSecretStore implements SecretStore {
  _FileSecretStore(this._cipher);
  final _Cipher _cipher;

  @override
  bool get isSupported => true;

  Future<File> _file(String name) async {
    final safe = name.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return File(p.join((await getApplicationSupportDirectory()).path, 'secrets', '$safe.bin'));
  }

  @override
  Future<bool> write(String name, String value) async {
    try {
      final file = await _file(name);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(await _cipher.encrypt(utf8.encode(value)), flush: true);
      return true;
    } catch (error) {
      debugPrint('=== SECRETOS: no se pudo guardar "$name" (${error.runtimeType}) ===');
      return false;
    }
  }

  @override
  Future<String?> read(String name) async {
    try {
      final file = await _file(name);
      if (!await file.exists()) return null;
      return utf8.decode(await _cipher.decrypt(await file.readAsBytes()));
    } catch (error) {
      debugPrint('=== SECRETOS: no se pudo leer "$name" (${error.runtimeType}) ===');
      return null;
    }
  }

  @override
  Future<void> delete(String name) async {
    final file = await _file(name);
    if (await file.exists()) await file.delete();
  }
}

class _AndroidKeystoreCipher implements _Cipher {
  static const _channel = MethodChannel('kiji/secrets');
  @override
  Future<List<int>> encrypt(List<int> plain) async =>
      (await _channel.invokeMethod<Uint8List>('encrypt', {'data': Uint8List.fromList(plain)}))!;
  @override
  Future<List<int>> decrypt(List<int> data) async =>
      (await _channel.invokeMethod<Uint8List>('decrypt', {'data': Uint8List.fromList(data)}))!;
}

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _ProtectC = Int32 Function(
    Pointer<_DataBlob>, Pointer<Utf16>, Pointer<Void>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<_DataBlob>);
typedef _ProtectDart = int Function(
    Pointer<_DataBlob>, Pointer<Utf16>, Pointer<Void>, Pointer<Void>, Pointer<Void>, int, Pointer<_DataBlob>);
typedef _UnprotectC = Int32 Function(
    Pointer<_DataBlob>, Pointer<Pointer<Utf16>>, Pointer<Void>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<_DataBlob>);
typedef _UnprotectDart = int Function(
    Pointer<_DataBlob>, Pointer<Pointer<Utf16>>, Pointer<Void>, Pointer<Void>, Pointer<Void>, int, Pointer<_DataBlob>);

/// DPAPI de Windows (crypt32.dll), por FFI: sin plugins.
class _DpapiCipher implements _Cipher {
  static final _crypt32 = DynamicLibrary.open('crypt32.dll');
  static final _kernel32 = DynamicLibrary.open('kernel32.dll');
  static final _protect = _crypt32.lookupFunction<_ProtectC, _ProtectDart>('CryptProtectData');
  static final _unprotect = _crypt32.lookupFunction<_UnprotectC, _UnprotectDart>('CryptUnprotectData');
  static final _localFree = _kernel32.lookupFunction<Pointer<Void> Function(Pointer<Void>), Pointer<Void> Function(Pointer<Void>)>('LocalFree');
  static const _uiForbidden = 0x1;

  List<int> _run(List<int> input, bool protect) {
    final inBlob = calloc<_DataBlob>();
    final outBlob = calloc<_DataBlob>();
    final buffer = calloc<Uint8>(input.isEmpty ? 1 : input.length);
    try {
      buffer.asTypedList(input.length).setAll(0, input);
      inBlob.ref
        ..cbData = input.length
        ..pbData = buffer;
      final ok = protect
          ? _protect(inBlob, nullptr, nullptr, nullptr, nullptr, _uiForbidden, outBlob)
          : _unprotect(inBlob, nullptr, nullptr, nullptr, nullptr, _uiForbidden, outBlob);
      if (ok == 0) throw StateError('DPAPI falló');
      final result = List<int>.from(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
      _localFree(outBlob.ref.pbData.cast());
      return result;
    } finally {
      calloc.free(buffer);
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }

  @override
  Future<List<int>> encrypt(List<int> plain) async => _run(plain, true);
  @override
  Future<List<int>> decrypt(List<int> data) async => _run(data, false);
}

class _NoSecrets implements SecretStore {
  const _NoSecrets();
  @override
  bool get isSupported => false;
  @override
  Future<bool> write(String name, String value) async => false;
  @override
  Future<String?> read(String name) async => null;
  @override
  Future<void> delete(String name) async {}
}
