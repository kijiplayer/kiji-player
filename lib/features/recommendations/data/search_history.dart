import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';


/// Búsquedas recientes. Se guardan solo en este dispositivo
/// (`<appSupport>/search_history.json`).
class SearchHistoryNotifier extends Notifier<List<String>> {
  SearchHistoryNotifier({Future<String> Function()? directory}) : _directoryPath = directory;

  static const maxEntries = 20;

  final Future<String> Function()? _directoryPath;
  JsonFile? _file;

  Future<JsonFile> _jsonFile() async => _file ??= JsonFile(
    p.join(
      await (_directoryPath ?? () async => (await getApplicationSupportDirectory()).path)(),
      'search_history.json',
    ),
    logTag: 'BUSQUEDAS',
  );

  @override
  List<String> build() {
    unawaited(Future.microtask(_load));
    return const [];
  }

  Future<void> _load() async {
    try {
      final json = await (await _jsonFile()).read();
      if (json is List) {
        final saved = [
          for (final q in json)
            if (q is String && q.trim().isNotEmpty) q,
        ];
        // Lo buscado mientras se leía el archivo queda arriba (leer no pisa lo más nuevo).
        final current = state;
        state = [
          ...current,
          ...saved.where((q) => !current.any((c) => c.toLowerCase() == q.toLowerCase())),
        ].take(maxEntries).toList();
      }
    } catch (error) {
      debugPrint('=== BUSQUEDAS: no se pudieron leer: $error ===');
    }
  }

  /// Guarda [query] arriba de todo (sin repetir, sin distinguir mayúsculas).
  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    state = [q, ...state.where((s) => s.toLowerCase() != q.toLowerCase())].take(maxEntries).toList();
    unawaited(_save());
  }

  void remove(String query) {
    state = [
      for (final s in state)
        if (s != query) s,
    ];
    unawaited(_save());
  }

  void clear() {
    state = const [];
    unawaited(_save());
  }

  Future<void>? _saving;
  bool _saveAgain = false;

  /// Guarda la lista. Si ya se está guardando (varias búsquedas seguidas), se junta: al terminar
  /// se guarda una vez más, lo último.
  Future<void> _save() {
    final running = _saving;
    if (running != null) {
      _saveAgain = true;
      return running;
    }
    return _saving = _saveLoop().whenComplete(() => _saving = null);
  }

  Future<void> _saveLoop() async {
    try {
      do {
        _saveAgain = false;
        await (await _jsonFile()).write(state);
      } while (_saveAgain);
    } catch (error) {
      debugPrint('=== BUSQUEDAS: no se pudieron guardar: $error ===');
    }
  }

  /// Espera a que lo último quede guardado (para las pruebas).
  @visibleForTesting
  Future<void> flush() => _saving ?? Future.value();
}

final searchHistoryProvider = NotifierProvider<SearchHistoryNotifier, List<String>>(SearchHistoryNotifier.new);
