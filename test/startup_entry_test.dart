// «Iniciar Kiji al encender la PC» (0.9, Windows): la entrada se prende, se lee y se borra; al
// terminar la prueba siempre queda borrada.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/desktop/startup_entry.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';

void main() {
  test('El comando lleva la ruta entre comillas y --startup', () {
    final entry = WindowsStartupEntry(executable: r'C:\Program Files\Kiji Player\kiji_player.exe');
    expect(entry.command, r'"C:\Program Files\Kiji Player\kiji_player.exe" --startup');
  });

  test('Apagado de fábrica; «Seguir donde lo dejé» prendido', () {
    const s = AppSettings();
    expect(s.startWithWindows, isFalse);
    expect(s.startupResume, isTrue);
    final back = AppSettings.fromJson(s.copyWith(startWithWindows: true, startupResume: false).toJson());
    expect((back.startWithWindows, back.startupResume), (true, false));
  });

  test(
    'En Windows: prender, leer y apagar la entrada del registro',
    () async {
      final entry = WindowsStartupEntry(executable: r'C:\inexistente\kiji_prueba.exe');
      final before = await entry.isEnabled();
      addTearDown(() async {
        // Si ya estaba prendida antes de la prueba (la de verdad), no se toca.
        if (!before) await entry.disable();
      });
      if (before) return; // no pisar una entrada real
      expect(await entry.enable(), isTrue);
      expect(await entry.isEnabled(), isTrue);
      expect(await entry.disable(), isTrue);
      expect(await entry.isEnabled(), isFalse);
    },
    skip: Platform.isWindows ? false : 'solo en Windows',
  );
}
