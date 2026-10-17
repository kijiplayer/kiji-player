// Adaptado de Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos originales: app/.../utils/cipher/PlayerJsFetcher.kt (ubicar y bajar el
// reproductor), PlayerConfigStore.kt y assets/player_configs.json (tabla por hash).

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// El reproductor de YouTube (`base.js`) que hace falta para descifrar.
class PlayerScript {
  PlayerScript({required this.hash, required this.signatureTimestamp, required this.load});

  /// Identificador de la versión del reproductor (8 caracteres hex).
  final String hash;
  final int signatureTimestamp;

  /// Lee el código (2–3 MB), de la caché en disco o de YouTube.
  final Future<String> Function() load;
}

/// Hash del reproductor dentro de la respuesta de `iframe_api`.
String? playerHashFrom(String iframeApi) =>
    RegExp(r'player\\?/([0-9a-f]{8})\\?/').firstMatch(iframeApi)?.group(1);

/// `signatureTimestamp` dentro del código del reproductor.
int? signatureTimestampFrom(String playerJs) {
  final match = RegExp(r'signatureTimestamp[=:](\d{5})').firstMatch(playerJs) ??
      RegExp(r'\bsts:(\d{5})').firstMatch(playerJs);
  return match == null ? null : int.parse(match.group(1)!);
}

/// `sts` de la tabla de Echo (`player_configs.json`) para [hash], buscando
/// también entre los alias.
int? stsFromConfigTable(Map<String, dynamic> table, String hash) {
  final players = table['players'];
  if (players is! Map) return null;
  for (final entry in players.entries) {
    final config = entry.value;
    if (config is! Map) continue;
    final aliases = config['aliases'];
    if (entry.key == hash || (aliases is List && aliases.contains(hash))) {
      final sts = config['sts'];
      return sts is int ? sts : null;
    }
  }
  return null;
}

class PlayerScriptSource {
  PlayerScriptSource({
    Dio? dio,
    Future<Directory> Function()? directory,
    Future<String> Function()? configTable,
  })  : _dio = dio ?? Dio(BaseOptions(receiveTimeout: const Duration(seconds: 30))),
        _directory = directory ?? getApplicationSupportDirectory,
        _configTable = configTable ?? (() => rootBundle.loadString('assets/solver/player_configs.json'));

  final Dio _dio;
  final Future<Directory> Function() _directory;
  final Future<String> Function() _configTable;

  PlayerScript? _current;
  DateTime? _checkedAt;
  Map<String, dynamic>? _table;

  /// El reproductor vigente. Se vuelve a preguntar cuál es cada hora (o
  /// con [refresh]), porque YouTube lo cambia seguido.
  Future<PlayerScript?> current({bool refresh = false}) async {
    final checked = _checkedAt;
    if (!refresh && _current != null && checked != null &&
        DateTime.now().difference(checked) < const Duration(hours: 1)) {
      return _current;
    }
    try {
      final iframe = await _dio.get<String>('https://www.youtube.com/iframe_api',
          options: Options(responseType: ResponseType.plain));
      final hash = playerHashFrom(iframe.data ?? '');
      if (hash == null) {
        debugPrint('=== YTM reproductor: no se encontró el hash en iframe_api ===');
        return _current;
      }
      if (_current?.hash == hash) {
        _checkedAt = DateTime.now();
        return _current;
      }
      var sts = stsFromConfigTable(await _loadTable(), hash);
      String? js;
      if (sts == null) {
        js = await _script(hash);
        sts = signatureTimestampFrom(js);
      }
      if (sts == null) {
        debugPrint('=== YTM reproductor: sin signatureTimestamp para $hash ===');
        return _current;
      }
      debugPrint('=== YTM reproductor: $hash (sts $sts) ===');
      final cached = js;
      _current = PlayerScript(
        hash: hash,
        signatureTimestamp: sts,
        load: () async => cached ?? await _script(hash),
      );
      _checkedAt = DateTime.now();
      return _current;
    } catch (error) {
      debugPrint('=== YTM reproductor: no se pudo ubicar: $error ===');
      return _current;
    }
  }

  Future<Map<String, dynamic>> _loadTable() async {
    final cached = _table;
    if (cached != null) return cached;
    try {
      final decoded = jsonDecode(await _configTable());
      return _table = decoded is Map<String, dynamic> ? decoded : const {};
    } catch (error) {
      debugPrint('=== YTM reproductor: no se pudo leer player_configs.json: $error ===');
      return _table = const {};
    }
  }

  /// Código del reproductor, guardado en disco por hash (se conservan los
  /// dos últimos).
  Future<String> _script(String hash) async {
    Directory? folder;
    try {
      folder = Directory(p.join((await _directory()).path, 'player_js'));
      final file = File(p.join(folder.path, '$hash.js'));
      if (await file.exists()) return await file.readAsString();
    } catch (error) {
      debugPrint('=== YTM reproductor: sin caché en disco: $error ===');
      folder = null;
    }
    final response = await _dio.get<String>(
      'https://www.youtube.com/s/player/$hash/player_ias.vflset/en_US/base.js',
      options: Options(responseType: ResponseType.plain),
    );
    final js = response.data ?? '';
    if (js.length < 100000) throw StateError('El reproductor llegó incompleto (${js.length} caracteres)');
    if (folder != null) {
      try {
        await folder.create(recursive: true);
        await File(p.join(folder.path, '$hash.js')).writeAsString(js);
        final old = folder.listSync().whereType<File>().toList()
          ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        for (final file in old.skip(2)) {
          await file.delete();
        }
      } catch (error) {
        debugPrint('=== YTM reproductor: no se pudo guardar en disco: $error ===');
      }
    }
    return js;
  }
}
