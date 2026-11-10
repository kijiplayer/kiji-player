import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/style/data/background_store.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

void main() {
  test('Con la capa automática, el texto se lee sobre cualquier fondo, en los tres estilos', () {
    for (final style in KijiStyle.values) {
      final palette = KijiPalette.forStyle(style);
      // El peor caso: una foto toda blanca en los estilos oscuros, toda negra en Papel.
      final worst = palette.isLight ? Colors.black : Colors.white;
      for (var opacity = 0.1; opacity <= 1.0001; opacity += 0.1) {
        final scrim = backgroundScrim(palette, opacity);
        final behind = Color.lerp(palette.background, worst, opacity)!;
        final result = Color.lerp(behind, palette.background, scrim)!;
        expect(KijiPalette.contrastOf(palette.text, result), greaterThanOrEqualTo(4.5), reason: '${style.name} $opacity');
        expect(KijiPalette.contrastOf(palette.muted, result), greaterThanOrEqualTo(4.5), reason: '${style.name} $opacity');
      }
      // Con poca opacidad casi no hace falta capa: el fondo se ve tal cual lo elegiste.
      expect(backgroundScrim(palette, 0.1), lessThan(backgroundScrim(palette, 1)));
    }
  });

  test('La capa se ajusta al tono real de la foto: una oscura casi no se tapa y el texto se lee igual', () {
    for (final style in KijiStyle.values) {
      final palette = KijiPalette.forStyle(style);
      final worst = palette.isLight ? Colors.black : Colors.white;
      // Una foto parecida al fondo del estilo (oscura en Nocturne y Grafito, clara en Papel).
      final soft = Color.lerp(palette.background, worst, 0.25)!;
      expect(backgroundScrim(palette, 0.6, tone: soft), lessThan(backgroundScrim(palette, 0.6) - 0.2),
          reason: '${style.name}: una foto suave no se tapa como si fuera blanca');
      for (final tone in [soft, const Color(0xFFE0A030), const Color(0xFF3060C0), worst]) {
        for (final opacity in [0.3, 0.6, 1.0]) {
          final scrim = backgroundScrim(palette, opacity, tone: tone);
          final result = Color.lerp(Color.lerp(palette.background, tone, opacity)!, palette.background, scrim)!;
          expect(KijiPalette.contrastOf(palette.text, result), greaterThanOrEqualTo(4.5), reason: '${style.name} $tone $opacity');
          expect(KijiPalette.contrastOf(palette.muted, result), greaterThanOrEqualTo(4.5), reason: '${style.name} $tone $opacity');
        }
      }
    }
  });

  test('Con fondo propio el gris secundario se aclara: menos capa, la foto se ve, y todo se lee', () {
    for (final style in KijiStyle.values) {
      final base = KijiPalette.forStyle(style);
      final photo = base.withBackgroundPhoto();
      const tone = Color(0xFF8CABA3); // una foto de colores medios (inventada)
      expect(backgroundScrim(photo, 0.6, tone: tone), lessThan(backgroundScrim(base, 0.6, tone: tone)), reason: style.name);
      expect(0.6 * (1 - backgroundScrim(photo, 0.6, tone: tone)), greaterThan(0.4), reason: '${style.name}: la foto se ve');
      for (final surface in [photo.background, photo.surface, photo.surfaceHigh]) {
        expect(KijiPalette.contrastOf(photo.muted, surface), greaterThanOrEqualTo(4.5), reason: style.name);
      }
    }
  });

  test('El fondo se guarda como un nombre de archivo dentro de Kiji (nunca una ruta)', () {
    final s = const AppSettings().copyWith(backgroundFile: 'fondo-1.png', backgroundBlur: 20, backgroundOpacity: 0.4);
    final back = AppSettings.fromJson(s.toJson());
    expect((back.backgroundFile, back.backgroundBlur, back.backgroundOpacity), ('fondo-1.png', 20.0, 0.4));
    expect(AppSettings.fromJson({'backgroundFile': r'C:\Users\otra\foto.png'}).backgroundFile, isNull);
    expect(AppSettings.fromJson({'backgroundFile': '../../secreto'}).backgroundFile, isNull);
    expect(s.copyWith(clearBackground: true).backgroundFile, isNull, reason: '"Quitar fondo"');
    expect(AppSettings.fromJson({'backgroundBlur': 999, 'backgroundOpacity': -3}).backgroundBlur, AppSettings.maxBackgroundBlur);
  });

  test('Se copia a la carpeta privada de Kiji y "Quitar fondo" la vacía', () async {
    final dir = Directory.systemTemp.createTempSync('kiji_fondo_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final original = File('${dir.path}/elegida.png')..writeAsBytesSync([1, 2, 3]);
    final store = BackgroundStore(directory: () async => Directory('${dir.path}/datos'));

    final first = await store.keep(original.path);
    expect((await store.fileFor(first)).readAsBytesSync(), [1, 2, 3]);
    expect(original.existsSync(), isTrue, reason: 'el archivo del usuario no se toca');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await store.keep(original.path);
    expect((await store.fileFor(first)).existsSync(), isFalse, reason: 'solo queda el último');
    expect((await store.fileFor(second)).existsSync(), isTrue);

    await store.removeAll();
    expect((await store.folder()).listSync(), isEmpty);
  });
}
