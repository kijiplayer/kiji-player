# Credits

Kiji Player is free software under the **GNU GPL-3.0** license (see `LICENSE`).

Kiji would not exist without the work of other open-source projects. We studied their code and
reused ideas, and in some cases code, respecting their licenses. Thanks to everyone who builds and
maintains them.

## Projects we build on

| Project | License | What we took |
|---|---|---|
| [Echo Music](https://github.com/EchoMusicApp/Echo-Music) (iad1tya and contributors) | GPL-3.0 | YouTube Music playback strategy: VISIONOS / ANDROID_VR clients with `visitorData`, signature and `n` parameter deciphering flow in a WebView, player configuration table. Architecture reference and feature inspiration. |
| [Metrolist](https://github.com/MetrolistGroup/Metrolist) (MetrolistGroup and contributors) | GPL-3.0 | The base Echo Music starts from; architecture reference for the InnerTube client, PO token generation and feature design. |
| InnerTune (Zion Huang, Malopieds) and OuterTune (Davide Garberi, Michael Zh) | GPL-3.0 | The original projects Metrolist and Echo Music descend from. |

## Kiji files adapted from other projects

| Kiji file | Project | Original file |
|---|---|---|
| `lib/features/yt_music/data/ytm_client.dart`, `yt_clients.dart` | Echo Music | `innertube/.../models/YouTubeClient.kt`, `app/src/main/kotlin/.../utils/YTPlayerUtils.kt` |
| `lib/features/yt_music/data/webview_ejs_solver.dart`, `player_script.dart` | Echo Music | `utils/sabr/EjsNTransformSolver.kt`, `utils/cipher/CipherWebView.kt`, `PlayerJsFetcher.kt`, `PlayerConfigStore.kt` |
| `lib/features/yt_music/data/po_token.dart` | Echo Music, which takes it from NewPipe (GPL-3.0) and BgUtils (LuanRT, MIT) | `utils/potoken/PoTokenWebView.kt`, `PoTokenGenerator.kt`, `JavaScriptUtil.kt`, `assets/po_token.html` |
| `lib/features/playback_memory/data/playback_memory_store.dart` | Echo Music (idea, not code) | `core/.../models/PersistQueue.kt`, `PersistPlayerState.kt`, `MusicService.kt` (what to save, when, and discarding a damaged save) |
| `lib/features/downloads/data/download_service.dart`, `downloads_repository.dart` | Echo Music (idea, not code) | `playback/DownloadUtil.kt`, `ExoDownloadService.kt` (in-app downloads, separate from the cache, resumable, Wi-Fi only option) |
| `lib/features/system_media/data/audio_service_controls.dart` | Echo Music (idea, not code) | `playback/MusicService.kt`, `MediaLibrarySessionCallback.kt` (media session, notification and system buttons) |
| `lib/features/stream_cache/data/stream_cache.dart` | Echo Music (idea, not code) | `playback/DownloadUtil.kt` (`playerCache`: cache of what you listened to, separate from downloads, with a limit) |
| `lib/features/queue/` (`queue_operations.dart`, `queue_screen.dart`, `track_actions.dart`) | Echo Music (idea, not code) | `ui/player/Queue.kt`, `ui/menu/QueueMenu.kt` (reorder, remove, play next) |
| `lib/features/account/` (`yt_session.dart`, `account_store.dart`, `account_screens.dart`) | Echo Music (idea and protocol, not code) | `ui/screens/LoginScreen.kt` (sign in inside a WebView and keep the music.youtube.com cookies), `innertube/.../InnerTube.kt` (`SAPISIDHASH` header), `ui/screens/settings/AccountSettingsScreen.kt` |
| `lib/widgets/nocturne/glass.dart` | Echo Music (idea, not code) | `ui/component/GlassEffect.kt` and the `backdrop/` folder (glass surfaces) |
| `lib/features/settings/` (`settings_store.dart`, `setting_search.dart`, `settings_screen.dart`) | Echo Music (idea, not code) | `constants/PreferenceKeys.kt`, `ui/screens/settings/`, `SearchableSettings.kt` (sections and settings search) |
| `lib/features/sleep_timer/` (`sleep_timer_logic.dart`) | Echo Music (idea, not code) | `playback/SleepTimer.kt` (timer by minutes and at the end of the song) |
| `lib/features/lyrics/` (`lyrics.dart`, `lrclib_client.dart`, `lyrics_repository.dart`, `lyrics_screen.dart`) | Echo Music (idea, not code) | `lyrics/LrcLibLyricsProvider.kt`, `LyricsHelper.kt`, `LyricsUtils.kt`, `ui/component/LyricsV2.kt` |
| `lib/features/playlists/` (`playlist.dart`, `smart_lists.dart`, `playlist_screens.dart`) | Echo Music (idea, not code) | `ui/screens/playlist/LocalPlaylistScreen.kt`, `AutoPlaylistScreen.kt` |
| `lib/features/import/data/import_parsers.dart` | Echo Music (format structure, not code) | `viewmodels/BackupRestoreViewModel.kt`, `ui/screens/settings/BackupAndRestore.kt`, `core/.../db/entities/` (song, artist, playlist and event tables) |
| `lib/features/backup/` (`backup_manifest.dart`, `backup_screen.dart`) | Echo Music (idea, not code) | `ui/screens/settings/BackupAndRestore.kt`, `viewmodels/BackupRestoreViewModel.kt` (backup to a file and restore) |
| `lib/features/equalizer/` (`equalizer_model.dart`, `equalizer_screen.dart`) | Echo Music (idea, not code) | `ui/screens/equalizer/EqScreen.kt`, `EQViewModel.kt`, `dsp-core/.../models/SavedEQProfile.kt` (saved profiles and an active one) |
| `lib/features/playback_extras/` (`playback_rules.dart`) | Echo Music (idea, not code) | `playback/crossfade/EqualPowerCurve.kt` (constant power curve), `playback/MusicService.kt` (PauseOnMute, ResumeOnBluetoothConnect) |
| `android/.../extractor/InnerTubeXEngine.kt` | Echo Music 1.4.3 (GPL-3.0) | `utils/InnerTubeXResolver.kt` (engine A: per-song exclusion, warm-up, remote config) |
| `android/.../extractor/PoTokenWebView.kt`, `PoTokenGenerator.kt`, `JavaScriptUtil.kt`, `PoTokenException.kt`, `assets/po_token.html` | Echo Music 1.4.3, which in turn comes from NewPipe (GPL-3.0) | `utils/potoken/*` (BotGuard PO token in a WebView). Kiji fixed the binding: the URL token is bound to the video |
| `lib/features/stream_cache/data/chunked_source.dart` | Echo Music (idea, own code) | `playback/ChunkedDataSource.kt` (bounded ranges and renewed URL) |
| `packages/just_audio_media_kit/` (local copy with changes) | [just_audio_media_kit](https://github.com/Pato05/just_audio_media_kit) 2.1.0 (Pato05, Unlicense) | `lib/mediakit_player.dart`, `lib/just_audio_media_kit.dart` (Kiji adds speed, pitch and sound effects in a single mpv filter chain) |

## Services Kiji uses (only when the user asks)

| Service | What for | What is sent |
|---|---|---|
| [LRCLIB](https://lrclib.net) | Synced lyrics (free, no account) | Title, artist, album and duration, when you tap "Lyrics". |
| [YouLyPlus / LyricsPlus](https://github.com/ibratabian17/YouLyPlus) (community servers `lyricsplus.*`, `lyrics-plus-backend.vercel.app`) | Word-by-word lyrics | Title, artist, album, duration and video id, only if the previous ones don't have them. |
| [PaxSenix](https://lyrics.paxsenix.org) | Synced lyrics | Title and artist. |
| [Unison](https://unison.boidu.dev) (by Better Lyrics) | Synced lyrics contributed by the community | Video id, or title, artist and duration. |
| [Better Lyrics](https://better-lyrics.boidu.dev) (`lyrics-api.boidu.dev`) | Synced lyrics | Title, artist, album and duration. |
| [KuGou](https://www.kugou.com) | Synced lyrics (large Asian catalog) | Title, artist and duration. |
| YouTube (captions) | Lyrics from the video's captions | Video id. |
| [YouTube Music](https://music.youtube.com) | Unsynced lyrics from the "Lyrics" tab | Video id. |
| [Mozilla Remote Settings](https://firefox.settings.services.mozilla.com) | Download, only once, the engine and the model of a language to translate on the device | Nothing about the song: only which language files are downloaded. |
| [zemer-cipher](https://github.com/ZemerTeam/zemer-cipher) (GitHub) | The `player_configs.json` table to decipher the audio (engines A and B), at most every 6 h | Nothing of yours: GitHub sees a request for a public file. |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) (GitHub releases, PC only and on request) | Extraction engine C, if the user accepts it | The official program is downloaded and its fingerprint verified; then it asks YouTube for the song's audio, like Kiji. |
| [Google Gemini API](https://ai.google.dev) (optional, off by default) | Translate lyrics with AI, with the user's own key | Only the lyric lines and the target language, with the user's key (encrypted on the device). |
| [song.link / Odesli](https://odesli.co) | Universal link when sharing a song | Nothing from Kiji: the link is just built with the video id; whoever receives it opens it. |

## Third-party components used as is

| Component | License | Use |
|---|---|---|
| [yt-dlp/ejs](https://github.com/yt-dlp/ejs) 0.8.0 (`yt.solver.core.js`, `yt.solver.lib.js`) | Unlicense | Signature and `n` parameter solver for the YouTube player (in `assets/solver/`, with `LICENSES.md`). |
| [meriyah](https://github.com/meriyah/meriyah) 6.1.4 (inside `yt.solver.lib.js`) | ISC | JavaScript parser used by the solver. |
| [astring](https://github.com/davidbonnet/astring) 1.9.0 (inside `yt.solver.lib.js`) | MIT | JavaScript code generator used by the solver. |
| Echo Music's `player_configs.json` | GPL-3.0 | Table of players verified by hash (Kiji uses the `sts`). |
| [crop_your_image](https://pub.dev/packages/crop_your_image) | Apache 2.0 | Cropping custom photos. |
| [image](https://pub.dev/packages/image) | MIT | Shrinking custom photos to 800 px. |
| [Space Grotesk](https://github.com/floriankarsten/space-grotesk) (Florian Karsten) | SIL OFL 1.1 | Title typeface, included in `assets/fonts/space_grotesk/` (with its `OFL.txt`). |
| [bergamot-translator](https://github.com/mozilla/bergamot-translator) (WebAssembly engine, Firefox version 3.0) | MPL-2.0 | On-device translation. Downloaded from Mozilla's servers; not bundled in the app. |
| `bergamot-translator.js` from [Firefox](https://searchfox.org/mozilla-central/source/toolkit/components/translations/bergamot-translator) | MPL-2.0 | The engine's JavaScript glue, unchanged, in `assets/translation/`. |
| [Firefox Translations models](https://github.com/mozilla/firefox-translations-models) (Mozilla) | MPL-2.0 | One model per language pair; downloaded only when the user chooses to translate, and they can be deleted. |
| [url_launcher](https://pub.dev/packages/url_launcher) | BSD-3-Clause | Opening pages in the browser (Gemini guide). |
| [InnerTubeX](https://github.com/MetrolistGroup/innertubex) v0.10.0 (MetrolistGroup) | GPL-3.0 | Extraction engine A on Android, from JitPack. |
| [quickjs-kt](https://github.com/dokar3/quickjs-kt) (inside InnerTubeX) | Apache-2.0 | JavaScript engine for deciphering on Android. |
| [Ktor](https://ktor.io), [OkHttp](https://square.github.io/okhttp/), [kotlinx.coroutines](https://github.com/Kotlin/kotlinx.coroutines) | Apache-2.0 | Networking and concurrency for engine A. |
| [WorkManager](https://developer.android.com/jetpack/androidx/releases/work) (AndroidX) | Apache-2.0 | Daily extractor test (Wi-Fi only and battery not low). |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | Unlicense | Engine C (PC only, optional): not bundled in the app; downloaded if the user asks for it. |
| [flutter_svg](https://pub.dev/packages/flutter_svg) | MIT | Showing the logo (`assets/branding/kiji_logo.svg`) inside the app. |
| [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) (development only) | MIT | Generating the Android adaptive icon and the Windows `.ico` from the logo. |
| [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono) (JetBrains) | SIL OFL 1.1 | Typeface for times and numbers, included in `assets/fonts/jetbrains_mono/` (with its `OFL.txt`). |
| [Inter](https://github.com/rsms/inter) (The Inter Project Authors) | SIL OFL 1.1 | Typeface for the Graphite and Paper styles, included in `assets/fonts/inter/` (with its `OFL.txt`). |
| [Newsreader](https://github.com/productiontype/Newsreader) (Production Type) | SIL OFL 1.1 | Titles in the Paper style, included in `assets/fonts/newsreader/` (with its `OFL.txt`). |
| [window_manager](https://pub.dev/packages/window_manager) (LeanFlutter) | MIT | PC: closing the window in order, minimum size and hiding it in the tray. |
| [tray_manager](https://pub.dev/packages/tray_manager) (LeanFlutter) | MIT | PC: Kiji's icon and menu in the system tray. |
| [hotkey_manager](https://pub.dev/packages/hotkey_manager) (LeanFlutter) | MIT | PC: global keyboard shortcuts (play/pause, next, previous). |
| [media_kit](https://github.com/media-kit/media-kit) and media_kit_video (Hitesh Kumar Saini) | MIT | PC: playback with mpv and the video of your own background. |
| [libmpv](https://mpv.io) (build from [media-kit/libmpv-win32-video-build](https://github.com/media-kit/libmpv-win32-video-build)) | GPL-2.0 or later / LGPL | PC: the audio and video engine (includes FFmpeg). |
| [ANGLE](https://chromium.googlesource.com/angle/angle) (`libGLESv2.dll`, `libEGL.dll`) | BSD-3-Clause | PC: draws the background video (comes with media_kit). |
| [video_player](https://pub.dev/packages/video_player) (Flutter) | BSD-3-Clause | Phone: the video of your own background. |

## How to maintain this file

This is the English version of `CREDITS.md`. Every time code from another project is ported or
adapted:
1. Add or update the matching row in `CREDITS.md` and in this file.
2. Put a header in the Kiji file stating the project, the license and the original file.

## Notice

Kiji does not host or distribute copyrighted content. It connects to public services anonymously.
Each person is responsible for using it in accordance with the laws of their country and the terms
of the services they access. Kiji is not a Google or YouTube product, nor is it affiliated with them.
