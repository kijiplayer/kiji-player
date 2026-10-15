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
| `lib/features/yt_music/data/ytm_client.dart` | Echo Music | `innertube/.../models/YouTubeClient.kt`, `app/src/main/kotlin/.../utils/YTPlayerUtils.kt` |
| `lib/features/playback_memory/data/playback_memory_store.dart` | Echo Music (idea, no código) | `core/.../models/PersistQueue.kt`, `PersistPlayerState.kt`, `MusicService.kt` (qué guardar, cuándo y borrar el guardado dañado) |
| `lib/features/downloads/data/download_service.dart`, `downloads_repository.dart` | Echo Music (idea, no código) | `playback/DownloadUtil.kt`, `ExoDownloadService.kt` (descargas dentro de la app, separadas de la caché, reanudables, opción solo WiFi) |

## Componentes de terceros usados tal cual

| Componente | Licencia | Uso |
|---|---|---|
| [yt-dlp/ejs](https://github.com/yt-dlp/ejs) (`yt.solver.core.js`) | Unlicense | Solver de firma y del parámetro `n` del reproductor de YouTube. |
| [meriyah](https://github.com/meriyah/meriyah) | ISC | Parser de JavaScript que usa el solver. |
| [astring](https://github.com/davidbonnet/astring) | MIT | Generador de código JavaScript que usa el solver. |

## Cómo mantener este archivo

Cada vez que se porte o adapte código de otro proyecto:
1. Agregá o actualizá la fila correspondiente en este archivo.
2. Poné un encabezado en el archivo de Kiji que indique el proyecto, la licencia y el archivo original.

## Aviso

Kiji no aloja ni distribuye contenido protegido por derechos de autor. Se conecta a servicios
públicos de forma anónima. Cada persona es responsable de usarlo de acuerdo con las leyes de su
país y los términos de los servicios a los que accede. Kiji no es un producto de Google ni de
YouTube, ni está afiliado a ellos.
