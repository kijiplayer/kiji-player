import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/style/presentation/accent_picker.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

void main() {
  test('El acento propio se guarda y se lee; uno roto vuelve al de fábrica', () {
    final s = const AppSettings().copyWith(accent: 'custom', customAccent: 0xFFFFD54F);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.customAccentColor, const Color(0xFFFFD54F));
    expect(AppSettings.fromJson({'accent': 'custom'}).accent, 'nocturne', reason: 'sin color, el de siempre');
    expect(const AppSettings().customAccentColor, isNull);
  });

  test('Códigos de color', () {
    expect(parseHex('#7c5cff'), const Color(0xFF7C5CFF));
    expect(parseHex('F80'), const Color(0xFFFF8800));
    expect(parseHex('hola'), isNull);
    expect(colorHex(const Color(0xFF0B1A3A)), '#0B1A3A');
  });

  test('Un color que no se lee se ajusta solo, en los tres estilos', () {
    // Azul marino casi negro sobre fondo oscuro: se aclara. Amarillo sobre Papel (claro): se oscurece.
    final dark = KijiPalette.forStyle(KijiStyle.graphite, custom: const Color(0xFF0B1A3A));
    expect(KijiPalette.contrastOf(dark.violet, dark.background), greaterThanOrEqualTo(4.5));
    expect(dark.violet.computeLuminance(), greaterThan(const Color(0xFF0B1A3A).computeLuminance()));
    final light = KijiPalette.forStyle(KijiStyle.paper, custom: const Color(0xFFFFEB3B));
    expect(KijiPalette.contrastOf(light.violet, light.background), greaterThanOrEqualTo(4.5));
    expect(light.violet.computeLuminance(), lessThan(const Color(0xFFFFEB3B).computeLuminance()));
    // Uno que ya se lee queda igual.
    const fine = Color(0xFFFF9800);
    expect(KijiPalette.forStyle(KijiStyle.nocturne, custom: fine).violet, fine);
  });

  testWidgets('Elegir una muestra la aplica en vivo', (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: AccentPicker())),
    ));
    await tester.tap(find.byTooltip('#FF9800'));
    await tester.pump();
    expect(container.read(settingsProvider).customAccentColor, const Color(0xFFFF9800));
    expect(find.text('#FF9800'), findsOneWidget, reason: 'el código queda escrito');
  });
}
