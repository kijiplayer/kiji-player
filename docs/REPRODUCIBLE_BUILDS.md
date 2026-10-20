# Reproducible builds (Android)

The APK published on [Releases](https://github.com/kijiplayer/kiji-player/releases) can be rebuilt
from the tagged source and compared file by file, except for the signature.

## Environment used for 0.5.0-beta.4

| | |
|---|---|
| Flutter | 3.47.0 (stable, framework `4cf2416426`, engine `59d54a2b28`), Dart 3.13.0 |
| JDK | OpenJDK 25.0.2 (Android Studio JBR) |
| Gradle / AGP / Kotlin | 9.3.1 / 9.1.0 / 2.4.0 |
| Android SDK | platform 37, build-tools 36.0.0 |

## Build

```bash
git checkout v0.5.0-beta.4
flutter pub get
flutter build apk --release --flavor prod
```

The unsigned contents of `build/app/outputs/flutter-apk/app-prod-release.apk` match the published
APK when the project is built from a checkout at the same path. Flutter writes the absolute path of
`.dart_tool/flutter_build/dart_plugin_registrant.dart` into `libapp.so`, so a build from a different
folder differs only in that string.

## Compare

Every entry outside `META-INF/` (the signature) must be identical, for example with
[diffoscope](https://diffoscope.org/):

```bash
diffoscope Kiji-Player-0.5.0-beta.4.apk build/app/outputs/flutter-apk/app-prod-release.apk
```

Only `META-INF/` should differ.

The APK is signed with the certificate `CN=Kiji Player`, SHA-256
`4734c315830c368bff97784bcccaad5b20650ff04405377d25a5d754c740b1f3`.
