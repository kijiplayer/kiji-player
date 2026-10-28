# Reproducible builds (Android)

The APK published on [Releases](https://github.com/kijiplayer/kiji-player/releases) can be rebuilt
from the tagged source and compared file by file, except for the signature.

## Environment used for 0.5.1, 0.6.0 and 0.7.0

| | |
|---|---|
| Flutter | 3.47.0 (stable, framework `4cf2416426`, engine `59d54a2b28`), Dart 3.13.0 |
| JDK | OpenJDK 25.0.2 (Android Studio JBR) |
| Gradle / AGP / Kotlin | 9.3.1 / 9.1.0 / 2.4.0 |
| Android SDK | platform 37, build-tools 36.0.0 |

## Build

```bash
git checkout v0.7.0
flutter pub get
dart run tool/patch_plugins.dart
flutter build apk --release --flavor prod
```

`tool/patch_plugins.dart` patches an old plugin (`on_audio_query_android` 1.1.0) that doesn't
build with the current Gradle; the published APKs were built with the same patch. Tags up to
v0.6.0 don't include that file yet: take it from `master` before running it:

```bash
git show origin/master:tool/patch_plugins.dart > tool/patch_plugins.dart
```

The per-architecture APKs (`Kiji-Player-<version>-arm64-v8a.apk` and the others) are the same build
with `--target-platform android-arm64`, `android-arm` or `android-x64`.

The unsigned contents of `build/app/outputs/flutter-apk/app-prod-release.apk` match the published
APK when the project is built from a checkout at the same path. Flutter writes the absolute path of
`.dart_tool/flutter_build/dart_plugin_registrant.dart` into `libapp.so`, so a build from a different
folder differs only in that string.

## Compare

Every entry outside `META-INF/` (the signature) must be identical, for example with
[diffoscope](https://diffoscope.org/):

```bash
diffoscope Kiji-Player-0.6.0.apk build/app/outputs/flutter-apk/app-prod-release.apk
```

Only `META-INF/` should differ.

The APK is signed with the certificate `CN=Kiji Player`, SHA-256
`4734c315830c368bff97784bcccaad5b20650ff04405377d25a5d754c740b1f3`.
