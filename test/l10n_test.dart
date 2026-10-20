import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/l10n/l10n.dart';

import '../tool/find_hardcoded_text.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

Set<String> _placeholders(String text) =>
    RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)[},]').allMatches(text).map((m) => m[1]!).toSet();

void main() {
  tearDown(() => setKijiLocale(const Locale('es')));

  test('No queda ningún texto de la interfaz fijo en el código (todo va en los ARB)', () {
    final found = findHardcodedText('lib');
    expect(
      found,
      isEmpty,
      reason: 'Textos fijos (pásalos a lib/l10n/app_es.arb y app_en.arb, o marca con '
          '// l10n-ignore si no son de la interfaz):\n${found.join('\n')}',
    );
  });

  test('Cada texto en español tiene su versión en inglés, con los mismos datos', () {
    final es = _arb('app_es.arb');
    final en = _arb('app_en.arb');
    final keys = es.keys.where((k) => !k.startsWith('@'));
    final missing = [for (final k in keys) if (!en.containsKey(k)) k];
    expect(missing, isEmpty, reason: 'Faltan en inglés: $missing');
    for (final k in keys) {
      expect(_placeholders(en[k] as String), _placeholders(es[k] as String), reason: k);
    }
  });

  test('El idioma se elige en Configuración o sigue al del teléfono', () {
    expect(resolveKijiLocale('es', const Locale('en')), const Locale('es'));
    expect(resolveKijiLocale('en', const Locale('es')), const Locale('en'));
    expect(resolveKijiLocale('system', const Locale('es', 'EC')), const Locale('es'));
    expect(resolveKijiLocale('system', const Locale('en', 'US')), const Locale('en'));
    // Un idioma que Kiji todavía no tiene: inglés.
    expect(resolveKijiLocale('system', const Locale('pt', 'BR')), const Locale('en'));
  });

  test('Cambiar el idioma cambia los textos al instante', () {
    setKijiLocale(const Locale('en'));
    expect(kijiLanguage, 'en');
    expect(tx.idioma, 'Language');
    expect(tx.nCanciones(1), '1 song');
    expect(tx.nCanciones(3), '3 songs');
    setKijiLocale(const Locale('es'));
    expect(tx.idioma, 'Idioma');
    expect(tx.nCanciones(1), '1 canción');
  });

  test('El idioma elegido se guarda (y un valor raro vuelve a "sistema")', () {
    final saved = const AppSettings().copyWith(language: 'en').toJson();
    expect(AppSettings.fromJson(saved).language, 'en');
    expect(const AppSettings().language, 'system');
    expect(AppSettings.fromJson({...saved, 'language': 'xx'}).language, 'system');
  });
}
