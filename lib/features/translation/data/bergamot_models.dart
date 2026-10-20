// Modelos de traducción de Firefox Translations (proyecto Bergamot, MPL-2.0), tal como los
// publica Mozilla en su servicio Remote Settings: colecciones `translations-models` (modelos
// por par de idiomas) y `translations-wasm` (el motor). Referencia: Firefox,
// toolkit/components/translations/ (TranslationsParent y translations-engine.worker.js).

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _settings = 'https://firefox.settings.services.mozilla.com/v1/buckets/main/collections';
const _attachments = 'https://firefox-settings-attachments.cdn.mozilla.net/';

/// Versión del motor que corresponde al pegamento JS incluido en la app
/// (`assets/translation/bergamot-translator.js`, de Firefox).
const bergamotEngineVersion = '3.0';

/// Un archivo para bajar (modelo, léxico, vocabulario o el motor).
class ModelFile {
  const ModelFile({
    required this.fileType,
    required this.url,
    required this.size,
    required this.sha256,
    required this.name,
  });

  /// model, lex, vocab, srcvocab, trgvocab o engine.
  final String fileType;
  final String url;
  final int size;
  final String sha256;
  final String name;

  Map<String, dynamic> toJson() => {'fileType': fileType, 'url': url, 'size': size, 'sha256': sha256, 'name': name};

  factory ModelFile.fromJson(Map json) => ModelFile(
    fileType: '${json['fileType']}',
    url: '${json['url']}',
    size: (json['size'] as num).toInt(),
    sha256: '${json['sha256']}',
    name: '${json['name']}',
  );
}

/// Un par de idiomas (por ejemplo, en→es).
typedef LanguagePair = ({String from, String to});

String pairKey(LanguagePair pair) => '${pair.from}-${pair.to}';

/// Si un registro sirve para esta plataforma. Mozilla marca algunos modelos
/// solo para Android (más chicos) o solo para escritorio; los de canales de
/// prueba (nightly, beta) no se usan.
@visibleForTesting
bool recordFitsPlatform(String? expression, {required bool android}) {
  final e = (expression ?? '').trim();
  if (e.isEmpty) return true;
  if (e.contains('nightly') || e.contains('beta')) return false;
  if (e.contains("env.appinfo.OS == 'Android'")) return android; // l10n-ignore
  if (e.contains("env.appinfo.OS != 'Android'")) return !android; // l10n-ignore
  return false;
}

int _compareVersions(String a, String b) {
  List<int> parts(String v) => [for (final x in v.split(RegExp(r'[^0-9]+')).where((x) => x.isNotEmpty)) int.parse(x)];
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return a.length.compareTo(b.length); // "2.0" antes que "2.0a1"
}

/// Archivos del par [from]→[to] en su versión más nueva para esta plataforma,
/// o null si Mozilla no tiene ese par.
@visibleForTesting
List<ModelFile>? pickModelFiles(List<Map> records, String from, String to, {required bool android}) {
  final byVersion = <String, List<Map>>{};
  for (final r in records) {
    if (r['fromLang'] != from || r['toLang'] != to) continue;
    if (!recordFitsPlatform(r['filter_expression'] as String?, android: android)) continue;
    byVersion.putIfAbsent('${r['version']}', () => []).add(r);
  }
  final versions = byVersion.keys.toList()..sort((a, b) => _compareVersions(b, a));
  for (final version in versions) {
    final files = byVersion[version]!;
    final types = {for (final f in files) '${f['fileType']}'};
    final complete =
        types.contains('model') &&
        (types.contains('vocab') || (types.contains('srcvocab') && types.contains('trgvocab')));
    if (!complete) continue;
    return [
      for (final f in files)
        if (f['attachment'] is Map)
          ModelFile(
            fileType: '${f['fileType']}',
            url: '$_attachments${(f['attachment'] as Map)['location']}',
            size: ((f['attachment'] as Map)['size'] as num).toInt(),
            sha256: '${(f['attachment'] as Map)['hash']}',
            name: '${f['name']}',
          ),
    ];
  }
  return null;
}

/// Catálogo, descargas y archivos instalados.
class BergamotModels {
  BergamotModels({Dio? dio, Future<Directory> Function()? directory, bool? android})
    : _dio = dio ?? Dio(BaseOptions(receiveTimeout: const Duration(minutes: 5))),
      _directory = directory ?? getApplicationSupportDirectory,
      _android = android ?? (!kIsWeb && Platform.isAndroid);

  final Dio _dio;
  final Future<Directory> Function() _directory;
  final bool _android;
  List<Map>? _records;
  List<Map>? _engines;

  Future<Directory> folder() async => Directory(p.join((await _directory()).path, 'translation'));

  Future<List<Map>> _collection(String name) async {
    final cache = File(p.join((await folder()).path, '$name.json'));
    try {
      if (await cache.exists() && DateTime.now().difference(await cache.lastModified()) < const Duration(days: 7)) {
        return [for (final r in jsonDecode(await cache.readAsString()) as List) r as Map];
      }
    } catch (error) {
      debugPrint('=== TRADUCIR: catálogo guardado dañado: $error ===');
    }
    final response = await _dio.get<Map<String, dynamic>>('$_settings/$name/records');
    final data = [for (final r in (response.data?['data'] as List? ?? const [])) r as Map];
    try {
      await cache.parent.create(recursive: true);
      await cache.writeAsString(jsonEncode(data));
    } catch (error) {
      debugPrint('=== TRADUCIR: no se pudo guardar el catálogo: $error ===');
    }
    return data;
  }

  /// Los pares de modelos que hacen falta para [from]→[to]: directo si
  /// existe; si no, pasando por inglés (como Firefox). null = no se puede.
  Future<List<LanguagePair>?> route(String from, String to) async {
    if (from == to) return const [];
    final records = _records ??= await _collection('translations-models');
    if (pickModelFiles(records, from, to, android: _android) != null) return [(from: from, to: to)];
    if (from != 'en' &&
        to != 'en' &&
        pickModelFiles(records, from, 'en', android: _android) != null &&
        pickModelFiles(records, 'en', to, android: _android) != null) {
      return [(from: from, to: 'en'), (from: 'en', to: to)];
    }
    return null;
  }

  Future<List<ModelFile>> filesFor(LanguagePair pair) async {
    final records = _records ??= await _collection('translations-models');
    final files = pickModelFiles(records, pair.from, pair.to, android: _android);
    if (files == null) throw StateError('No hay modelo ${pairKey(pair)}');
    return files;
  }

  Future<ModelFile> engineFile() async {
    final records = _engines ??= await _collection('translations-wasm');
    final r = records.firstWhere(
      (r) => r['name'] == 'bergamot-translator' && r['version'] == bergamotEngineVersion,
      orElse: () => throw StateError('Mozilla ya no publica el motor $bergamotEngineVersion'),
    );
    final a = r['attachment'] as Map;
    return ModelFile(
      fileType: 'engine',
      url: '$_attachments${a['location']}',
      size: (a['size'] as num).toInt(),
      sha256: '${a['hash']}',
      name: 'bergamot-translator.wasm',
    );
  }

  Future<File> _target(String folderName, ModelFile file) async => File(
    p.join((await folder()).path, folderName, file.fileType == 'engine' ? 'engine.wasm' : '${file.fileType}.bin'),
  );

  Future<bool> isInstalled(String folderName, List<ModelFile> files) async {
    for (final f in files) {
      final target = await _target(folderName, f);
      if (!await target.exists() || await target.length() != f.size) return false;
    }
    return true;
  }

  /// Bytes que faltan bajar para traducir [from]→[to] (motor incluido).
  Future<int> missingBytes(List<LanguagePair> route) async {
    var total = 0;
    final engine = await engineFile();
    if (!await isInstalled('engine', [engine])) total += engine.size;
    for (final pair in route) {
      final files = await filesFor(pair);
      if (!await isInstalled(pairKey(pair), files)) total += files.fold(0, (a, f) => a + f.size);
    }
    return total;
  }

  /// Baja lo que falte (verificando cada archivo). [onProgress] recibe bytes
  /// bajados y total.
  Future<void> install(List<LanguagePair> route, {void Function(int done, int total)? onProgress}) async {
    final jobs = <(String, ModelFile)>[];
    final engine = await engineFile();
    if (!await isInstalled('engine', [engine])) jobs.add(('engine', engine));
    for (final pair in route) {
      final files = await filesFor(pair);
      if (await isInstalled(pairKey(pair), files)) continue;
      for (final f in files) {
        jobs.add((pairKey(pair), f));
      }
    }
    final total = jobs.fold(0, (a, j) => a + j.$2.size);
    var done = 0;
    for (final (folderName, file) in jobs) {
      final target = await _target(folderName, file);
      await target.parent.create(recursive: true);
      final part = File('${target.path}.part');
      final before = done;
      await _dio.download(
        file.url,
        part.path,
        onReceiveProgress: (received, _) => onProgress?.call(before + received, total),
      );
      final hash = (await sha256.bind(part.openRead()).first).toString();
      if (hash != file.sha256) {
        await part.delete();
        throw StateError('El archivo ${file.name} llegó dañado (no coincide su huella).');
      }
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      done += file.size;
      onProgress?.call(done, total);
    }
    // Para saber qué archivos usar sin internet.
    for (final pair in route) {
      final files = await filesFor(pair);
      await File(p.join((await folder()).path, pairKey(pair), 'files.json'))
          .writeAsString(jsonEncode([for (final f in files) f.toJson()]));
    }
    debugPrint('=== TRADUCIR: modelos listos (${(total / 1048576).toStringAsFixed(1)} MB bajados) ===');
  }

  /// Pares instalados y cuánto ocupa cada uno.
  Future<Map<String, int>> installed() async {
    final dir = await folder();
    final result = <String, int>{};
    if (!await dir.exists()) return result;
    await for (final entity in dir.list()) {
      if (entity is! Directory || p.basename(entity.path) == 'engine') continue;
      var size = 0;
      await for (final f in entity.list()) {
        if (f is File && f.path.endsWith('.bin')) size += await f.length();
      }
      if (size > 0) result[p.basename(entity.path)] = size;
    }
    return result;
  }

  /// Tipos de archivo del par instalado (para cargarlos sin internet).
  Future<List<String>> installedTypes(LanguagePair pair) async {
    final dir = Directory(p.join((await folder()).path, pairKey(pair)));
    if (!await dir.exists()) return const [];
    return [
      await for (final f in dir.list())
        if (f is File && f.path.endsWith('.bin')) p.basenameWithoutExtension(f.path),
    ];
  }

  Future<void> delete(String key) async {
    final dir = Directory(p.join((await folder()).path, key));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
