import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/updates/whats_new.dart';
import 'package:kiji_player/version.dart';

/// Mismo formato que las notas de las versiones publicadas en GitHub.
const _body = '''**English** · [Español](#español)

## ⚠️ Android: reinstall Kiji once

From this version, Kiji has **its final** identifier.

## What's new in 0.5.1
- New app identifier on Android (see [above](#top)).
- Smaller APKs per processor type.

## Downloads

| File | For | SHA-256 |
|---|---|---|
| `Kiji-Player-0.5.1.apk` | Any | `e7d8` |

If you're not sure which APK to pick, use `Kiji-Player-0.5.1.apk`.

---

## Español

## ⚠️ Android: reinstala Kiji una vez

Desde esta versión, Kiji tiene **su identificador** definitivo.

## Novedades de 0.5.1
- Identificador nuevo en Android.
- APK más livianos por tipo de procesador.

## Descargas

| Archivo | Para | SHA-256 |
|---|---|---|
| `Kiji-Player-0.5.1.apk` | Cualquiera | `e7d8` |

Si no sabes cuál elegir, usa `Kiji-Player-0.5.1.apk`.
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notas de GitHub en el idioma de la app', () {
    test('En español: solo la parte en español, sin la tabla de descargas', () {
      final es = releaseNotesFor(_body, 'es');
      expect(es, startsWith('⚠️ Android: reinstala Kiji una vez'));
      expect(es, contains('Kiji tiene su identificador definitivo.'));
      expect(es, contains('• Identificador nuevo en Android.'));
      expect(es, isNot(contains('reinstall')));
      expect(es, isNot(contains('SHA-256')));
      expect(es, isNot(contains('Si no sabes cuál elegir')));
      expect(es, isNot(contains('**')));
    });

    test('En inglés: sin el selector de idioma ni la parte en español', () {
      final en = releaseNotesFor(_body, 'en');
      expect(en, startsWith('⚠️ Android: reinstall Kiji once'));
      expect(en, contains('• New app identifier on Android (see above).'));
      expect(en, isNot(contains('Español')));
      expect(en, isNot(contains('---')));
      expect(en, isNot(contains('e7d8')));
    });

    test('Notas en un solo idioma: se muestran enteras', () {
      expect(releaseNotesFor('- Arreglos', 'en'), '• Arreglos');
      expect(releaseNotesFor('', 'es'), '');
    });
  });

  group('Novedades de esta versión', () {
    test('Solo después de actualizar y una vez por versión', () {
      expect(shouldShowWhatsNew(lastSeenVersion: null, freshInstall: true), isFalse);
      expect(shouldShowWhatsNew(lastSeenVersion: null, freshInstall: false), isTrue); // venía de la 0.5.x
      expect(shouldShowWhatsNew(lastSeenVersion: '0.4.0', freshInstall: false), isTrue);
      expect(shouldShowWhatsNew(lastSeenVersion: kijiVersion, freshInstall: false), isFalse);
    });

    test('Las notas de la compilación actual vienen en los dos idiomas', () async {
      final es = await loadBundledWhatsNew('es');
      final en = await loadBundledWhatsNew('en');
      expect(es, isNotNull);
      expect(en, isNotNull);
      expect(es, isNot(en));
    });

    test('Sin notas para esa compilación: null, sin romper nada', () async {
      expect(await loadBundledWhatsNew('es', build: 99999), isNull);
    });
  });
}
