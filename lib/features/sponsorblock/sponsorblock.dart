// Saltar las partes sin música de los videos musicales con la base pública de SponsorBlock
// (https://sponsor.ajay.app, datos CC BY-NC-SA 4.0). Opcional y apagado de fábrica.
//
// Privacidad: no se manda el ID del video, solo los primeros 4 caracteres de su SHA-256 (la
// consulta «k-anonimidad» de SponsorBlock): la respuesta trae los segmentos de todos los videos que
// empiezan igual y Kiji elige el suyo en el dispositivo.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Categorías de SponsorBlock que tienen sentido en música.
enum SkipCategory {
  musicOfftopic('music_offtopic'), // l10n-ignore
  intro('intro'), // l10n-ignore
  outro('outro'), // l10n-ignore
  preview('preview'), // l10n-ignore
  selfpromo('selfpromo'), // l10n-ignore
  sponsor('sponsor'), // l10n-ignore
  interaction('interaction'); // l10n-ignore

  const SkipCategory(this.apiName);

  final String apiName;

  static SkipCategory? fromApi(String name) => values.where((c) => c.apiName == name).firstOrNull;

  String get label => switch (this) {
    SkipCategory.musicOfftopic => tx.skipSinMusica,
    SkipCategory.intro => tx.skipIntro,
    SkipCategory.outro => tx.skipOutro,
    SkipCategory.preview => tx.skipAvance,
    SkipCategory.selfpromo => tx.skipAutopromocion,
    SkipCategory.sponsor => tx.skipPatrocinio,
    SkipCategory.interaction => tx.skipSuscribete,
  };
}

/// De fábrica (al prenderlo): lo que no es música, intros y finales.
const defaultSkipCategories = ['music_offtopic', 'intro', 'outro']; // l10n-ignore

/// Un tramo para saltar.
@immutable
class SkipSegment {
  const SkipSegment({required this.start, required this.end, required this.category});

  final Duration start;
  final Duration end;
  final SkipCategory category;

  @override
  bool operator ==(Object other) =>
      other is SkipSegment && other.start == start && other.end == end && other.category == category;

  @override
  int get hashCode => Object.hash(start, end, category);
}

/// Prefijo del hash que se manda (4 caracteres hexadecimales del SHA-256 del ID del video).
String hashPrefixFor(String videoId) => sha256.convert(utf8.encode(videoId)).toString().substring(0, 4);

/// Lee la respuesta de `/api/skipSegments/<prefijo>` y se queda con los tramos de [videoId].
List<SkipSegment> parseSkipSegments(Object? json, String videoId) {
  if (json is! List) return const [];
  for (final video in json) {
    if (video is! Map || video['videoID'] != videoId) continue;
    final segments = <SkipSegment>[];
    for (final s in video['segments'] as List? ?? const []) {
      if (s is! Map) continue;
      final category = SkipCategory.fromApi('${s['category']}');
      final range = s['segment'];
      if (category == null || range is! List || range.length < 2) continue;
      final a = range[0], b = range[1];
      if (a is! num || b is! num || b <= a) continue;
      // Solo «saltar» (no los que SponsorBlock marca como silenciar o resaltado).
      if (s['actionType'] != null && s['actionType'] != 'skip') continue; // l10n-ignore
      segments.add(
        SkipSegment(
          start: Duration(milliseconds: (a * 1000).round()),
          end: Duration(milliseconds: (b * 1000).round()),
          category: category,
        ),
      );
    }
    segments.sort((x, y) => x.start.compareTo(y.start));
    return segments;
  }
  return const [];
}

/// Cliente de SponsorBlock: un pedido por video (se guarda en memoria mientras Kiji está abierta).
class SponsorBlockClient {
  SponsorBlockClient({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://sponsor.ajay.app/api', // l10n-ignore
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  final Dio _dio;
  final _cache = <String, List<SkipSegment>>{};

  Future<List<SkipSegment>> segmentsFor(String videoId, List<String> categories) async {
    final key = '$videoId|${categories.join(',')}';
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final response = await _dio.get<Object>(
        '/skipSegments/${hashPrefixFor(videoId)}',
        queryParameters: {'categories': jsonEncode(categories)},
      );
      return _cache[key] = parseSkipSegments(response.data, videoId);
    } on DioException catch (error) {
      // 404: ningún video con ese prefijo tiene tramos (es lo normal).
      if (error.response?.statusCode == 404) return _cache[key] = const [];
      debugPrint('=== SPONSORBLOCK: sin tramos (${error.type.name}) ===');
      return const [];
    } catch (error) {
      debugPrint('=== SPONSORBLOCK: respuesta inesperada (${error.runtimeType}) ===');
      return const [];
    }
  }
}

/// ¿Hay que saltar ahora? El tramo en el que está [position] y que no se deshizo ni se saltó ya.
/// No salta si queda menos de un segundo del tramo (ya casi termina).
SkipSegment? segmentToSkip(List<SkipSegment> segments, Duration position, Set<SkipSegment> done) {
  for (final s in segments) {
    if (done.contains(s)) continue;
    if (position >= s.start && position < s.end - const Duration(seconds: 1)) return s;
  }
  return null;
}
