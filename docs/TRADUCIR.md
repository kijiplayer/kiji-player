# Traducir Kiji

Kiji está en español (la plantilla) e inglés. Esta nota es para sumar idiomas, a mano o con
Weblate.

## Dónde están los textos

- `lib/l10n/app_es.arb`: la plantilla. Cada texto lleva su descripción (`@clave`) para quien
  traduce.
- `lib/l10n/app_en.arb`: inglés. Un idioma nuevo es otro archivo `app_<código>.arb` con las mismas
  claves; `flutter gen-l10n` (o `flutter pub get`) genera el código y el idioma aparece solo en
  `AppLocalizations.supportedLocales`.
- Lo que no es de Flutter:
  - Widgets de Android: `android/app/src/main/res/values/strings.xml` (español) y `values-en/`.
  - Notas de la tienda: `fastlane/metadata/android/<idioma>/` (máximo 500 caracteres por versión).
  - Créditos: `CREDITS.md` y `CREDITS.en.md`.

`test/l10n_test.dart` falla si queda un texto fijo en el código o si a un idioma le falta una
clave. Las excepciones (nombres propios, palabras clave del buscador) llevan `// l10n-ignore`.

## Weblate (cuando se active)

- Componente con formato **"ARB file"**, máscara `lib/l10n/app_*.arb`, idioma base `app_es.arb` y
  la plantilla monolingüe en el mismo archivo.
- Otro componente **"Android String Resource"** para `res/values*/strings.xml` (base `values/`).
- Que Weblate abra PR a la rama de desarrollo (nunca a `master` directo) y que la CI corra
  `l10n_test` en cada uno.
- Respetar los marcadores `{nombre}` y las formas plurales ICU (`{count, plural, ...}`) tal cual.
- Tono simple, sin palabras técnicas (igual que en `CONTRIBUTING.md`).

## Idiomas de derecha a izquierda (árabe, hebreo, persa)

Flutter da vuelta la interfaz sola según el idioma (`Directionality`). Estado actual:

- Listas, filas, barras de navegación y la mayoría de los márgenes ya se adaptan.
- Quedan márgenes con `EdgeInsets.fromLTRB` y alineaciones `Alignment.centerLeft/Right` (unas
  100) que no se dan vuelta. Antes de sumar un idioma RTL, cambiarlos por
  `EdgeInsetsDirectional.fromSTEB` y `AlignmentDirectional.centerStart/End`, y probar con
  `Directionality(textDirection: TextDirection.rtl)` en las pruebas de pantalla.
- La onda, la barra de progreso y los botones anterior/siguiente se dejan como están: van con el
  tiempo, igual que en otros reproductores.
