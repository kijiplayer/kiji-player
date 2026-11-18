import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/update_assets.dart';
import '../domain/update_installer.dart';
import '../update_checker.dart';

/// Android: el APK de la arquitectura del teléfono, el certificado comparado con el de Kiji y el
/// instalador del sistema (FileProvider). Lado nativo: `AppUpdater.kt`.
class AndroidUpdateInstaller implements UpdateInstaller {
  AndroidUpdateInstaller({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('kiji/update');

  final MethodChannel _channel;

  @override
  Future<ReleaseAsset?> pickAsset(Release release) async {
    final abis = await _channel.invokeListMethod<String>('abis') ?? const <String>[];
    final asset = pickAndroidAsset(abis, release.assets, release.version);
    debugPrint('=== ACTUALIZAR: ABI ${abis.isEmpty ? '?' : abis.first} → ${asset?.name ?? 'ninguno'} ===');
    return asset;
  }

  /// Android ya pregunta en su instalador.
  @override
  bool get confirmBeforeInstall => false;

  @override
  Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  @override
  Future<void> openInstallPermission() => _channel.invokeMethod<void>('openInstallPermission');

  @override
  Future<bool?> sameSigner(File file) async => await _channel.invokeMethod<bool>('sameSigner', file.path) ?? false;

  @override
  Future<void> install(File file) => _channel.invokeMethod<void>('install', file.path);
}
