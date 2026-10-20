import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/languages.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Un error de Gemini en palabras simples (para el usuario).
class GeminiException implements Exception {
  const GeminiException(this.message, {this.offline = false});
  final String message;
  final bool offline;
  @override
  String toString() => message;
}

class GeminiModel {
  const GeminiModel(this.name, this.displayName);

  /// "models/gemini-2.5-flash-lite".
  final String name;
  final String displayName;

  bool get isLite => name.contains('flash-lite');
}

/// Modelos que generan texto, el recomendado primero (el Flash-Lite más
/// nuevo, el más liviano).
@visibleForTesting
List<GeminiModel> textModels(Object? json) {
  final models = json is Map ? json['models'] : null;
  if (models is! List) return const [];
  const skip = [
    'embedding', 'image', 'tts', 'audio', 'live', 'aqa', 'veo', 'imagen', 'learnlm', 'robotics', //
    'computer-use', 'transcribe', 'customtools', 'custom-tools',
  ];
  final list = [
    for (final m in models.whereType<Map>())
      if ((m['supportedGenerationMethods'] as List?)?.contains('generateContent') == true &&
          '${m['name']}'.startsWith('models/gemini') &&
          !skip.any('${m['name']}'.toLowerCase().contains))
        GeminiModel('${m['name']}', '${m['displayName'] ?? m['name']}'),
  ];
  bool preview(GeminiModel m) => RegExp(r'preview|exp').hasMatch(m.name);
  list.sort((a, b) {
    if (a.isLite != b.isLite) return a.isLite ? -1 : 1;
    if (preview(a) != preview(b)) return preview(a) ? 1 : -1; // las estables primero
    return b.name.compareTo(a.name); // "latest" y los más nuevos primero
  });
  return list;
}

/// El texto de la primera respuesta de `generateContent`, o null.
@visibleForTesting
String? responseText(Object? json) {
  final candidates = json is Map ? json['candidates'] : null;
  if (candidates is! List || candidates.isEmpty) return null;
  final parts = ((candidates.first as Map?)?['content'] as Map?)?['parts'];
  if (parts is! List || parts.isEmpty) return null;
  final text = (parts.first as Map?)?['text'];
  return text is String ? text : null;
}

/// Traducción con la API de Gemini, con la clave del usuario. Solo se envían
/// las líneas de la letra y el idioma de destino (nada del usuario). La clave
/// va en un header y nunca se escribe en los logs.
class GeminiClient {
  GeminiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://generativelanguage.googleapis.com/v1beta/',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );

  final Dio _dio;

  static GeminiException _explain(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final body = '${error.response?.data}';
      if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout) {
        return GeminiException(tx.sinConexionAInternet, offline: true);
      }
      if (status == 429) return GeminiException(tx.llegasteAlLimiteGratuitoDeGemini);
      if (status == 400 && body.contains('API_KEY')) return GeminiException(tx.laClaveNoEsValidaRevisala);
      if (status == 401 || status == 403) {
        return GeminiException(tx.googleRechazoLaClaveOEl);
      }
      return GeminiException(tx.geminiNoRespondioHttp(status ?? '?'));
    }
    return GeminiException(tx.geminiRespondioAlgoQueKijiNo);
  }

  /// Modelos disponibles con esa clave (sirve también para "Probar").
  Future<List<GeminiModel>> models(String key) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'models',
        queryParameters: {'pageSize': 200},
        options: Options(headers: {'x-goog-api-key': key}),
      );
      return textModels(response.data);
    } catch (error) {
      debugPrint('=== GEMINI: no se pudieron listar los modelos (${error.runtimeType}) ===');
      throw _explain(error);
    }
  }

  /// Traduce [lines] al idioma [target]. Devuelve una línea por cada una.
  Future<List<String>> translate(String key, String model, List<String> lines, String target) async {
    // El pedido a Gemini es técnico: no cambia con el idioma de la app.
    final prompt =
        'Traduce estas líneas de una canción al idioma "${languageName(target)}" ($target). ' // l10n-ignore
        'Mantén el sentido y el tono, una traducción por línea. Responde SOLO con un array JSON de ' // l10n-ignore
        'strings, con exactamente ${lines.length} elementos, en el mismo orden.\n\n${jsonEncode(lines)}'; // l10n-ignore
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$model:generateContent', // l10n-ignore
        options: Options(headers: {'x-goog-api-key': key}),
        data: {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0.2},
        },
      );
      final text = responseText(response.data);
      final decoded = text == null ? null : jsonDecode(text);
      if (decoded is! List || decoded.length != lines.length) {
        throw GeminiException(tx.geminiDevolvioOtraCantidadDeLineas);
      }
      return [for (final line in decoded) '$line'];
    } on GeminiException {
      rethrow;
    } catch (error) {
      debugPrint('=== GEMINI: no se pudo traducir (${error.runtimeType}) ===');
      throw _explain(error);
    }
  }
}
