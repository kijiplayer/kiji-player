import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

void main() {
  tearDown(() {
    KijiText.chosenFamily = null;
    KijiText.useSystemFont = false;
    KijiLook.style = KijiStyle.nocturne;
  });

  test('Cada opción de "Tipografía" usa una fuente incluida en la app (o la del estilo, o la del sistema)', () {
    final declared = File('pubspec.yaml').readAsStringSync();
    for (final font in AppSettings.fonts) {
      final family = KijiText.familyFor(font);
      if (font == 'kiji' || font == 'system') {
        expect(family, isNull, reason: font);
        continue;
      }
      expect(declared, contains('family: $family'), reason: '$font tiene que venir en la app (assets/fonts, OFL)');
    }
  });

  test('La elegida va en títulos y texto; los números siguen con la del estilo', () {
    KijiLook.style = KijiStyle.graphite;
    expect(KijiText.title().fontFamily, 'Inter', reason: 'la del estilo');
    KijiText.chosenFamily = KijiText.familyFor('newsreader');
    expect(KijiText.title().fontFamily, 'Newsreader');
    expect(KijiText.bodyFamily, 'Newsreader');
    expect(KijiText.mono().fontFamily, 'Inter', reason: 'tiempos y números: los del estilo');
    KijiText.useSystemFont = true;
    expect(KijiText.title().fontFamily, isNull, reason: 'la del sistema gana');
  });

  test('Se guarda y se lee; una que no existe vuelve a la del estilo', () {
    expect(AppSettings.fromJson(const AppSettings().copyWith(font: 'inter').toJson()).font, 'inter');
    expect(AppSettings.fromJson({'font': 'comic-sans'}).font, 'kiji');
  });
}
