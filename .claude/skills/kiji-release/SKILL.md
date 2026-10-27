---
name: kiji-release
description: Pasos para preparar y publicar una versión de Kiji Player (versión, notas ES/EN, fastlane, etiqueta, firma y Obtainium). Usar cuando se pida "sacar", "preparar" o "publicar" una versión o release. Nunca publicar sin aprobación.
---

# Publicar una versión de Kiji

**Nada se publica sin la aprobación explícita del mantenedor.** Preparar todo y pedir el "sí"
antes de crear la etiqueta. Seguir también la skill `kiji-reglas`.

## 1. Antes
- La versión candidata ya pasó por Kiji Dev (1–2 actualizaciones probadas sin errores nuevos) y es
  el MISMO commit, sin cambios de código.
- `flutter analyze` sin avisos y `flutter test` en verde (en la PC). CI de GitHub en verde.

## 2. Versión
- `dart run tool/version.dart X.Y.Z`: escribe `version: X.Y.Z+N` en `pubspec.yaml`
  (versionName = X.Y.Z, versionCode = N, siempre +1) y `lib/version.dart`. No editar a mano.

## 3. Notas (inglés y español)
- `CHANGELOG.md`: una entrada en tono humano para X.Y.Z.
- fastlane, con el número de compilación N como nombre:
  - `fastlane/metadata/android/es-ES/changelogs/N.txt`
  - `fastlane/metadata/android/en-US/changelogs/N.txt`
  Cortas (máx. 500 caracteres). Son también las notas de la release y "Novedades" en la app.

## 4. Etiqueta (solo con aprobación)
- Commit en `master` vía PR (master está protegido: nada de force push).
- `git tag vX.Y.Z` (igual a pubspec) y `git push origin vX.Y.Z`. `release.yml` compila los 4 APK
  firmados (`Kiji-Player-X.Y.Z.apk` y por arquitectura) y el instalador de Windows, y crea una
  release **normal** (no pre-release) con las notas ES/EN.

## 5. Verificar
- Firma de cada APK: `apksigner verify --print-certs <apk>` → `CN=Kiji Player`, la misma huella
  de siempre. Si no coincide, retirar la release y avisar.
- SHA-256 de cada archivo en las notas.
- Obtainium: la release es "Latest" (no pre-release), la etiqueta es `vX.Y.Z` y el APK universal
  se llama `Kiji-Player-X.Y.Z.apk`. Comprobar que la API la ve:
  `gh api repos/kijiplayer/kiji-player/releases/latest --jq '.tag_name, [.assets[].name]'`.
- El aviso de actualizaciones de la app lee el mismo `releases/latest`.
