// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
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

/// `player_configs.json` remoto de ZemerTeam/zemer-cipher (el que usan Echo y Metrolist), con
/// caché de 6 h y ETag. YouTube rota su reproductor cada pocos días y la tabla de la
/// app queda vieja; si aparece un reproductor desconocido se fuerza otra consulta (como mucho cada
/// 10 min). GitHub ve esa consulta (lo explica Configuración → Privacidad). Si no hay red, se usa
/// la tabla incluida en la app.
class RemotePlayerConfigs {
  RemotePlayerConfigs({Dio? dio, Future<Directory> Function()? directory, DateTime Function()? now})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20))),
        _directory = directory ?? getApplicationSupportDirectory,
        _now = now ?? DateTime.now;

  static const url =
      'https://raw.githubusercontent.com/ZemerTeam/zemer-cipher/master/library/src/main/assets/player_configs.json';
  static const ttl = Duration(hours: 6);
  static const forcedCooldown = Duration(minutes: 10);

  final Dio _dio;
  final Future<Directory> Function() _directory;
  final DateTime Function() _now;
  DateTime? _lastForced;

  Future<File> _file(String name) async => File(p.join((await _directory()).path, name));

  /// La tabla remota (de la caché si tiene menos de 6 h, salvo [force]); null si no hay.
  Future<String?> load({bool force = false}) async {
    final body = await _file('player_configs_remote.json');
    final meta = await _file('player_configs_remote.meta');
    String? etag;
    DateTime? fetchedAt;
    try {
      if (await meta.exists()) {
        final m = jsonDecode(await meta.readAsString()) as Map;
        etag = m['etag'] as String?;
        fetchedAt = DateTime.tryParse('${m['at']}');
      }
    } catch (error) {
      debugPrint('=== YTM config remota: meta dañada: $error ===');
    }
    final cached = await body.exists() ? await body.readAsString() : null;
    final fresh = fetchedAt != null && _now().difference(fetchedAt) < ttl;
    if (cached != null && fresh && !force) return cached;
    if (force) {
      final last = _lastForced;
      if (last != null && _now().difference(last) < forcedCooldown) return cached;
      _lastForced = _now();
    }
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {if (etag != null && cached != null) 'If-None-Match': etag},
          validateStatus: (s) => s == 200 || s == 304,
        ),
      );
      if (response.statusCode == 304 && cached != null) {
        await meta.writeAsString(jsonEncode({'etag': etag, 'at': _now().toIso8601String()}));
        return cached;
      }
      final text = response.data ?? '';
      if (jsonDecode(text) is! Map) return cached;
      await body.parent.create(recursive: true);
      await body.writeAsString(text);
      await meta.writeAsString(jsonEncode({'etag': response.headers.value('etag'), 'at': _now().toIso8601String()}));
      debugPrint('=== YTM config remota: actualizada ===');
      return text;
    } catch (error) {
      debugPrint('=== YTM config remota: sin conexión o error (${error.runtimeType}); se usa la guardada ===');
      return cached;
    }
  }
}

class PlayerScriptSource {
  PlayerScriptSource({
    Dio? dio,
    Future<Directory> Function()? directory,
    Future<String> Function()? configTable,
    RemotePlayerConfigs? remote,
  })  : _dio = dio ?? Dio(BaseOptions(receiveTimeout: const Duration(seconds: 30))),
        _directory = directory ?? getApplicationSupportDirectory,
        _configTable = configTable ?? (() => rootBundle.loadString('assets/solver/player_configs.json')),
        // Con una tabla inyectada (tests) no se consulta la remota.
        _remote = configTable != null ? null : (remote ?? RemotePlayerConfigs(directory: directory));

  final Dio _dio;
  final Future<Directory> Function() _directory;
  final Future<String> Function() _configTable;
  final RemotePlayerConfigs? _remote;

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
      if (sts == null && _remote != null) {
        // Reproductor desconocido: la tabla remota puede estar vieja; se pide de nuevo.
        final forced = await _remote.load(force: true);
        if (forced != null) {
          _table = null;
          sts = stsFromConfigTable(await _loadTable(remoteText: forced), hash);
        }
      }
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

  Future<Map<String, dynamic>> _loadTable({String? remoteText}) async {
    final cached = _table;
    if (cached != null) return cached;
    try {
      // La remota primero (más nueva); la de la app, de respaldo. Se unen: la remota manda.
      final bundled = jsonDecode(await _configTable());
      final remote = remoteText ?? await _remote?.load();
      final decodedRemote = remote == null ? null : jsonDecode(remote);
      final merged = <String, dynamic>{
        if (bundled is Map<String, dynamic>) ...bundled,
        if (decodedRemote is Map<String, dynamic>) ...decodedRemote,
      };
      return _table = merged;
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
