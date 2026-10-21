# El extractor de Kiji · Kiji's extractor

**Español** · [English](#english)

## Español

El "extractor" es la parte de Kiji que consigue la URL del audio de una canción de YouTube Music,
sin cuenta y sin claves. YouTube cambia cosas seguido; esta guía explica cómo funciona, qué se
rompe y cómo arreglarlo sin ayuda.

### Cómo funciona

Hay **tres motores**. Todos devuelven lo mismo (`ResolvedStream`: URL, headers, tamaño) o una
falla clasificada (de la *forma* o de la *canción*). Los prueba `StreamResolver`
(`lib/features/extractor/data/stream_resolver.dart`) en este orden:

| Motor | Dónde | Qué es |
|---|---|---|
| **A · InnerTubeX** | Solo Android | La librería de Metrolist (`innertubex-android`, en `android/app/build.gradle.kts`), por el canal `kiji/innertubex` (`android/app/src/main/kotlin/io/github/kijiplayer/kiji/extractor/`). |
| **B · Kiji** | Todas las plataformas | Extractor propio en Dart: `lib/features/yt_music/data/ytm_client.dart`. |
| **C · yt-dlp** | Solo PC, si el usuario lo acepta | Baja el ejecutable oficial, verifica su `SHA2-256SUMS` y lo usa como último recurso (`ytdlp_engine.dart`). |

**El motor B, paso a paso:**

1. **visitorData:** pide un identificador anónimo de visitante a
   `https://music.youtube.com/sw.js_data` y lo manda en `X-Goog-Visitor-Id`. Si YouTube responde
   `400 Precondition check failed`, el visitorData venía fallado: se pide otro y se reintenta.
2. **Formas ("clientes"):** pide `/player` haciéndose pasar por distintas apps de YouTube, en el
   orden de `ytPlayerClients` (`lib/features/yt_music/data/yt_clients.dart`). Cada forma tiene su
   nombre, versión, `User-Agent` y requisitos:
   - **Sin cifrado (las mejores):** `VISIONOS` da URLs directas y completas.
   - **`needsPlayerScript`:** los formatos vienen cifrados. Hay que bajar el reproductor de
     YouTube (`base.js`, `player_script.dart`), sacar su `signatureTimestamp` y descifrar la firma
     y el parámetro `n` con el **solver de yt-dlp/ejs** (`assets/solver/`). El solver corre dentro
     de un Web Worker en una WebView (`webview_ejs_solver.dart`).
   - **`usesPoToken`:** necesita un *PO token* generado con BotGuard en otra WebView
     (`po_token.dart`). Sin él, YouTube solo deja bajar el primer minuto.
   - **`retired`:** formas que hoy no sirven. Quedan en la lista, con el motivo, por si YouTube las
     vuelve a habilitar.
3. **Último byte:** antes de usar una URL, Kiji pide el **último byte** del archivo. Así se
   detectan las formas que cortan en ~1 MiB (el "recorte de 60 segundos").
4. **A mitad de canción:** si el reproductor recibe un 403, se reintenta con la forma siguiente
   desde el mismo segundo.
5. **Tabla de reproductores:** `assets/solver/player_configs.json` (la de Echo/Metrolist), con
   actualización remota cada 6 h (`RemotePlayerConfigs`), da el `signatureTimestamp` sin tener que
   bajar el reproductor.

**Salud del Extractor** (`path_health.dart`; en la app: Configuración → Privacidad → Salud del
Extractor): anota cada éxito y cada falla *de la forma* (las de la canción, como la restricción de
edad, no cuentan) y reordena las formas según los éxitos recientes. Las **pruebas automáticas**
(`extractor_tester.dart`) usan tres canciones de control públicas y nunca nada del usuario.

**Canciones que no se pueden** (edad, bloqueo regional): `alternatives.dart` busca la versión
"Canción" del mismo tema y lo recuerda en `alternatives.json`.

### Qué se rompe cuando YouTube cambia algo

| Síntoma | Causa probable | Dónde arreglarlo |
|---|---|---|
| `400 Precondition check failed` en todas las formas | La versión del cliente quedó vieja o el visitorData no sirve | Versión de la forma en `yt_clients.dart` (copiar la de Echo/Metrolist/yt-dlp); `_visitorData` en `ytm_client.dart` |
| `UNPLAYABLE` / "LOGIN_REQUIRED" / "Sign in to confirm you're not a bot" | YouTube endureció esa forma (o bloquea la IP, en servidores) | Probar otra forma; si es general, actualizar versiones; retirar la forma con su motivo |
| La canción corta al minuto (~1 MiB) | La forma necesita PO token o ya no da el archivo entero | `usesPoToken` en la forma; si sigue, `retired:` |
| `403` al bajar el audio | Falta transformar `n` o la firma | Solver: actualizar `assets/solver/` con la última versión de yt-dlp/ejs, sin modificar los `.js` |
| "No se encontró el reproductor" / `signatureTimestamp` vacío | Cambió `iframe_api` o el formato de `base.js` | Regex de `player_script.dart`; tabla `player_configs.json` |
| La búsqueda no devuelve nada | Cambió la forma del JSON de `search` | `ytm_browse_parser.dart` (es recursivo: suele bastar un nombre de campo nuevo) |
| Falla solo en Android | InnerTubeX quedó viejo | Versión de `innertubex-android` en `android/app/build.gradle.kts` (Metrolist publica seguido) |

### Diagnóstico paso a paso

1. **¿Falla para todos o solo en tu equipo?** Mira la [prueba diaria del
   extractor](../.github/workflows/extractor.yml) en la pestaña Actions de GitHub. Si falla, abre
   sola un issue con la tabla de formas. Puedes correrla a mano: Actions → "Prueba diaria del
   extractor" → *Run workflow*.
2. **Correr la prueba en vivo en tu PC:**
   `flutter test test_live/extractor_live_test.dart`. Deja un resumen en
   `build/extractor_live.md`: búsqueda y audio, forma por forma, con el motivo exacto.
3. **En la app (Kiji Dev):** Configuración → Kiji Dev → herramientas: registro en vivo, prueba de
   una canción y de cada forma, y Salud del Extractor ("Probar ahora"). El registro guarda líneas
   `=== YTM ... ===` y `=== SALUD ... ===` con el código HTTP y el motivo.
4. **Lee el motivo, no el síntoma:** `400` (versión o visitorData), `403` (cifrado o PO token),
   `UNPLAYABLE` (la forma ya no sirve), corte al minuto (PO token), error de red (no es YouTube).
5. **Compara con los proyectos de referencia** (GPL-3.0, se puede portar su código):
   [Echo Music](https://github.com/EchoMusicApp/Echo-Music) (`innertube/.../YouTubeClient.kt`,
   `utils/YTPlayerUtils.kt`, `utils/cipher/`), [Metrolist](https://github.com/MetrolistGroup/Metrolist)
   e InnerTubeX, y [yt-dlp](https://github.com/yt-dlp/yt-dlp) (`yt_dlp/extractor/youtube/`). Si
   ellos ya cambiaron una versión o el orden de las formas, copia el cambio y acredítalo
   (encabezado del archivo y `CREDITS.md`).
6. **Arregla una cosa por vez** y vuelve a correr la prueba en vivo. Después, `flutter analyze` y
   `flutter test`.

### Arreglos frecuentes

- **Subir la versión de una forma:** en `yt_clients.dart`, cambia `version` (y el `User-Agent`
  si lo tiene) por la que usa hoy Echo/Metrolist/yt-dlp.
- **Retirar una forma:** ponle `retired: tx.<motivo>` (el texto va en `lib/l10n/app_es.arb` y
  `app_en.arb`). Queda visible en "Formas retiradas" y fuera de la cadena automática.
- **Cambiar el orden:** el orden de `ytPlayerClients` es el de arranque; la Salud lo ajusta sola
  con los éxitos.
- **Actualizar el solver:** reemplaza los `.js` de `assets/solver/` por los de la última
  release de [yt-dlp/ejs](https://github.com/yt-dlp/ejs), **sin modificarlos**, y actualiza
  `assets/solver/LICENSES.md`.
- **Actualizar InnerTubeX:** sube la versión en `android/app/build.gradle.kts`, compila
  `flutter build apk --debug --flavor dev` y prueba en un celular con Kiji Dev.

---

## English

The "extractor" is the part of Kiji that gets the audio URL of a YouTube Music song, with no
account and no keys. YouTube changes things often; this guide explains how it works, what breaks
and how to fix it on your own.

### How it works

There are **three engines**. All of them return the same thing (`ResolvedStream`: URL, headers,
size) or a classified failure (of the *form* or of the *song*). `StreamResolver`
(`lib/features/extractor/data/stream_resolver.dart`) tries them in this order:

| Engine | Where | What it is |
|---|---|---|
| **A · InnerTubeX** | Android only | Metrolist's library (`innertubex-android`, in `android/app/build.gradle.kts`), through the `kiji/innertubex` channel (`android/app/src/main/kotlin/io/github/kijiplayer/kiji/extractor/`). |
| **B · Kiji** | All platforms | Kiji's own Dart extractor: `lib/features/yt_music/data/ytm_client.dart`. |
| **C · yt-dlp** | PC only, if the user accepts it | Downloads the official binary, checks its `SHA2-256SUMS` and uses it as a last resort (`ytdlp_engine.dart`). |

**Engine B, step by step:**

1. **visitorData:** asks `https://music.youtube.com/sw.js_data` for an anonymous visitor id and
   sends it as `X-Goog-Visitor-Id`. If YouTube answers `400 Precondition check failed`, that
   visitorData was bad: Kiji asks for a new one and retries.
2. **Forms ("clients"):** calls `/player` pretending to be different YouTube apps, in the order of
   `ytPlayerClients` (`lib/features/yt_music/data/yt_clients.dart`). Each form has its name,
   version, `User-Agent` and requirements:
   - **No cipher (the best ones):** `VISIONOS` gives direct, complete URLs.
   - **`needsPlayerScript`:** formats come encrypted. Kiji downloads YouTube's player (`base.js`,
     `player_script.dart`), reads its `signatureTimestamp` and deciphers the signature and the
     `n` parameter with the **yt-dlp/ejs solver** (`assets/solver/`). The solver runs inside a
     Web Worker in a WebView (`webview_ejs_solver.dart`).
   - **`usesPoToken`:** needs a *PO token* generated with BotGuard in another WebView
     (`po_token.dart`). Without it, YouTube only serves the first minute.
   - **`retired`:** forms that don't work today. They stay in the list, with the reason, in case
     YouTube enables them again.
3. **Last byte:** before using a URL, Kiji requests the **last byte** of the file. This catches
   forms that stop at ~1 MiB (the "60-second cut").
4. **Mid-song:** if the player gets a 403, Kiji retries with the next form from the same second.
5. **Player table:** `assets/solver/player_configs.json` (Echo/Metrolist's), refreshed remotely
   every 6 h (`RemotePlayerConfigs`), gives the `signatureTimestamp` without downloading the player.

**Extractor Health** (`path_health.dart`; in the app: Settings → Privacy → Extractor Health)
records every success and every failure *of the form* (song problems, like age restriction, don't
count) and reorders the forms by recent successes. The **automatic tests**
(`extractor_tester.dart`) use three public control songs and never anything from the user.

**Songs that can't be played** (age, region): `alternatives.dart` looks for the "Song" version of
the same track and remembers it in `alternatives.json`.

### What breaks when YouTube changes something

| Symptom | Likely cause | Where to fix it |
|---|---|---|
| `400 Precondition check failed` on every form | The client version is outdated or the visitorData is bad | Form version in `yt_clients.dart` (copy Echo/Metrolist/yt-dlp's); `_visitorData` in `ytm_client.dart` |
| `UNPLAYABLE` / "LOGIN_REQUIRED" / "Sign in to confirm you're not a bot" | YouTube hardened that form (or blocks the IP, on servers) | Try another form; if it's everywhere, update versions; retire the form with its reason |
| The song stops after a minute (~1 MiB) | The form needs a PO token or no longer serves the whole file | `usesPoToken` on the form; if it persists, `retired:` |
| `403` when downloading the audio | `n` or the signature isn't transformed | Solver: update `assets/solver/` with the latest yt-dlp/ejs, without modifying the `.js` |
| "Player not found" / empty `signatureTimestamp` | `iframe_api` or the `base.js` format changed | Regexes in `player_script.dart`; `player_configs.json` table |
| Search returns nothing | The `search` JSON shape changed | `ytm_browse_parser.dart` (it's recursive: usually a new field name is enough) |
| Fails only on Android | InnerTubeX is outdated | `innertubex-android` version in `android/app/build.gradle.kts` (Metrolist releases often) |

### Step-by-step diagnosis

1. **Does it fail for everyone or only for you?** Check the [daily extractor
   test](../.github/workflows/extractor.yml) in GitHub's Actions tab. When it fails, it opens an
   issue with the per-form table. You can run it by hand: Actions → "Prueba diaria del extractor"
   → *Run workflow*.
2. **Run the live test on your PC:** `flutter test test_live/extractor_live_test.dart`. It writes
   a summary to `build/extractor_live.md`: search and audio, form by form, with the exact reason.
3. **In the app (Kiji Dev):** Settings → Kiji Dev → tools: live log, test one song and each form,
   and Extractor Health ("Test now"). The log keeps `=== YTM ... ===` and `=== SALUD ... ===`
   lines with the HTTP code and the reason.
4. **Read the reason, not the symptom:** `400` (version or visitorData), `403` (cipher or PO
   token), `UNPLAYABLE` (the form no longer works), one-minute cut (PO token), network error (not
   YouTube).
5. **Compare with the reference projects** (GPL-3.0, their code can be ported):
   [Echo Music](https://github.com/EchoMusicApp/Echo-Music) (`innertube/.../YouTubeClient.kt`,
   `utils/YTPlayerUtils.kt`, `utils/cipher/`), [Metrolist](https://github.com/MetrolistGroup/Metrolist)
   and InnerTubeX, and [yt-dlp](https://github.com/yt-dlp/yt-dlp) (`yt_dlp/extractor/youtube/`).
   If they already changed a version or the order of forms, copy the change and credit it (file
   header and `CREDITS.md`).
6. **Fix one thing at a time** and run the live test again. Then `flutter analyze` and
   `flutter test`.

### Common fixes

- **Bump a form's version:** in `yt_clients.dart`, change `version` (and the `User-Agent` if it
  has one) to what Echo/Metrolist/yt-dlp use today.
- **Retire a form:** set `retired: tx.<reason>` (the text goes in `lib/l10n/app_es.arb` and
  `app_en.arb`). It stays visible under "Retired forms" and out of the automatic chain.
- **Change the order:** the order of `ytPlayerClients` is the starting one; Health adjusts it by
  itself with the successes.
- **Update the solver:** replace the `.js` files in `assets/solver/` with the ones from the latest
  [yt-dlp/ejs](https://github.com/yt-dlp/ejs) release, **without modifying them**, and update
  `assets/solver/LICENSES.md`.
- **Update InnerTubeX:** bump the version in `android/app/build.gradle.kts`, build
  `flutter build apk --debug --flavor dev` and test on a phone with Kiji Dev.
