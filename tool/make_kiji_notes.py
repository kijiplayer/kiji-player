"""Genera assets/sounds/kiji_notes.wav: las 5 notas de Kiji.

Una nota por cada barra del logo (la K y las 4 barras de la onda), de la más grave a la más
aguda: La4, Do#5, Mi5, Fa#5 y La5 (pentatónica de La mayor). Timbre de campanita suave: una
senoidal con dos armónicos chicos, ataque corto y caída exponencial. Mono, 22 050 Hz, 16 bits.

Uso: python tool/make_kiji_notes.py
"""
import math
import os
import struct
import wave

RATE = 22050
NOTES = [440.00, 554.37, 659.25, 739.99, 880.00]
GAP = 0.18  # segundos entre notas (igual que las barras en la bienvenida)
DECAY = 0.55  # segundos hasta que una nota baja a ~37 %
LENGTH = GAP * (len(NOTES) - 1) + 1.4
PEAK = 0.45

samples = [0.0] * int(RATE * LENGTH)
for i, freq in enumerate(NOTES):
    start = int(RATE * GAP * i)
    for n in range(int(RATE * 1.4)):
        t = n / RATE
        attack = min(1.0, t / 0.008)
        env = attack * math.exp(-t / DECAY)
        tone = (math.sin(2 * math.pi * freq * t)
                + 0.25 * math.sin(2 * math.pi * 2 * freq * t) * math.exp(-t / 0.2)
                + 0.08 * math.sin(2 * math.pi * 3 * freq * t) * math.exp(-t / 0.1))
        if start + n < len(samples):
            samples[start + n] += tone * env

top = max(abs(s) for s in samples)
fade = int(RATE * 0.05)
out = bytearray()
for k, s in enumerate(samples):
    if k > len(samples) - fade:
        s *= (len(samples) - k) / fade
    out += struct.pack('<h', int(s / top * PEAK * 32767))

path = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds', 'kiji_notes.wav')
os.makedirs(os.path.dirname(path), exist_ok=True)
with wave.open(path, 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(bytes(out))
print(os.path.normpath(path), len(out) // 1024, 'KB')
