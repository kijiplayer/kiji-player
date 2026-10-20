<p align="center">
  <a href="README.md">English</a> | <b>Español</b>
</p>

<p align="center">
  <img src="assets/branding/kiji_logo.svg" width="112" height="112" alt="Logo de Kiji Player">
</p>

<h1 align="center">Kiji Player</h1>

<p align="center">
  Un reproductor de música libre para Android y Windows.<br>
  Sin anuncios, sin pagos y sin rastreo.
</p>

---

Kiji reproduce tu música guardada y la de YouTube Music, de forma anónima. Todo lo tuyo (la cola,
las playlists, el historial y las descargas) se queda en tu dispositivo.

- Descargas para escuchar sin conexión, de una canción o de playlists enteras.
- Letras sincronizadas, con traducción en el propio teléfono.
- Inicio con recomendaciones calculadas en tu dispositivo.
- Temporizador para dormir, ecualizador, transición suave entre canciones y copia de seguridad.
- Importa playlists desde Echo Music, Metrolist, `.m3u` y otros formatos.
- En español e inglés.

## Capturas

<p align="center">
  <img src="docs/capturas/reproductor_es.png" width="180" alt="Reproductor">
  <img src="docs/capturas/inicio_es.png" width="180" alt="Inicio">
  <img src="docs/capturas/letras_es.png" width="180" alt="Letra sincronizada">
</p>
<p align="center">
  <img src="docs/capturas/biblioteca_es.png" width="180" alt="Biblioteca">
  <img src="docs/capturas/bienvenida_es.png" width="180" alt="Bienvenida">
</p>

<p align="center"><sub>Las canciones, artistas, portadas y letras de las capturas son inventadas.</sub></p>

## Instalación

Las versiones se publican en [Releases](https://github.com/kijiplayer/kiji-player/releases). Kiji
funciona en Android 7 o más nuevo y en Windows 10/11.

<p>
  <a href="https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/kijiplayer/kiji-player"><img src="https://raw.githubusercontent.com/ImranR98/Obtainium/main/assets/graphics/badge_obtainium.png" alt="Consíguelo en Obtainium" height="54"></a>
</p>

Con Obtainium, Kiji se actualiza en Android directamente desde esas versiones.

Para compilarlo tú mismo necesitas [Flutter](https://flutter.dev) 3.47 o más nuevo:

```bash
flutter pub get
flutter build apk --flavor prod   # Android
flutter build windows             # Windows
```

El APK de Android se puede volver a compilar y comparar con el publicado: ver
[docs/REPRODUCIBLE_BUILDS.md](docs/REPRODUCIBLE_BUILDS.md).

## Licencia y créditos

Kiji es software libre bajo la licencia [GNU GPL-3.0](LICENSE).

Se basa en el trabajo de [Echo Music](https://github.com/EchoMusicApp/Echo-Music) y
[Metrolist](https://github.com/MetrolistGroup/Metrolist), dos reproductores libres para Android, y
de los proyectos de los que ellos descienden. La lista completa, con qué se tomó de cada uno, está
en [CREDITS.md](CREDITS.md).

Kiji se programa con ayuda de inteligencia artificial, y cada cambio lo revisa y aprueba una persona.

Kiji es un proyecto independiente, compatible con YouTube Music. No está afiliado ni respaldado por
Google ni YouTube.
