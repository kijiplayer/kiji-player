// Manifiesto de Android: lo que no se puede perder sin romper algo en algún teléfono.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 10 puede abrir la música local por su ruta (requestLegacyExternalStorage)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final application = RegExp(r'<application[^>]*>', dotAll: true).firstMatch(manifest)!.group(0)!;
    expect(application, contains('android:requestLegacyExternalStorage="true"'));
  });
}
