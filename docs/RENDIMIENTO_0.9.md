# Rendimiento de Kiji 0.9 — antes y después

Medido el 27/11/2026 con compilaciones *profile*. «Antes» es `release/0.9` antes de estos cambios;
«después» incluye este PR y el vidrio líquido con shader (#37).

- **Teléfono:** Motorola Edge 50 Fusion, Android 16, Impeller (Vulkan), pantalla a 120 Hz.
- **PC:** Windows 11, AMD Radeon 760M, ventana de 1280×720.
- Cuadros: el medidor de Kiji (`FrameStats`), mediana / p90 en ms, en ventanas de 3 s mientras se
  desliza la lista. «Dibujo» = *raster*; «armado» = *build*.
- CPU: % de un núcleo, promedio de 10 s. Memoria: Android PSS total; Windows memoria privada.

## Qué se cambió (sin cambiar cómo se ve ni cómo funciona)

1. **Windows dibuja con Skia** (`windows/runner/main.cpp`, `set_impeller_switch(Disabled)`). En esta
   versión de Flutter, Windows usa Impeller sobre OpenGL ES (ANGLE) de fábrica. El perfil del motor
   mostró que casi todo el tiempo de cada cuadro se iba en codificar comandos de GL
   (`RenderPassGLES::EncodeCommandsInReactor`): ~20 ms por cuadro con la pantalla casi quieta.
   Con Skia, el mismo cuadro tarda ~4 ms. Capturas comparadas: se ve igual.
2. **Miniaturas decodificadas a su tamaño** (`lib/utils/image_decode.dart`). En Búsqueda, en las
   tarjetas de Inicio y en las colecciones de YouTube Music, las imágenes de red se decodificaban a
   resolución completa para verse en 44–140 px. Ahora se decodifican al tamaño en pantalla.
3. `--dart-define=KIJI_FRAME_STATS=true` prende el medidor de cuadros fuera de Kiji Dev (para medir en la PC).

## Windows

| | Antes | Después |
|---|---|---|
| Arranque: ventana visible | 1,75–2,5 s | 0,68–0,89 s |
| Arranque: primer cuadro (desde Dart) | 183–222 ms | 189–235 ms |
| Inicio deslizando: dibujo por cuadro | 20,5–21,2 ms (p90 24) | 4,2 ms (p90 5,3) |
| Búsqueda deslizando: dibujo por cuadro | 24,0–24,5 ms (p90 27–28) | 4,5–5,2 ms (p90 5,3–6,4) |
| Cuadros de más de 16 ms (Inicio, 3 s) | 89–99 de 89–99 | 0–2 |
| Memoria privada, quieta | 692 MB | 294 MB |
| Memoria privada, sonando | 799 MB | 392 MB |
| CPU quieta | 1,4 % | 0 % |
| CPU sonando (Inicio a la vista) | 157 % | 45 % |

## Android (teléfono)

| | Antes | Después |
|---|---|---|
| Arranque en frío (`am start -W`) | 1102–1127 ms | 990–1182 ms |
| Arranque en caliente | 77–97 ms | 70–87 ms |
| Inicio deslizando | 2,4 ms (p90 2,7) | 2,4 ms (p90 2,8) |
| Biblioteca (Me gusta) deslizando | 2,1 ms (p90 2,4) | 2,2 ms (p90 2,4) |
| Búsqueda: al aparecer los resultados | 11 cuadros > 16 ms, p90 9,2 ms | 1 cuadro > 16 ms, p90 3,6 ms |
| Búsqueda deslizando | 2,5 ms (p90 2,9) | 2,7 ms (p90 3,0) |
| Memoria (PSS), quieta / sonando | 254 / 272 MB | 252 / 261 MB |
| CPU quieta | 0,3 % | 0,6 % |
| CPU sonando, reproductor a la vista | 77 % | 79 % |

En Android ya iba bien (2–3 ms por cuadro a 120 Hz): el cambio que se nota es el de Búsqueda.

## Observaciones (no se tocaron)

- **Arranque en frío en Android (~1,1 s):** Dart dibuja el primer cuadro a los ~180 ms. El resto pasa
  antes: inicio del proceso y registro de unos 40 plugins nativos (Android avisa «Skipped 32 frames»,
  ~270 ms del hilo principal). Para saber cuál pesa más hace falta un trazado del sistema (perfetto).
- **CPU sonando con el reproductor a la vista (~77 %):** el reproductor se redibuja 120 veces por
  segundo por sus animaciones (onda en vivo, anillo, deriva de la portada en Grafito). Con Inicio a
  la vista, sonando, baja a ~28 %. Bajarlo cambiaría cómo se ve (menos cuadros por segundo).
- **Dos reproductores de audio:** en una medición larga aparecieron dos hilos de ExoPlayer
  decodificando (uno sin sonar). No se pudo reproducir desde un arranque limpio ni con la mezcla
  entre canciones; queda para investigar con más uso.
- **Letras:** la medición de «después» tomó una canción sin letra sincronizada (pantalla quieta);
  no es comparable con la de «antes» (365 cuadros por 3 s, 2,6 ms).
