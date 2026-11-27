# Vidrio líquido real (liquid_glass_renderer) — medición y decisión

Rama `vidrio-liquido`. **No entra en la 0.9**: no cumple los 8,3 ms por cuadro (120 Hz).

## Qué se hizo
- `liquid_glass_renderer` 1.0.0-dev.3 (Apache-2.0), versión fija. Flutter GPU activado en el manifiesto.
- `RealGlass` (`lib/widgets/nocturne/real_glass.dart`): solo Android con Impeller; carga los shaders
  después del primer cuadro; si falla, vuelve al vidrio de siempre. Interruptor en Apariencia.
- Encima del vidrio real se dibuja el mismo borde de luz del vidrio de siempre (el diseño no cambia).

## Mediciones (Motorola Edge 50 Fusion, Android 16, Impeller Vulkan, 120 Hz, Kiji Dev profile)
`raster` = dibujo de cada cuadro, mediana (p90). Inicio y Búsqueda deslizando; reproductor sonando.

| Variante | Inicio | Búsqueda | Reproductor |
|---|---|---|---|
| Vidrio de siempre | 2,3 ms (2,5) | 2,6 ms (2,9) | 2,2 ms (2,8) |
| Real en todo el vidrio | 18–21 ms (26) | ~18 ms (19–20) | 2,2 ms (2,7) |
| Real solo en lo flotante (barra, mini-reproductor, hojas) | 17,4 ms (19) | 18 ms (20–22) | 2,3 ms (2,8) |
| Real solo flotante, sin desenfoque, sin arcoíris, sin sombras | 8,9 ms (10) | 9,6 ms (10,7) | — |

Cada capa del paquete copia la pantalla entera y la procesa con la GPU: en este Adreno, una sola
capa con el diseño pedido ya cuesta ~15 ms. Emulador Android 14 (Impeller GLES): carga bien.

## Para retomarlo
Volver a medir cuando el paquete salga de prelanzamiento o Flutter GPU deje de estar en vista previa.
