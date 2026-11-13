import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';
import '../../customize/data/track_overrides.dart';

/// Archivo de las portadas elegidas para álbumes y carpetas (entra en la copia de seguridad).
const groupCoversFile = 'group_covers.json';

/// Portadas que eligió el usuario para un álbum o una carpeta de la música del equipo ("Elegir
/// portada", con el selector de fotos del sistema: sin pedir permisos). Clave del grupo
/// (`album:…` o `folder:…`) → nombre del archivo en `covers/`. La foto se guarda una sola vez.
class GroupCoversNotifier extends Notifier<Map<String, String>> {
  GroupCoversNotifier({Future<Directory> Function()? directory}) : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  JsonFile? _file;

  Future<JsonFile> _json() async => _file ??= JsonFile(p.join((await _directory()).path, groupCoversFile), logTag: 'PORTADAS');

  @override
  Map<String, String> build() {
    unawaited(_load());
    return const {};
  }

  Future<void> _load() async {
    try {
      final json = await (await _json()).read();
      if (json is Map) {
        state = {
          for (final e in json.entries)
            // Solo un nombre de archivo (nunca una ruta).
            if (e.key is String && e.value is String && !(e.value as String).contains(RegExp(r'[\\/]')))
              e.key as String: e.value as String,
          ...state,
        };
      }
    } catch (error) {
      debugPrint('=== PORTADAS: no se pudieron leer las de los grupos: ${error.runtimeType} ===');
    }
  }

  Future<void> _save() async {
    try {
      await (await _json()).write(state);
    } catch (error) {
      debugPrint('=== PORTADAS: no se pudieron guardar las de los grupos: ${error.runtimeType} ===');
    }
  }

  /// Guarda [bytes] como portada del grupo [key] (reemplaza la anterior).
  Future<void> set(String key, Uint8List bytes) async {
    final covers = ref.read(trackOverridesProvider.notifier).covers;
    final name = await covers.save('group-${key.hashCode.toUnsigned(32).toRadixString(16)}', bytes);
    final old = state[key];
    state = {...state, key: name};
    await _save();
    await covers.delete(old);
    debugPrint('=== PORTADAS: portada elegida para un ${key.split(':').first} ===');
  }

  /// "Quitar la portada elegida": vuelve la del archivo, la de la carpeta o la generada.
  Future<void> clear(String key) async {
    final old = state[key];
    if (old == null) return;
    state = {...state}..remove(key);
    await _save();
    await ref.read(trackOverridesProvider.notifier).covers.delete(old);
  }
}

final groupCoversProvider = NotifierProvider<GroupCoversNotifier, Map<String, String>>(GroupCoversNotifier.new);
