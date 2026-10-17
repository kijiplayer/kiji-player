import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';

/// Búsquedas recientes (Tarea Z5). Se guardan solo en este dispositivo
/// (`<appSupport>/search_history.json`).
class SearchHistoryNotifier extends Notifier<List<String>> {
  SearchHistoryNotifier({Future<String> Function()? directory}) : _directoryPath = directory;

  static const maxEntries = 20;

  final Future<String> Function()? _directoryPath;
  JsonFile? _file;

  Future<JsonFile> _jsonFile() async => _file ??= JsonFile(
        p.join(await (_directoryPath ?? () async => (await getApplicationSupportDirectory()).path)(), 'search_history.json'),
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
      if (json is List) state = [for (final q in json) if (q is String && q.trim().isNotEmpty) q];
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
    state = [for (final s in state) if (s != query) s];
    unawaited(_save());
  }

  void clear() {
    state = const [];
    unawaited(_save());
  }

  Future<void> _save() async => (await _jsonFile()).write(state);
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(SearchHistoryNotifier.new);
