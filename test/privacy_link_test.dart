// Configuración → Acerca de → «Política de privacidad» abre la página en el idioma de la app.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/updates/updates_screen.dart';
import 'package:kiji_player/l10n/l10n.dart';

void main() {
  tearDown(() => setKijiLocale(const Locale('es')));

  test('En español abre /privacy/#es y en inglés /privacy/#en', () {
    setKijiLocale(const Locale('es'));
    expect(kijiPrivacyPolicyUrl, 'https://kijiplayer.github.io/kiji-player/privacy/#es');
    setKijiLocale(const Locale('en'));
    expect(kijiPrivacyPolicyUrl, 'https://kijiplayer.github.io/kiji-player/privacy/#en');
  });
}
