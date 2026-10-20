<p align="center">
  <b>English</b> | <a href="README.es.md">Español</a>
</p>

<p align="center">
  <img src="assets/branding/kiji_logo.svg" width="112" height="112" alt="Kiji Player logo">
</p>

<h1 align="center">Kiji Player</h1>

<p align="center">
  A free, open-source music player for Android and Windows.<br>
  No ads, no payments, no tracking.
</p>

---

Kiji plays the music on your device and from YouTube Music, anonymously. Everything that is yours
(the queue, playlists, history and downloads) stays on your device.

- Downloads to listen offline, one song or whole playlists.
- Synced lyrics, with translation done on the phone itself.
- A home screen with recommendations calculated on your device.
- Sleep timer, equalizer, crossfade between songs and backups.
- Imports playlists from Echo Music, Metrolist, `.m3u` and other formats.
- In English and Spanish.

## Screenshots

<p align="center">
  <img src="docs/capturas/reproductor.png" width="200" alt="Player">
  <img src="docs/capturas/playlist.png" width="200" alt="A playlist">
  <img src="docs/capturas/traduccion.png" width="200" alt="Lyrics translation">
</p>

## Installation

Versions are published on [Releases](https://github.com/kijiplayer/kiji-player/releases). Kiji runs
on Android 7 or newer and on Windows 10/11.

To build it yourself you need [Flutter](https://flutter.dev) 3.47 or newer:

```bash
flutter pub get
flutter build apk --flavor prod   # Android
flutter build windows             # Windows
```

## License and credits

Kiji is free software under the [GNU GPL-3.0](LICENSE) license.

It builds on the work of [Echo Music](https://github.com/EchoMusicApp/Echo-Music) and
[Metrolist](https://github.com/MetrolistGroup/Metrolist), two free music players for Android, and of
the projects they come from. The full list, with what was taken from each one, is in
[CREDITS.md](CREDITS.md).

Kiji is built with the help of AI, and every change is reviewed and approved by a person.

Kiji is an independent project, compatible with YouTube Music. It is not affiliated with or endorsed
by Google or YouTube.
