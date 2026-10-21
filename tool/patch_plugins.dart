// Parches a plugins viejos que no compilan con el Gradle/AGP actual: `dart run tool/patch_plugins.dart`
// (después de `flutter pub get`). Se usa en la PC nueva y en GitHub Actions; si el parche ya está,
// no hace nada.
//
// on_audio_query_android 1.1.0: le falta `namespace` y pide compileSdk 33 con Java 1.8.

import 'dart:convert';
import 'dart:io';

void main() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) _fail('Falta .dart_tool/package_config.json: corre `flutter pub get` antes.');
  final packages = (jsonDecode(config.readAsStringSync())['packages'] as List).cast<Map<String, dynamic>>();
  final plugin = packages.where((p) => p['name'] == 'on_audio_query_android').firstOrNull;
  if (plugin == null) {
    stdout.writeln('on_audio_query_android no está entre las dependencias: nada que parchear.');
    return;
  }
  final root = Uri.parse(plugin['rootUri'] as String);
  final dir = Directory.fromUri(root.isAbsolute ? root : config.parent.uri.resolveUri(root));
  final gradle = File('${dir.path}${Platform.pathSeparator}android${Platform.pathSeparator}build.gradle');
  if (!gradle.existsSync()) _fail('No se encontró ${gradle.path}.');

  final text = gradle.readAsStringSync();
  if (text.contains('namespace ')) {
    stdout.writeln('on_audio_query_android ya estaba parcheado.');
    return;
  }
  const original = '    compileSdkVersion 33';
  if (!text.contains(original)) _fail('El build.gradle de on_audio_query_android cambió: revisar el parche a mano.');
  gradle.writeAsStringSync(
    text.replaceFirst(original, '''
    namespace 'com.lucasjosino.on_audio_query'

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = '11'
    }

    compileSdkVersion 36'''),
  );
  stdout.writeln('on_audio_query_android parcheado (${gradle.path}).');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
