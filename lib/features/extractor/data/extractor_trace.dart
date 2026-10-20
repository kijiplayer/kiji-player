import 'package:flutter/foundation.dart';

/// Una búsqueda de audio: qué canción, cuánto tardó, qué camino ganó y qué falló antes.
class TraceEntry {
  const TraceEntry({
    required this.at,
    required this.videoId,
    required this.elapsed,
    required this.result,
    this.failures = const [],
    this.ok = false,
  });

  final DateTime at;
  final String videoId;
  final Duration elapsed;

  /// "A/WEB_REMIX, 140 kbps", "contenido: ageRestricted" o "falló".
  final String result;
  final bool ok;

  /// (camino, motivo) de cada forma que falló antes.
  final List<(String, String)> failures;
}

/// Las últimas búsquedas de audio, en memoria (herramientas de Kiji Dev).
class ExtractorTrace extends ChangeNotifier {
  ExtractorTrace._();

  static final instance = ExtractorTrace._();
  static const capacity = 40;

  final List<TraceEntry> _entries = [];

  /// De la más nueva a la más vieja.
  List<TraceEntry> get entries => List.unmodifiable(_entries.reversed);

  void add(TraceEntry entry) {
    _entries.add(entry);
    if (_entries.length > capacity) _entries.removeAt(0);
    notifyListeners();
  }

  @visibleForTesting
  void clear() => _entries.clear();
}
