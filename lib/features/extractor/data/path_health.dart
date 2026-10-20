import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';


/// Cómo le va a un camino (motor + forma, "B/WEB_REMIX") en las pruebas y al reproducir.
class PathRecord {
  PathRecord({this.ok = 0, this.fail = 0, this.lastOk, this.lastFail, this.lastReason, List<bool>? recent})
    : recent = recent ?? [];

  int ok;
  int fail;
  DateTime? lastOk;
  DateTime? lastFail;

  /// Motivo de la última falla de la FORMA (nunca de contenido).
  String? lastReason;

  /// Últimos resultados, el más nuevo al final (máx. [PathHealth.window]).
  final List<bool> recent;

  /// Anduvo la última vez.
  bool get working => recent.isNotEmpty && recent.last;

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'fail': fail,
    'lastOk': lastOk?.toIso8601String(),
    'lastFail': lastFail?.toIso8601String(),
    'lastReason': lastReason,
    'recent': [for (final r in recent) r ? 1 : 0],
  };

  static PathRecord fromJson(Map json) => PathRecord(
    ok: (json['ok'] as num?)?.toInt() ?? 0,
    fail: (json['fail'] as num?)?.toInt() ?? 0,
    lastOk: DateTime.tryParse('${json['lastOk']}'),
    lastFail: DateTime.tryParse('${json['lastFail']}'),
    lastReason: json['lastReason'] as String?,
    recent: [for (final r in (json['recent'] as List? ?? const [])) r == 1],
  );
}

/// Salud del Extractor 2.0: por camino, solo con fallas de la FORMA (las de la
/// canción no cuentan), con pruebas de control y con cada reproducción real. El orden de las
/// formas se ajusta solo según los éxitos recientes.
class PathHealth extends ChangeNotifier {
  PathHealth({Future<String> Function()? directory, DateTime Function()? now})
    : _directoryPath = directory,
      _now = now ?? DateTime.now;

  static final instance = PathHealth();

  static const window = 20;

  final Future<String> Function()? _directoryPath;
  final DateTime Function() _now;
  final Map<String, PathRecord> _records = {};
  JsonFile? _file;
  bool _loaded = false;

  /// Cuándo fue la última prueba automática (para "más de 12 h").
  DateTime? lastTestAt;

  Map<String, PathRecord> get all => Map.unmodifiable(_records);
  PathRecord? operator [](String path) => _records[path];

  Future<JsonFile> _jsonFile() async => _file ??= JsonFile(
    p.join(
      await (_directoryPath ?? () async => (await getApplicationSupportDirectory()).path)(),
      'extractor_health_v2.json',
    ),
    logTag: 'SALUD',
  );

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final json = await (await _jsonFile()).read();
      if (json is Map) {
        lastTestAt = DateTime.tryParse('${json['lastTestAt']}');
        final paths = json['paths'];
        if (paths is Map) {
          for (final e in paths.entries) {
            if (e.value is Map) _records['${e.key}'] = PathRecord.fromJson(e.value as Map);
          }
        }
      }
      notifyListeners();
    } catch (error) {
      debugPrint('=== SALUD: no se pudo leer: $error ===');
    }
  }

  void _save() => unawaited(
    _jsonFile().then(
      (f) => f.write({
        'lastTestAt': lastTestAt?.toIso8601String(),
        'paths': {for (final e in _records.entries) e.key: e.value.toJson()},
      }),
    ),
  );

  void _push(PathRecord r, bool value) {
    r.recent.add(value);
    if (r.recent.length > window) r.recent.removeAt(0);
  }

  void recordSuccess(String path) {
    final r = _records.putIfAbsent(path, PathRecord.new);
    r.ok++;
    r.lastOk = _now();
    _push(r, true);
    _save();
    notifyListeners();
  }

  /// Solo fallas de la FORMA. Las del contenido no se anotan nunca.
  void recordFormFailure(String path, String reason) {
    final r = _records.putIfAbsent(path, PathRecord.new);
    r.fail++;
    r.lastFail = _now();
    r.lastReason = reason;
    _push(r, false);
    _save();
    notifyListeners();
  }

  void markTested() {
    lastTestAt = _now();
    _save();
    notifyListeners();
  }

  /// Puntaje para ordenar: éxitos recientes pesan más (los últimos [window] resultados).
  double score(String path) {
    final r = _records[path];
    if (r == null || r.recent.isEmpty) return 0.5; // sin datos: en el medio
    var total = 0.0, weight = 0.0;
    for (var i = 0; i < r.recent.length; i++) {
      final w = pow(1.25, i).toDouble(); // el más nuevo vale más
      total += r.recent[i] ? w : 0;
      weight += w;
    }
    return total / weight;
  }

  /// [forms] ordenadas por puntaje para el motor [engine] ("A", "B"); empates conservan el orden.
  List<String> order(String engine, List<String> forms) {
    final indexed = [for (final (i, f) in forms.indexed) (i, f)];
    indexed.sort((x, y) {
      final c = score('$engine/${y.$2}').compareTo(score('$engine/${x.$2}'));
      return c != 0 ? c : x.$1.compareTo(y.$1);
    });
    return [for (final x in indexed) x.$2];
  }
}
