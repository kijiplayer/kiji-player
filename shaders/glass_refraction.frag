// Vidrio líquido de Kiji (0.9): refracción real en el borde del vidrio, sobre el fondo de Kiji.
//
// No copia la pantalla: lee la imagen del fondo que la pantalla ya publicó UNA vez, desenfocada
// (GlassBackdrop). El vidrio es una cara plana con un bisel redondeado en el borde: solo el bisel
// desvía la luz, en un cuarto de círculo (más cerca del filo, más desvío), y cada color se desvía
// distinto (dispersión: el arcoíris del borde).
#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;        // tamaño del vidrio (px lógicos)
uniform vec2 uOffset;      // esquina del vidrio en el lienzo local
uniform vec2 uGlobal;      // esquina del vidrio en la pantalla
uniform vec4 uLayer;       // dónde está la imagen del fondo en la pantalla: izq, arriba, ancho, alto
uniform float uRadius;     // radio de las esquinas
uniform float uBevel;      // ancho del bisel
uniform float uAmount;     // cuánto se desvía en el filo (px)
uniform float uDispersion; // separación de colores en el borde
uniform float uAlpha;      // opacidad de esta capa del fondo
uniform sampler2D uImage;

out vec4 fragColor;

float roundedBox(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec4 sampleAt(vec2 screen) {
  vec2 uv = (screen - uLayer.xy) / uLayer.zw;
  return texture(uImage, clamp(uv, vec2(0.0), vec2(1.0)));
}

void main() {
  vec2 local = FlutterFragCoord().xy - uOffset;
  vec2 halfSize = uSize * 0.5;
  vec2 p = local - halfSize;
  float r = min(uRadius, min(halfSize.x, halfSize.y));
  float d = roundedBox(p, halfSize, r);
  vec2 screen = uGlobal + local;

  // Normal del borde (hacia afuera), por diferencias.
  vec2 n = vec2(
    roundedBox(p + vec2(1.0, 0.0), halfSize, r) - roundedBox(p - vec2(1.0, 0.0), halfSize, r),
    roundedBox(p + vec2(0.0, 1.0), halfSize, r) - roundedBox(p - vec2(0.0, 1.0), halfSize, r)
  );
  float len = length(n);
  n = len > 0.0001 ? n / len : vec2(0.0);

  // 1 en el filo, 0 donde termina el bisel; desvío en cuarto de círculo.
  float t = clamp(1.0 + d / max(uBevel, 0.001), 0.0, 1.0);
  float shift = uAmount * (1.0 - sqrt(max(1.0 - t * t, 0.0)));

  // Se mira hacia adentro (como el borde de un vaso): cada color un poco distinto.
  vec4 cr = sampleAt(screen - n * shift * (1.0 + uDispersion * 0.5));
  vec4 cg = sampleAt(screen - n * shift);
  vec4 cb = sampleAt(screen - n * shift * (1.0 - uDispersion * 0.5));
  vec4 color = vec4(cr.r, cg.g, cb.b, cg.a);

  float edge = clamp(0.5 - d, 0.0, 1.0);
  fragColor = color * uAlpha * edge;
}
