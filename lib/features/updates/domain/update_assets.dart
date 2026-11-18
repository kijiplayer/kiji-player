import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Un archivo de una versión publicada en GitHub (APK o instalador).
@immutable
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, required this.size, this.digest});

  final String name;

  /// Dirección de descarga (`browser_download_url`).
  final String url;
  final int size;

  /// SHA-256 que publica GitHub para el archivo (sin el "sha256:"), si lo trae.
  final String? digest;

  static ReleaseAsset? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = '${json['name'] ?? ''}'.trim();
    final url = '${json['browser_download_url'] ?? ''}'.trim();
    if (name.isEmpty || url.isEmpty) return null;
    final digest = '${json['digest'] ?? ''}'.trim().toLowerCase();
    return ReleaseAsset(
      name: name,
      url: url,
      size: json['size'] is int ? json['size'] as int : 0,
      digest: digest.startsWith('sha256:') && isSha256(digest.substring(7)) ? digest.substring(7) : null,
    );
  }
}

/// El archivo con las sumas SHA-256 de todos los demás (lo arma `release.yml`).
const sha256SumsName = 'SHA256SUMS.txt';

/// Instalador de Windows con nombre fijo.
const windowsSetupName = 'Kiji-Player-Windows-Setup.exe';

/// APK universal con nombre fijo (sirve en cualquier teléfono).
const universalApkName = 'Kiji-Player.apk';

/// Qué APK bajar según la arquitectura principal del teléfono ([abis] es `Build.SUPPORTED_ABIS`,
/// la preferida primero). arm64-v8a: `Kiji-Player-arm64.apk`; armeabi-v7a o x86_64: el de su
/// arquitectura si está; si no, el universal. null si la versión no trae ninguno de esos.
ReleaseAsset? pickAndroidAsset(List<String> abis, List<ReleaseAsset> assets, String version) {
  ReleaseAsset? named(String name) => assets.where((a) => a.name == name).firstOrNull;
  final primary = abis.isEmpty ? '' : abis.first;
  final specific = switch (primary) {
    'arm64-v8a' => named('Kiji-Player-arm64.apk') ?? named('Kiji-Player-$version-arm64-v8a.apk'),
    'armeabi-v7a' => named('Kiji-Player-$version-armeabi-v7a.apk'),
    'x86_64' => named('Kiji-Player-$version-x86_64.apk'),
    _ => null,
  };
  return specific ?? named(universalApkName) ?? named('Kiji-Player-$version.apk');
}

/// Instalador de Windows (el de nombre fijo, o el que lleva la versión).
ReleaseAsset? pickWindowsAsset(List<ReleaseAsset> assets, String version) =>
    assets.where((a) => a.name == windowsSetupName).firstOrNull ??
    assets.where((a) => a.name == 'Kiji_Player_${version}_Windows_Setup.exe').firstOrNull;

bool isSha256(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

/// Lee un SHA256SUMS.txt (formato de `sha256sum`: `suma  archivo` o `suma *archivo`).
Map<String, String> parseSha256Sums(String text) {
  final sums = <String, String>{};
  for (final line in text.split('\n')) {
    final match = RegExp(r'^\s*([0-9a-fA-F]{64})\s+\*?(.+?)\s*$').firstMatch(line);
    if (match != null) sums[match.group(2)!] = match.group(1)!.toLowerCase();
  }
  return sums;
}

/// La suma que tiene que dar [asset]: la de SHA256SUMS.txt; si la versión no lo trae, la que
/// publica GitHub. Si las dos están y no coinciden, no hay suma confiable (null).
String? expectedSha256(ReleaseAsset asset, Map<String, String> sums) {
  final listed = sums[asset.name];
  final digest = asset.digest;
  if (listed != null && digest != null && listed != digest) return null;
  return listed ?? digest;
}

/// SHA-256 de un archivo, leyéndolo por partes.
Future<String> sha256OfFile(File file) async => (await sha256.bind(file.openRead()).first).toString();

/// ¿El archivo es el publicado? Si no hay suma para comparar, tampoco: nunca se instala sin verificar.
Future<bool> verifySha256(File file, String? expected) async {
  if (expected == null || !isSha256(expected)) return false;
  return await sha256OfFile(file) == expected;
}
