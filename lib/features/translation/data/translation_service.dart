import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/secret_store.dart';
import '../domain/languages.dart';
import 'bergamot_engine.dart';
import 'bergamot_models.dart';
import 'gemini_client.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Nombre del secreto con la clave de Gemini.
const geminiKeySecret = 'gemini_api_key';

/// Lo que hace falta para traducir en el teléfono.
class LocalPlan {
  const LocalPlan({required this.source, required this.route, required this.missingBytes});
  final String source;
  final List<LanguagePair> route;
  final int missingBytes;
}

class TranslationException implements Exception {
  const TranslationException(this.message, {this.suggestLocal = false});
  final String message;

  /// Ofrecer la traducción en el teléfono (por ejemplo, si Gemini falló).
  final bool suggestLocal;
  @override
  String toString() => message;
}

/// Traducción de letras (Tarea Z4): en el teléfono (Bergamot) o con Gemini.
/// Cada traducción se guarda en caché para no repetirla.
class TranslationService {
  TranslationService({
    BergamotModels? models,
    BergamotEngine? engine,
    GeminiClient? gemini,
    SecretStore? secrets,
    Future<Directory> Function()? directory,
  }) : models = models ?? BergamotModels(),
       gemini = gemini ?? GeminiClient(),
       secrets = secrets ?? createSecretStore(),
       _directory = directory ?? getApplicationSupportDirectory {
    this.engine = engine ?? BergamotEngine(this.models);
  }

  final BergamotModels models;
  late final BergamotEngine engine;
  final GeminiClient gemini;
  final SecretStore secrets;
  final Future<Directory> Function() _directory;

  Future<File> _cacheFile(String trackId, String engineName, String target) async {
    final safe = trackId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File(p.join((await _directory()).path, 'lyrics', '$safe.tr.$engineName.$target.json'));
  }

  static String _hash(List<String> lines) => sha256.convert(utf8.encode(lines.join('\n'))).toString();

  /// Traducción guardada, si la letra no cambió.
  Future<List<String?>?> cached(String trackId, List<String> lines, String engineName, String target) async {
    try {
      final file = await _cacheFile(trackId, engineName, target);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map;
      if (json['hash'] != _hash(lines)) return null;
      return [for (final l in json['lines'] as List) l as String?];
    } catch (error) {
      debugPrint('=== TRADUCIR: caché dañada: $error ===');
      return null;
    }
  }

  Future<void> _save(String trackId, List<String> lines, String engineName, String target, List<String?> out) async {
    try {
      final file = await _cacheFile(trackId, engineName, target);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'hash': _hash(lines), 'lines': out}));
    } catch (error) {
      debugPrint('=== TRADUCIR: no se pudo guardar la traducción: $error ===');
    }
  }

  /// Qué hace falta para traducir [lines] en el teléfono. [source] = idioma
  /// de la letra (si es null, se detecta).
  Future<LocalPlan> planLocal(List<String> lines, String target, {String? source}) async {
    final from = source ?? detectLanguage(lines);
    if (from == null) throw TranslationException(tx.noSePudoSaberEnQue);
    if (from == target) {
      throw TranslationException(tx.laLetraYaEstaEn(languageName(target).toLowerCase()));
    }
    final List<LanguagePair>? route;
    try {
      route = await models.route(from, target);
    } catch (error) {
      throw TranslationException(tx.noSePudoConsultarLaLista);
    }
    if (route == null) {
      throw TranslationException(
        tx.todaviaNoHayTraduccionDeA(languageName(from).toLowerCase(), languageName(target).toLowerCase()),
      );
    }
    return LocalPlan(source: from, route: route, missingBytes: await models.missingBytes(route));
  }

  /// Traduce en el teléfono (los modelos ya tienen que estar bajados).
  Future<List<String?>> translateLocal(String trackId, List<String> lines, LocalPlan plan, String target) async {
    final hit = await cached(trackId, lines, 'local', target);
    if (hit != null) return hit;
    final out = await _byLines(lines, (texts) => engine.translate(plan.route, texts));
    await _save(trackId, lines, 'local', target, out);
    return out;
  }

  /// Traduce con Gemini, con la clave guardada en el dispositivo.
  Future<List<String?>> translateGemini(String trackId, List<String> lines, String model, String target) async {
    final hit = await cached(trackId, lines, 'gemini', target);
    if (hit != null) return hit;
    final key = await secrets.read(geminiKeySecret);
    if (key == null || key.isEmpty) {
      throw TranslationException(tx.faltaLaClaveDeGeminiConfiguracion, suggestLocal: true);
    }
    try {
      final out = await _byLines(lines, (texts) => gemini.translate(key, model, texts, target));
      await _save(trackId, lines, 'gemini', target, out);
      return out;
    } on GeminiException catch (error) {
      throw TranslationException(error.message, suggestLocal: true);
    }
  }

  /// Traduce solo las líneas con texto y devuelve una por cada original
  /// (null en las vacías).
  static Future<List<String?>> _byLines(List<String> lines, Future<List<String>> Function(List<String>) run) async {
    final indexes = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].trim().isNotEmpty) i,
    ];
    if (indexes.isEmpty) return List.filled(lines.length, null);
    final translated = await run([for (final i in indexes) lines[i]]);
    final out = List<String?>.filled(lines.length, null);
    for (var k = 0; k < indexes.length && k < translated.length; k++) {
      out[indexes[k]] = translated[k];
    }
    return out;
  }
}

final translationServiceProvider = Provider<TranslationService>((ref) {
  final service = TranslationService();
  ref.onDispose(service.engine.close);
  return service;
});
