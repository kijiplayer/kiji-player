import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/backup/presentation/backup_screen.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';
import 'package:kiji_player/utils/clock_format.dart';
import 'package:flutter/material.dart';

/// Novedades de la 0.6.0.
void main() {
  group('Ajustes nuevos', () {
    test('De fábrica: hora del sistema, sin descargar al dar me gusta, tema oscuro', () {
      const s = AppSettings();
      expect(s.timeFormat, 'system');
      expect(s.downloadLiked, isFalse);
      expect(s.accent, 'nocturne');
      expect(s.theme, 'dark');
      expect(s.font, 'kiji');
      expect(s.lyricsSize, 'normal');
      expect(s.lastSeenVersion, isNull);
    });

    test('Se guardan y se leen igual', () {
      const s = AppSettings(
        timeFormat: '12',
        downloadLiked: true,
        accent: 'ember',
        theme: 'light',
        font: 'system',
        lyricsSize: 'large',
        lastSeenVersion: '0.6.0',
      );
      final r = AppSettings.fromJson(s.toJson());
      expect(r.timeFormat, '12');
      expect(r.downloadLiked, isTrue);
      expect(r.accent, 'ember');
      expect(r.theme, 'light');
      expect(r.font, 'system');
      expect(r.lyricsSize, 'large');
      expect(r.lastSeenVersion, '0.6.0');
    });

    test('Valores desconocidos vuelven a los de fábrica', () {
      final r = AppSettings.fromJson({
        'timeFormat': '36',
        'downloadLiked': 'sí',
        'accent': 'rosa-chicle',
        'theme': 'neón',
        'font': 3,
        'lyricsSize': 'enorme',
      });
      expect(r.timeFormat, 'system');
      expect(r.downloadLiked, isFalse);
      expect(r.accent, 'nocturne');
      expect(r.theme, 'dark');
      expect(r.font, 'kiji');
      expect(r.lyricsSize, 'normal');
    });
  });

  group('Hora en 12 o 24 horas', () {
    test('"Sistema" sigue al teléfono; 12 y 24 lo fuerzan', () {
      expect(use24HourClock('system', system: true), isTrue);
      expect(use24HourClock('system', system: false), isFalse);
      expect(use24HourClock('12', system: true), isFalse);
      expect(use24HourClock('24', system: false), isTrue);
    });

    test('Formato de la hora', () {
      expect(formatClock(DateTime(2026, 1, 1, 8, 5), use24Hour: true), '08:05');
      expect(formatClock(DateTime(2026, 1, 1, 21, 10), use24Hour: true), '21:10');
      expect(formatClock(DateTime(2026, 1, 1, 8, 5), use24Hour: false), '8:05 AM');
      expect(formatClock(DateTime(2026, 1, 1, 21, 10), use24Hour: false), '9:10 PM');
      expect(formatClock(DateTime(2026, 1, 1, 0, 30), use24Hour: false), '12:30 AM');
      expect(formatClock(DateTime(2026, 1, 1, 12, 0), use24Hour: false), '12:00 PM');
    });

    test('Las fechas de las copias usan el mismo formato', () {
      final now = DateTime(2026, 10, 16, 12);
      expect(describeDate(DateTime(2026, 10, 15, 21, 10), now, use24Hour: false), 'ayer 9:10 PM');
      expect(describeDate(DateTime(2026, 10, 1, 9, 0), now, use24Hour: true), '01/10/2026 09:00');
    });
  });

  group('Personalización', () {
    test('De fábrica, la paleta es la Nocturne de siempre', () {
      expect(KijiPalette.resolve(), KijiPalette.nocturne);
      expect(KijiPalette.resolve().background, const Color(0xFF07070C));
    });

    test('Más oscuro: negro puro; claro: fondo claro y texto oscuro', () {
      expect(KijiPalette.resolve(theme: 'darker').background, Colors.black);
      final light = KijiPalette.resolve(theme: 'light');
      expect(light.isLight, isTrue);
      expect(light.background.computeLuminance(), greaterThan(0.8));
      expect(light.text.computeLuminance(), lessThan(0.05));
    });

    test('Cada acento cambia el degradado; uno desconocido vuelve a Nocturne', () {
      final colors = {for (final a in AppSettings.accents) KijiPalette.resolve(accent: a).violet};
      expect(colors.length, AppSettings.accents.length);
      expect(KijiPalette.resolve(accent: 'raro'), KijiPalette.nocturne);
    });

    test('Dos paletas iguales son iguales (no se redibuja todo de gusto)', () {
      expect(
        KijiPalette.resolve(theme: 'light', accent: 'ember'),
        KijiPalette.resolve(theme: 'light', accent: 'ember'),
      );
      expect(KijiPalette.resolve(theme: 'light'), isNot(KijiPalette.resolve()));
    });

    test('Los colores siguen a la paleta activa', () {
      addTearDown(() => KijiColors.palette = KijiPalette.nocturne);
      KijiColors.palette = KijiPalette.resolve(theme: 'light', accent: 'ocean');
      expect(KijiColors.background, const Color(0xFFF4F4FA));
      expect(KijiColors.accentGradient.colors.first, KijiColors.violet);
    });

    test('Tipografía del sistema: sin familia propia', () {
      addTearDown(() => KijiText.useSystemFont = false);
      expect(KijiText.title().fontFamily, 'SpaceGrotesk');
      KijiText.useSystemFont = true;
      expect(KijiText.title().fontFamily, isNull);
      expect(KijiText.mono().fontFamily, isNull);
    });
  });
}
