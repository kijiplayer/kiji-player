import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../dev_tools/dev_build.dart';

/// La bienvenida está, por ahora, solo en Kiji Dev. Para Kiji basta con cambiar esta línea.
const welcomeEnabled = isDevBuild;

/// Archivos que dicen "esta persona ya usó Kiji": si hay alguno, la bienvenida no aparece sola.
const _userDataFiles = [
  'settings.json',
  'history.json',
  'favorites.json',
  'playlists.json',
  'playback_state.json',
  'moments.json',
  'imports.json',
  'track_overrides.json',
  'equalizer.json',
  'library_folders.json',
  'downloads/index.json',
];

const _seenFile = 'welcome.json';

/// Decide si la bienvenida se muestra sola: una única vez y solo a quien recién instala Kiji.
class WelcomeStore {
  WelcomeStore({Future<Directory> Function()? directory}) : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  /// true si hay que mostrarla al abrir: nunca se vio y no hay datos de antes.
  Future<bool> shouldShow() async {
    try {
      final dir = (await _directory()).path;
      if (await File(p.join(dir, _seenFile)).exists()) return false;
      for (final name in _userDataFiles) {
        if (await File(p.join(dir, name)).exists()) return false;
      }
      return true;
    } catch (error) {
      debugPrint('=== BIENVENIDA: no se pudo revisar (no se muestra): $error ===');
      return false;
    }
  }

  /// Ya se vio (con "Empezar" o "Saltar"): no vuelve a aparecer sola.
  Future<void> markSeen() async {
    try {
      final file = File(p.join((await _directory()).path, _seenFile));
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'seen': true, 'at': DateTime.now().toIso8601String()}));
    } catch (error) {
      debugPrint('=== BIENVENIDA: no se pudo guardar que ya se vio: $error ===');
    }
  }
}
