import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';
import 'yt_clients.dart';

/// Cómo le fue a un "cliente" de YouTube (VISIONOS, ANDROID_VR, WEB_REMIX)
/// la última vez que se usó.
class ClientHealth {
  const ClientHealth({this.lastSuccess, this.lastFailure, this.lastFailureReason});

  final DateTime? lastSuccess;
  final DateTime? lastFailure;

  /// Motivo en palabras simples ("YouTube lo rechazó", "sin conexión").
  final String? lastFailureReason;

  bool get neverUsed => lastSuccess == null && lastFailure == null;

  /// Funciona si su último resultado fue un éxito.
  bool get working =>
      lastSuccess != null && (lastFailure == null || lastSuccess!.isAfter(lastFailure!));

  Map<String, dynamic> toJson() => {
        if (lastSuccess != null) 'lastSuccess': lastSuccess!.millisecondsSinceEpoch,
        if (lastFailure != null) 'lastFailure': lastFailure!.millisecondsSinceEpoch,
        if (lastFailureReason != null) 'lastFailureReason': lastFailureReason,
      };

  factory ClientHealth.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json[key] as int);
    return ClientHealth(
      lastSuccess: date('lastSuccess'),
      lastFailure: date('lastFailure'),
      lastFailureReason: json['lastFailureReason'] as String?,
    );
  }
}

/// Registro de "Salud del Extractor": qué cliente de YouTube está
/// funcionando hoy. Se guarda en el dispositivo y no sale de él.
class ExtractorHealth extends ChangeNotifier {
  ExtractorHealth._();

  static final instance = ExtractorHealth._();

  /// Orden en que se prueban las formas (Tarea Z1).
  static final clients = [for (final client in ytPlayerClients) client.label];

  final Map<String, ClientHealth> _health = {};
  JsonFile? _file;
  bool _loaded = false;

  Map<String, ClientHealth> get all => {for (final c in clients) c: _health[c] ?? const ClientHealth()};

  Future<JsonFile> _jsonFile() async => _file ??= JsonFile(
        p.join((await getApplicationSupportDirectory()).path, 'extractor_health.json'),
        logTag: 'EXTRACTOR',
      );

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final json = await (await _jsonFile()).read();
      if (json is Map<String, dynamic>) {
        for (final entry in json.entries) {
          _health[entry.key] = ClientHealth.fromJson(entry.value as Map<String, dynamic>);
        }
        notifyListeners();
      }
    } catch (error) {
      debugPrint('=== EXTRACTOR: no se pudo leer el registro: $error ===');
    }
  }

  void recordSuccess(String client) {
    final previous = _health[client] ?? const ClientHealth();
    _health[client] = ClientHealth(
      lastSuccess: DateTime.now(),
      lastFailure: previous.lastFailure,
      lastFailureReason: previous.lastFailureReason,
    );
    _changed();
  }

  void recordFailure(String client, String reason) {
    final previous = _health[client] ?? const ClientHealth();
    _health[client] = ClientHealth(
      lastSuccess: previous.lastSuccess,
      lastFailure: DateTime.now(),
      lastFailureReason: reason,
    );
    _changed();
  }

  void _changed() {
    notifyListeners();
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await (await _jsonFile()).write({
        for (final entry in _health.entries) entry.key: entry.value.toJson(),
      });
    } catch (error) {
      // En los tests no hay path_provider: el registro queda solo en memoria.
      debugPrint('=== EXTRACTOR: no se pudo guardar el registro: $error ===');
    }
  }

  @visibleForTesting
  void resetForTest() {
    _health.clear();
    _loaded = true;
  }
}
