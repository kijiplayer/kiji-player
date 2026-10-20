// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../constants/PreferenceKeys.kt (un único lugar
// para las preferencias, con valores por defecto).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';
import '../domain/app_settings.dart';


/// Preferencias guardadas en `<appSupportDir>/settings.json`.
class SettingsNotifier extends Notifier<AppSettings> {
  SettingsNotifier({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  JsonFile? _file;
  final Completer<AppSettings> _loaded = Completer();

  /// Se completa cuando ya se leyó el archivo. El reproductor lo espera
  /// antes de restaurar la cola (por "Recordar la cola al cerrar").
  Future<AppSettings> get loaded => _loaded.future;

  Future<JsonFile> _jsonFile() async =>
      _file ??= JsonFile(p.join((await _directory()).path, 'settings.json'), logTag: 'AJUSTES');

  @override
  AppSettings build() {
    unawaited(Future.microtask(_load));
    return const AppSettings();
  }

  Future<void> _load() async {
    try {
      final json = await (await _jsonFile()).read();
      if (json is Map<String, dynamic>) state = AppSettings.fromJson(json);
    } catch (error) {
      debugPrint('=== AJUSTES: no se pudieron leer (se usan los de fábrica): $error ===');
    } finally {
      if (!_loaded.isCompleted) _loaded.complete(state);
    }
  }

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    try {
      await (await _jsonFile()).write(state.toJson());
    } catch (error) {
      debugPrint('=== AJUSTES: no se pudieron guardar: $error ===');
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
