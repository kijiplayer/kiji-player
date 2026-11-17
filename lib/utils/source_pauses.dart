import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'json_file.dart';

/// Pausas de los servicios de afuera que fallan (fuentes de letras, Gemini), guardadas en el
/// dispositivo (`source_pauses.json`), así no se vuelven a intentar a cada rato ni cada vez que se
/// abre Kiji. Si siguen fallando, la pausa crece (30 min, 1 h, 2 h… hasta 24 h); una respuesta buena
/// la borra. No guarda nada de la persona: solo el nombre del servicio y hasta cuándo.
class SourcePauses {
  SourcePauses({required this._directory, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;
  final _until = <String, DateTime>{};
  final _strikes = <String, int>{};
  Future<void>? _loading;
  JsonFile? _file;

  static const base = Duration(minutes: 30);
  static const max = Duration(hours: 24);

  Future<JsonFile> _json() async =>
      _file ??= JsonFile(p.join((await _directory()).path, 'source_pauses.json'), logTag: 'PAUSAS');

  /// Lee lo guardado (una vez).
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final json = await (await _json()).read();
      if (json is! Map) return;
      for (final MapEntry(:key, :value) in json.entries) {
        if (value is! Map) continue;
        final until = DateTime.tryParse('${value['until']}');
        if (until != null) _until['$key'] = until;
        final strikes = value['strikes'];
        if (strikes is int) _strikes['$key'] = strikes;
      }
    } catch (error) {
      debugPrint('=== PAUSAS: no se pudieron leer (${error.runtimeType}); se empieza de cero ===');
    }
  }

  Future<void> _save() async {
    try {
      await (await _json()).write({
        for (final key in {..._until.keys, ..._strikes.keys})
          key: {if (_until[key] case final until?) 'until': until.toIso8601String(), 'strikes': _strikes[key] ?? 0},
      });
    } catch (error) {
      debugPrint('=== PAUSAS: no se pudieron guardar (${error.runtimeType}) ===');
    }
  }

  /// ¿Está en pausa [id] ahora? (Llamar antes a [ensureLoaded].)
  bool paused(String id) {
    final until = _until[id];
    return until != null && _clock().isBefore(until);
  }

  /// [id] rechazó o está caído: se pausa, cada vez más largo. Devuelve cuánto.
  Future<Duration> refuse(String id, {Duration? first}) async {
    await ensureLoaded();
    final strikes = (_strikes[id] ?? 0) + 1;
    _strikes[id] = strikes;
    final start = first ?? base;
    final minutes = math.min(start.inMinutes * math.pow(2, strikes - 1), max.inMinutes).round();
    final pause = Duration(minutes: minutes);
    _until[id] = _clock().add(pause);
    await _save();
    return pause;
  }

  /// [id] respondió bien: fuera la pausa y la cuenta.
  Future<void> success(String id) async {
    await ensureLoaded();
    if (_until.remove(id) == null && _strikes.remove(id) == null) return;
    _strikes.remove(id);
    await _save();
  }
}
