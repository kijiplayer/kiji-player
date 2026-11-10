"""Genera los sonidos originales de las reacciones de teatro (assets/sounds/splat|boo|applause.wav).

Son de Kiji (sin muestras de terceros): ruido y tonos sintetizados aquí. Uso: python tool/make_theater_sounds.py
"""
import math, random, struct, wave

random.seed(7)
R = 22050


def write(name, samples):
    with wave.open(f'assets/sounds/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(R)
        w.writeframes(b''.join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples))


# Splat: ruido filtrado con caída rápida y un golpe grave.
splat, lp = [], 0.0
for i in range(int(R * 0.35)):
    t = i / R
    noise = random.uniform(-1, 1)
    lp += (noise - lp) * 0.18
    splat.append(0.7 * (lp * 2.2 * math.exp(-t * 14) + math.sin(2 * math.pi * 90 * t) * math.exp(-t * 30) * 0.8))
write('splat', splat)

# Abucheo: "buuu" grave con vibrato y un poco de aire, tres voces.
boo = []
for i in range(int(R * 0.9)):
    t = i / R
    env = min(1, t / 0.08) * (1 - t / 0.9) ** 1.3
    v = sum(math.sin(2 * math.pi * f * t + 2.5 * math.sin(2 * math.pi * 5.5 * t)) for f in (110, 131, 147)) / 3
    boo.append(0.55 * env * (v + random.uniform(-1, 1) * 0.08))
write('boo', boo)

# Aplausos: muchos chasquidos cortos de ruido, al azar.
n = int(R * 1.3)
claps = [0.0] * n
for _ in range(140):
    start, lp = int(random.uniform(0, 1.15) * R), 0.0
    for k in range(int(R * 0.025)):
        if start + k >= n:
            break
        noise = random.uniform(-1, 1)
        lp += (noise - lp) * 0.6
        claps[start + k] += (noise - lp) * math.exp(-k / (R * 0.006)) * 0.35
write('applause', [c * min(1, (n - i) / (R * 0.3)) for i, c in enumerate(claps)])
print('ok')
