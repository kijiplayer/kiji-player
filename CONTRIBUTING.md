# Cómo contribuir a Kiji · Contributing to Kiji

**Español** · [English](#english)

## Español

¡Gracias por querer ayudar! Kiji es un reproductor de música libre (GPL-3.0), sin pagos, sin
anuncios y sin telemetría. Esta guía explica cómo compilarlo, probarlo y mandar cambios.

### Compilar

Necesitas:
- **Flutter 3.47.0** (canal stable) y Dart 3.13.
- **Android:** Android SDK y Java 17.
- **Windows:** Visual Studio 2022 con "Desarrollo para el escritorio con C++" y `nuget.exe` en el
  PATH (lo usa el plugin de WebView).

```sh
git clone https://github.com/kijiplayer/kiji-player.git
cd kiji-player
flutter pub get
dart run tool/patch_plugins.dart   # parche de on_audio_query (Android); se corre una vez
```

Hay dos *flavors*: `prod` (Kiji) y `dev` (Kiji Dev, que se instala al lado, con otro id y sus
propios datos). **Prueba siempre en Kiji Dev** para no tocar tu música:

```sh
flutter run --flavor dev -d <id-del-celular>      # Android
flutter build apk --debug --flavor dev            # APK de Kiji Dev
flutter run -d windows                            # Windows
```

Sin la clave de firma (no está en el repo), las compilaciones release se firman con la clave de
depuración.

### Pruebas

```sh
flutter analyze                                   # sin avisos
flutter test                                      # todas las pruebas (no salen a internet)
flutter test integration_test/recorrido_test.dart -d windows   # recorrido completo, solo en PC
flutter test test_live/extractor_live_test.dart   # extractor contra YouTube real (sí sale a internet)
```

- **Nunca** corras `integration_test/` en un celular: desinstala la app y se pierden sus datos.
- Si algo de YouTube dejó de andar: [docs/EXTRACTOR.md](docs/EXTRACTOR.md).

### Reglas del proyecto

- **Cero Sorpresas.** Kiji es previsible y reversible. Toda automatización importante se puede
  apagar y **nada sale del dispositivo sin que el usuario lo pida**: nada de telemetría, analytics,
  anuncios ni servicios de Google Play.
- **Nada personal:** ni en el código, ni en las pruebas, ni en capturas, issues o PR. Sin nombres,
  correos, cuentas, rutas de tu equipo, historiales ni listas reales de nadie. Usa **datos
  inventados** (por ejemplo, "Paper Lanterns · Mira Solenne").
- **Sin letras reales de canciones** en pruebas, capturas, issues ni PR. Usa textos inventados o de
  dominio público ("The sun is warm today / We walk along the river"). Títulos y artistas sí se
  pueden usar.
- **Nunca subas** claves, cookies, tokens, `key.properties`, `.jks` ni `google-services.json`.
- **Textos de la app** en `lib/l10n/app_es.arb` (la plantilla, con su descripción) y
  `lib/l10n/app_en.arb`. Nada de textos fijos en el código (`test/l10n_test.dart` lo revisa).
  Tono simple, sin palabras técnicas.
- **Comentarios y mensajes de commit en español.** Si no hablas español, escríbelos en inglés y
  los traducimos al revisar.
- **Código de otros proyectos GPL** (Echo Music, Metrolist…): se puede portar. Lleva un encabezado
  con el proyecto y el archivo original, y se agrega a `CREDITS.md`.
- **Multiplataforma:** nada que llame directo a un plugin de una sola plataforma. Va detrás de una
  interfaz en `domain/` con una implementación por plataforma en `data/`. Rutas con
  `path_provider` y `path`.
- **Estructura:** `lib/features/<módulo>/{data,domain,presentation}`, estado con Riverpod. Logs
  con `debugPrint('=== MÓDULO: mensaje ===')` y nunca un `catch` silencioso.
- Las hojas que suben desde abajo se abren con `showKijiSheet`
  (`lib/widgets/nocturne/kiji_sheet.dart`).

### Cómo enviar un cambio (PR)

1. Abre un issue o comenta en uno (los fáciles tienen la etiqueta
   [`good first issue`](https://github.com/kijiplayer/kiji-player/labels/good%20first%20issue)).
2. Haz un *fork* y una rama a partir de `master`.
3. Cambios chicos: una cosa por PR, con pruebas si cambia la lógica o la interfaz.
4. Antes de mandarlo: `flutter analyze` sin avisos y `flutter test` en verde.
5. Abre el PR y completa la plantilla. El CI (GitHub Actions) corre el análisis, las pruebas y la
   compilación de Android y Windows; tiene que quedar en verde.

### Releases (solo para quien mantiene el proyecto)

Una release se publica sola al subir una etiqueta `vX.Y.Z` que coincida con `pubspec.yaml`. Antes:
`dart run tool/version.dart X.Y.Z`, la entrada en `CHANGELOG.md` y las novedades en
`fastlane/metadata/android/{es-ES,en-US}/changelogs/<compilación>.txt` (menos de 500 caracteres).
Con eso, la Action [Release](.github/workflows/release.yml) compila los 4 APK firmados y el
instalador de Windows, y crea la release con las notas en inglés y español.

**Cargar la clave de firma en GitHub (una sola vez):**

1. En la PC que tiene la clave, abre PowerShell y copia el `.jks` en base64 al portapapeles:
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ruta\a\tu-clave.jks")) | Set-Clipboard
   ```
2. En GitHub: el repositorio → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret**. Crea estos cuatro:

   | Nombre | Valor |
   |---|---|
   | `KIJI_KEYSTORE_BASE64` | lo que copiaste en el paso 1 (pegar) |
   | `KIJI_KEYSTORE_PASSWORD` | la contraseña del almacén (`storePassword` de `key.properties`) |
   | `KIJI_KEY_ALIAS` | el alias de la clave (`keyAlias`) |
   | `KIJI_KEY_PASSWORD` | la contraseña de la clave (`keyPassword`) |

3. Vacía el portapapeles (copia cualquier otra cosa). Nunca pegues la clave en un issue, un chat ni
   un archivo del repo.
4. Prueba: Actions → **Release** → **Run workflow**. Compila todo sin publicar. En el resumen,
   cada APK tiene que decir `CN=Kiji Player`.

Los Secrets no se pueden leer desde GitHub ni desde un PR de un *fork*. La Action escribe la clave
en el runner solo mientras compila y la borra al terminar.

---

## English

Thanks for wanting to help! Kiji is a free (GPL-3.0) music player with no payments, no ads and no
telemetry. This guide explains how to build it, test it and send changes.

### Building

You need:
- **Flutter 3.47.0** (stable channel) and Dart 3.13.
- **Android:** Android SDK and Java 17.
- **Windows:** Visual Studio 2022 with "Desktop development with C++" and `nuget.exe` on the PATH
  (the WebView plugin uses it).

```sh
git clone https://github.com/kijiplayer/kiji-player.git
cd kiji-player
flutter pub get
dart run tool/patch_plugins.dart   # on_audio_query patch (Android); run it once
```

There are two *flavors*: `prod` (Kiji) and `dev` (Kiji Dev, installed side by side, with another
id and its own data). **Always test on Kiji Dev** so your own music stays untouched:

```sh
flutter run --flavor dev -d <phone-id>            # Android
flutter build apk --debug --flavor dev            # Kiji Dev APK
flutter run -d windows                            # Windows
```

Without the signing key (it's not in the repo), release builds are signed with the debug key.

### Tests

```sh
flutter analyze                                   # no warnings
flutter test                                      # all tests (no internet)
flutter test integration_test/recorrido_test.dart -d windows   # full walkthrough, PC only
flutter test test_live/extractor_live_test.dart   # extractor against real YouTube (uses internet)
```

- **Never** run `integration_test/` on a phone: it uninstalls the app and its data is lost.
- If something with YouTube stopped working: [docs/EXTRACTOR.md](docs/EXTRACTOR.md).

### Project rules

- **Zero Surprises.** Kiji is predictable and reversible. Every important automation can be turned
  off, and **nothing leaves the device unless the user asks for it**: no telemetry, analytics, ads
  or Google Play services.
- **Nothing personal:** not in code, tests, screenshots, issues or PRs. No names, emails, accounts,
  paths from your computer, or anyone's real history or playlists. Use **invented data** (for
  example, "Paper Lanterns · Mira Solenne").
- **No real song lyrics** in tests, screenshots, issues or PRs. Use invented or public-domain text
  ("The sun is warm today / We walk along the river"). Titles and artists are fine.
- **Never commit** keys, cookies, tokens, `key.properties`, `.jks` or `google-services.json`.
- **App texts** go in `lib/l10n/app_es.arb` (the template, with a description) and
  `lib/l10n/app_en.arb`. No hard-coded texts (`test/l10n_test.dart` checks it). Simple words, no
  jargon.
- **Comments and commit messages in Spanish.** If you don't speak Spanish, write them in English
  and we'll translate them during review.
- **Code from other GPL projects** (Echo Music, Metrolist…) can be ported. It gets a header naming
  the project and the original file, and an entry in `CREDITS.md`.
- **Cross-platform:** nothing calls a single-platform plugin directly. It goes behind an interface
  in `domain/` with one implementation per platform in `data/`. Paths with `path_provider` and
  `path`.
- **Structure:** `lib/features/<module>/{data,domain,presentation}`, state with Riverpod. Logs with
  `debugPrint('=== MODULE: message ===')`, never a silent `catch`.
- Bottom sheets open with `showKijiSheet` (`lib/widgets/nocturne/kiji_sheet.dart`).

### Sending a change (PR)

1. Open an issue or comment on one (easy ones are labeled
   [`good first issue`](https://github.com/kijiplayer/kiji-player/labels/good%20first%20issue)).
2. Fork the repo and branch off `master`.
3. Small changes: one thing per PR, with tests if logic or UI changes.
4. Before sending: `flutter analyze` with no warnings and `flutter test` green.
5. Open the PR and fill in the template. CI (GitHub Actions) runs analysis, tests and the Android
   and Windows builds; it has to pass.

### Releases (maintainers only)

A release is published by pushing a `vX.Y.Z` tag that matches `pubspec.yaml`. Before that:
`dart run tool/version.dart X.Y.Z`, the `CHANGELOG.md` entry and the notes in
`fastlane/metadata/android/{es-ES,en-US}/changelogs/<build>.txt` (under 500 characters). The
[Release](.github/workflows/release.yml) action then builds the 4 signed APKs and the Windows
installer, and creates the release with English and Spanish notes.

**Loading the signing key into GitHub (once):** encode the `.jks` file in base64 and create the
repository secrets `KIJI_KEYSTORE_BASE64`, `KIJI_KEYSTORE_PASSWORD`, `KIJI_KEY_ALIAS` and
`KIJI_KEY_PASSWORD` (Settings → Secrets and variables → Actions). Detailed steps are in the
Spanish section above. Test it with Actions → **Release** → **Run workflow**, which builds
everything without publishing.
