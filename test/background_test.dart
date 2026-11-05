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
