// Frases del día (0.9): todas de dominio público, con fuente y en los dos idiomas; ninguna de las
// «a confirmar» sale en la app; y la frase encaja con el momento.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:kiji_player/features/quotes/quotes.dart';
import 'package:kiji_player/l10n/l10n.dart';

void main() {
  final raw = File('assets/quotes/quotes.json').readAsStringSync();
  final quotes = parseQuotes(raw);

  test('Hay al menos 150 frases listas, cada una con autor, fuente, español e inglés', () {
    expect(quotes.length, greaterThanOrEqualTo(150));
    for (final q in quotes) {
      expect(q.author, isNotEmpty, reason: q.id);
      expect(q.source, isNotEmpty, reason: q.id);
      expect(q.es, isNotEmpty, reason: q.id);
      expect(q.en, isNotEmpty, reason: q.id);
      expect(q.tags, isNotEmpty, reason: q.id);
    }
    expect({for (final q in quotes) q.id}.length, quotes.length, reason: 'sin ids repetidos');
  });

  test('Las marcadas «check» (fuente a confirmar) no aparecen; las aprobadas, sí', () {
    final checked = parseQuotes(raw.replaceFirst('{"id":"nye-wagner",', '{"id":"nye-wagner","check":true,'));
    expect(checked.where((q) => q.id == 'nye-wagner'), isEmpty);
    expect(quotes.where((q) => q.id == 'nye-wagner'), hasLength(1), reason: 'aprobada por David');
  });

  test('Encaja con el momento: tomates, rosas, repetir y la hora', () {
    final night = DateTime(2026, 11, 26, 23);
    expect(pickQuote(quotes, QuoteMoment(now: night, tomatoes: 3))!.tags, contains('boo'));
    expect(pickQuote(quotes, QuoteMoment(now: night, roses: 4))!.tags, contains('cheer'));
    expect(pickQuote(quotes, QuoteMoment(now: night, repeating: true))!.tags, contains('repeat'));
    expect(pickQuote(quotes, QuoteMoment(now: night))!.tags, contains('night'));
    expect(pickQuote(quotes, QuoteMoment(now: DateTime(2026, 11, 26, 3)))!.tags, contains('late'));
    expect(pickQuote(quotes, QuoteMoment(now: DateTime(2026, 11, 26, 8)))!.tags, contains('morning'));
  });

  test('El mismo día y momento, la misma frase; otro día, puede cambiar', () {
    final a = pickQuote(quotes, QuoteMoment(now: DateTime(2026, 11, 26, 9)));
    final b = pickQuote(quotes, QuoteMoment(now: DateTime(2026, 11, 26, 11, 30)));
    expect(a!.id, b!.id);
    final days = {for (var d = 1; d <= 10; d++) pickQuote(quotes, QuoteMoment(now: DateTime(2026, 11, d, 9)))!.id};
    expect(days.length, greaterThan(1));
  });

  test('En inglés, el autor y la fuente no quedan en español', () {
    final spanish = RegExp(r'\b(acto|escena|capítulo|parte|libro|tomo|estrofa|Cartas|Noche de Reyes|Orgullo)\b');
    setKijiLocale(const Locale('en'));
    addTearDown(() => setKijiLocale(const Locale('es')));
    for (final q in quotes) {
      expect(spanish.hasMatch(q.sourceText), isFalse, reason: '${q.id}: ${q.sourceText}');
    }
    expect(quotes.firstWhere((q) => q.id == 'seneca-tiempo').authorText, 'Seneca');
  });
}