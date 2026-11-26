import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/playback_provider.dart';
import '../history/listening_history.dart';
import '../settings/data/settings_store.dart';
import '../streaks/streaks.dart' show dayKey;
import '../theater/data/theater_store.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Una frase real de un autor de dominio público, con su fuente (`assets/quotes/quotes.json`).
/// Nunca letras de canciones. Las que tienen `check` (fuente menos segura) no se muestran hasta
/// que David las revise.
@immutable
class Quote {
  const Quote({
    required this.id,
    required this.author,
    required this.source,
    required this.es,
    required this.en,
    this.original,
    this.tags = const {},
  });

  final String id;
  final String author;
  final String source;
  final String? original;
  final String es;
  final String en;
  final Set<String> tags;

  /// La frase en el idioma de la app.
  String get text => kijiLanguage == 'es' ? es : en;

  static Quote? fromJson(Object? json) {
    if (json is! Map || json['check'] == true) return null;
    final id = json['id'], a = json['a'], s = json['s'], es = json['es'], en = json['en'];
    if (id is! String || a is! String || s is! String || es is! String || en is! String) return null;
    return Quote(
      id: id,
      author: a,
      source: s,
      original: json['o'] as String?,
      es: es,
      en: en,
      tags: {for (final t in json['t'] as List? ?? const []) if (t is String) t},
    );
  }
}

List<Quote> parseQuotes(String json) => [
  for (final q in jsonDecode(json) as List) ?Quote.fromJson(q),
];

final quotesProvider = FutureProvider<List<Quote>>((ref) async {
  try {
    return parseQuotes(await rootBundle.loadString('assets/quotes/quotes.json'));
  } catch (error) {
    debugPrint('=== FRASES: no se pudieron leer (${error.runtimeType}) ===');
    return const [];
  }
});

/// Lo que pasa ahora, para elegir una frase que encaje.
@immutable
class QuoteMoment {
  const QuoteMoment({required this.now, this.repeating = false, this.tomatoes = 0, this.roses = 0});

  final DateTime now;

  /// La canción que suena ya sonó 3 veces o más hoy.
  final bool repeating;
  final int tomatoes;
  final int roses;

  /// Las etiquetas de este momento, de la más fuerte a la más suave.
  List<String> get tags => [
    if (tomatoes >= 3) 'boo',
    if (roses >= 3) 'cheer',
    if (repeating) 'repeat',
    if (now.month == 12) 'december',
    switch (now.hour) {
      < 6 => 'late',
      < 12 => 'morning',
      < 20 => 'afternoon',
      _ => 'night',
    },
    'music',
  ];
}

/// La frase para [moment]: la de la etiqueta más fuerte que tenga frases. Cambia una vez por día (y
/// cuando cambia lo que pasa), siempre la misma para el mismo día y momento.
Quote? pickQuote(List<Quote> quotes, QuoteMoment moment) {
  for (final tag in moment.tags) {
    final options = [for (final q in quotes) if (q.tags.contains(tag)) q];
    if (options.isEmpty) continue;
    final seed = '${dayKey(moment.now)}|$tag'.hashCode & 0x7fffffff;
    return options[seed % options.length];
  }
  return quotes.isEmpty ? null : quotes.first;
}

/// La frase de ahora (null si están apagadas o todavía no se leyeron).
final currentQuoteProvider = Provider<Quote?>((ref) {
  if (!ref.watch(settingsProvider.select((s) => s.dailyQuotes))) return null;
  final quotes = ref.watch(quotesProvider).value ?? const <Quote>[];
  if (quotes.isEmpty) return null;
  final now = DateTime.now();
  final trackId = ref.watch(playbackProvider.select((p) => p.track?.id));
  final history = ref.watch(listeningHistoryProvider);
  final entry = history.where((e) => e.track.id == trackId).firstOrNull;
  final repeating = entry != null && entry.playCount >= 3 && dayKey(entry.lastPlayed) == dayKey(now);
  final (tomatoes, roses) = ref.watch(theaterProvider.select((t) => t.today(now)));
  return pickQuote(quotes, QuoteMoment(now: now, repeating: repeating, tomatoes: tomatoes, roses: roses));
});
