# Créditos

Kiji Player es software libre bajo la licencia **GNU GPL-3.0** (ver `LICENSE`).

Kiji no existiría sin el trabajo de otros proyectos de código abierto. Estudiamos su código y
reutilizamos ideas, y en algunos casos código, respetando sus licencias. Gracias a todas las
personas que los construyen y mantienen.

## Proyectos en los que nos basamos

| Proyecto | Licencia | Qué tomamos |
|---|---|---|
| [Echo Music](https://github.com/EchoMusicApp/Echo-Music) (iad1tya y colaboradores) | GPL-3.0 | Estrategia de reproducción de YouTube Music: clientes VISIONOS / ANDROID_VR con `visitorData`, flujo de descifrado de firma y del parámetro `n` en WebView, tabla de configuración de reproductores. Referencia de arquitectura e inspiración de funciones. |
| [Metrolist](https://github.com/MetrolistGroup/Metrolist) (MetrolistGroup y colaboradores) | GPL-3.0 | Base de la que parte Echo Music; referencia de arquitectura del cliente InnerTube, la generación de PO token y el diseño de funciones. |
| InnerTune (Zion Huang, Malopieds) y OuterTune (Davide Garberi, Michael Zh) | GPL-3.0 | Proyectos originales de los que descienden Metrolist y Echo Music. |

## Archivos de Kiji adaptados de otros proyectos

| Archivo de Kiji | Proyecto | Archivo original |
|---|---|---|
| `lib/features/yt_music/data/ytm_client.dart`, `yt_clients.dart` | Echo Music | `innertube/.../models/YouTubeClient.kt`, `app/src/main/kotlin/.../utils/YTPlayerUtils.kt` |
| `lib/features/yt_music/data/webview_ejs_solver.dart`, `player_script.dart` | Echo Music | `utils/sabr/EjsNTransformSolver.kt`, `utils/cipher/CipherWebView.kt`, `PlayerJsFetcher.kt`, `PlayerConfigStore.kt` |
| `lib/features/yt_music/data/po_token.dart` | Echo Music, que lo toma de NewPipe (GPL-3.0) y BgUtils (LuanRT, MIT) | `utils/potoken/PoTokenWebView.kt`, `PoTokenGenerator.kt`, `JavaScriptUtil.kt`, `assets/po_token.html` |
| `lib/features/playback_memory/data/playback_memory_store.dart` | Echo Music (idea, no código) | `core/.../models/PersistQueue.kt`, `PersistPlayerState.kt`, `MusicService.kt` (qué guardar, cuándo y borrar el guardado dañado) |
| `lib/features/downloads/data/download_service.dart`, `downloads_repository.dart` | Echo Music (idea, no código) | `playback/DownloadUtil.kt`, `ExoDownloadService.kt` (descargas dentro de la app, separadas de la caché, reanudables, opción solo WiFi) |
| `lib/features/system_media/data/audio_service_controls.dart` | Echo Music (idea, no código) | `playback/MusicService.kt`, `MediaLibrarySessionCallback.kt` (sesión multimedia, notificación y botones del sistema) |
| `lib/features/stream_cache/data/stream_cache.dart` | Echo Music (idea, no código) | `playback/DownloadUtil.kt` (`playerCache`: caché de lo escuchado, separada de las descargas, con límite) |
| `lib/features/queue/` (`queue_operations.dart`, `queue_screen.dart`, `track_actions.dart`) | Echo Music (idea, no código) | `ui/player/Queue.kt`, `ui/menu/QueueMenu.kt` (reordenar, quitar, reproducir a continuación) |
| `lib/features/account/` (`yt_session.dart`, `account_store.dart`, `account_screens.dart`) | Echo Music (idea y protocolo, no código) | `ui/screens/LoginScreen.kt` (iniciar sesión en una WebView y quedarse con las cookies de music.youtube.com), `innertube/.../InnerTube.kt` (encabezado `SAPISIDHASH`), `ui/screens/settings/AccountSettingsScreen.kt` |
| `lib/widgets/nocturne/glass.dart` | Echo Music (idea, no código) | `ui/component/GlassEffect.kt` y carpeta `backdrop/` (superficies de vidrio) |
| `lib/features/settings/` (`settings_store.dart`, `setting_search.dart`, `settings_screen.dart`) | Echo Music (idea, no código) | `constants/PreferenceKeys.kt`, `ui/screens/settings/`, `SearchableSettings.kt` (secciones y buscador de opciones) |
| `lib/features/sleep_timer/` (`sleep_timer_logic.dart`) | Echo Music (idea, no código) | `playback/SleepTimer.kt` (temporizador por minutos y al terminar la canción) |
| `lib/features/lyrics/` (`lyrics.dart`, `lrclib_client.dart`, `lyrics_repository.dart`, `lyrics_screen.dart`) | Echo Music (idea, no código) | `lyrics/LrcLibLyricsProvider.kt`, `LyricsHelper.kt`, `LyricsUtils.kt`, `ui/component/LyricsV2.kt` |
| `lib/features/playlists/` (`playlist.dart`, `smart_lists.dart`, `playlist_screens.dart`) | Echo Music (idea, no código) | `ui/screens/playlist/LocalPlaylistScreen.kt`, `AutoPlaylistScreen.kt` |
| `lib/features/import/data/import_parsers.dart` | Echo Music (estructura del formato, no código) | `viewmodels/BackupRestoreViewModel.kt`, `ui/screens/settings/BackupAndRestore.kt`, `core/.../db/entities/` (tablas song, artist, playlist, event) |
| `lib/features/backup/` (`backup_manifest.dart`, `backup_screen.dart`) | Echo Music (idea, no código) | `ui/screens/settings/BackupAndRestore.kt`, `viewmodels/BackupRestoreViewModel.kt` (copia en un archivo y restaurar) |
| `lib/features/equalizer/` (`equalizer_model.dart`, `equalizer_screen.dart`) | Echo Music (idea, no código) | `ui/screens/equalizer/EqScreen.kt`, `EQViewModel.kt`, `dsp-core/.../models/SavedEQProfile.kt` (perfiles guardados y uno activo) |
| `lib/features/playback_extras/` (`playback_rules.dart`) | Echo Music (idea, no código) | `playback/crossfade/EqualPowerCurve.kt` (curva de potencia constante), `playback/MusicService.kt` (PauseOnMute, ResumeOnBluetoothConnect) |
| `android/.../extractor/InnerTubeXEngine.kt` | Echo Music 1.4.3 (GPL-3.0) | `utils/InnerTubeXResolver.kt` (motor A: exclusión por canción, precalentamiento, config remota) |
| `android/.../extractor/PoTokenWebView.kt`, `PoTokenGenerator.kt`, `JavaScriptUtil.kt`, `PoTokenException.kt`, `assets/po_token.html` | Echo Music 1.4.3, que a su vez viene de NewPipe (GPL-3.0) | `utils/potoken/*` (PO token BotGuard en una WebView). Kiji corrigió la vinculación: el token de la URL va ligado al video |
| `lib/features/stream_cache/data/chunked_source.dart` | Echo Music (idea, código propio) | `playback/ChunkedDataSource.kt` (rangos acotados y URL renovada) |

## Servicios que usa Kiji (solo cuando el usuario lo pide)

| Servicio | Para qué | Qué se envía |
|---|---|---|
| [LRCLIB](https://lrclib.net) | Letras sincronizadas (libres, sin cuenta) | Título, artista, álbum y duración, al tocar "Letra". |
| [YouLyPlus / LyricsPlus](https://github.com/ibratabian17/YouLyPlus) (servidores comunitarios `lyricsplus.*`, `lyrics-plus-backend.vercel.app`) | Letras palabra por palabra | Título, artista, álbum, duración e id del video, solo si las anteriores no la tienen. |
| [PaxSenix](https://lyrics.paxsenix.org) | Letras sincronizadas | Título y artista. |
| [Unison](https://unison.boidu.dev) (de Better Lyrics) | Letras sincronizadas aportadas por la comunidad | Id del video, o título, artista y duración. |
| [Better Lyrics](https://better-lyrics.boidu.dev) (`lyrics-api.boidu.dev`) | Letras sincronizadas | Título, artista, álbum y duración. |
| [KuGou](https://www.kugou.com) | Letras sincronizadas (catálogo grande en asiático) | Título, artista y duración. |
| YouTube (subtítulos) | Letra desde los subtítulos del video | Id del video. |
| [YouTube Music](https://music.youtube.com) | Letra sin sincronizar de la pestaña "Letra" | Id del video. |
| [Mozilla Remote Settings](https://firefox.settings.services.mozilla.com) | Bajar una sola vez el motor y el modelo de un idioma para traducir en el teléfono | Nada de la canción: solo qué archivos de idioma se bajan. |
| [zemer-cipher](https://github.com/ZemerTeam/zemer-cipher) (GitHub) | Tabla `player_configs.json` para descifrar el audio (motores A y B), como mucho cada 6 h | Nada tuyo: GitHub ve una consulta a un archivo público. |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) (releases de GitHub, solo PC y a pedido) | Motor C de extracción, si el usuario lo acepta | Se baja el programa oficial y se verifica su huella; después le pide a YouTube el audio de la canción, como Kiji. |
| [Google Gemini API](https://ai.google.dev) (opcional, apagado de fábrica) | Traducir letras con IA, con la clave del propio usuario | Solo las líneas de la letra y el idioma de destino, con la clave del usuario (cifrada en el dispositivo). |
| [song.link / Odesli](https://odesli.co) | Enlace universal al compartir una canción | Nada desde Kiji: solo se arma el enlace con el id del video; lo abre quien lo recibe. |

## Componentes de terceros usados tal cual

| Componente | Licencia | Uso |
|---|---|---|
| [yt-dlp/ejs](https://github.com/yt-dlp/ejs) 0.8.0 (`yt.solver.core.js`, `yt.solver.lib.js`) | Unlicense | Solver de firma y del parámetro `n` del reproductor de YouTube (en `assets/solver/`, con `LICENSES.md`). |
| [meriyah](https://github.com/meriyah/meriyah) 6.1.4 (dentro de `yt.solver.lib.js`) | ISC | Parser de JavaScript que usa el solver. |
| [astring](https://github.com/davidbonnet/astring) 1.9.0 (dentro de `yt.solver.lib.js`) | MIT | Generador de código JavaScript que usa el solver. |
| `player_configs.json` de Echo Music | GPL-3.0 | Tabla de reproductores verificados por hash (Kiji usa el `sts`). |
| [crop_your_image](https://pub.dev/packages/crop_your_image) | Apache 2.0 | Recorte de fotos personalizadas. |
| [image](https://pub.dev/packages/image) | MIT | Achicar las fotos personalizadas a 800 px. |
| [Space Grotesk](https://github.com/floriankarsten/space-grotesk) (Florian Karsten) | SIL OFL 1.1 | Tipografía de títulos, incluida en `assets/fonts/space_grotesk/` (con su `OFL.txt`). |
| [bergamot-translator](https://github.com/mozilla/bergamot-translator) (motor WebAssembly, versión 3.0 de Firefox) | MPL-2.0 | Traducción en el teléfono. Se baja de los servidores de Mozilla; no viene en la app. |
| `bergamot-translator.js` de [Firefox](https://searchfox.org/mozilla-central/source/toolkit/components/translations/bergamot-translator) | MPL-2.0 | Pegamento JavaScript del motor, sin cambios, en `assets/translation/`. |
| [Modelos de Firefox Translations](https://github.com/mozilla/firefox-translations-models) (Mozilla) | MPL-2.0 | Un modelo por par de idiomas; se bajan solo cuando el usuario elige traducir y se pueden borrar. |
| [url_launcher](https://pub.dev/packages/url_launcher) | BSD-3-Clause | Abrir páginas en el navegador (guía de Gemini). |
| [InnerTubeX](https://github.com/MetrolistGroup/innertubex) v0.10.0 (MetrolistGroup) | GPL-3.0 | Motor A de extracción en Android, desde JitPack. |
| [quickjs-kt](https://github.com/dokar3/quickjs-kt) (dentro de InnerTubeX) | Apache-2.0 | Motor JavaScript para descifrar en Android. |
| [Ktor](https://ktor.io), [OkHttp](https://square.github.io/okhttp/), [kotlinx.coroutines](https://github.com/Kotlin/kotlinx.coroutines) | Apache-2.0 | Red y concurrencia del motor A. |
| [WorkManager](https://developer.android.com/jetpack/androidx/releases/work) (AndroidX) | Apache-2.0 | Prueba diaria del extractor (solo WiFi y batería no baja). |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | Unlicense | Motor C (solo PC, opcional): no viene en la app; se baja si el usuario lo pide. |
| [flutter_svg](https://pub.dev/packages/flutter_svg) | MIT | Mostrar el logo (`assets/branding/kiji_logo.svg`) dentro de la app. |
| [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) (solo para desarrollo) | MIT | Generar el ícono adaptable de Android y el `.ico` de Windows desde el logo. |
| [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono) (JetBrains) | SIL OFL 1.1 | Tipografía de tiempos y números, incluida en `assets/fonts/jetbrains_mono/` (con su `OFL.txt`). |
| [window_manager](https://pub.dev/packages/window_manager) (LeanFlutter) | MIT | PC: cerrar la ventana en orden, tamaño mínimo y ocultarla en la bandeja. |
| [tray_manager](https://pub.dev/packages/tray_manager) (LeanFlutter) | MIT | PC: ícono y menú de Kiji en la bandeja del sistema. |
| [hotkey_manager](https://pub.dev/packages/hotkey_manager) (LeanFlutter) | MIT | PC: atajos de teclado globales (play/pausa, siguiente, anterior). |

## Cómo mantener este archivo

Cada vez que se porte o adapte código de otro proyecto:
1. Agregá o actualizá la fila correspondiente en este archivo.
2. Poné un encabezado en el archivo de Kiji que indique el proyecto, la licencia y el archivo original.

## Aviso

Kiji no aloja ni distribuye contenido protegido por derechos de autor. Se conecta a servicios
públicos de forma anónima. Cada persona es responsable de usarlo de acuerdo con las leyes de su
país y los términos de los servicios a los que accede. Kiji no es un producto de Google ni de
YouTube, ni está afiliado a ellos.
