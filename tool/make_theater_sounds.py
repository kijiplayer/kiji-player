"""Genera los sonidos originales de las reacciones de teatro (assets/sounds/*.wav).

Son de Kiji (sin muestras de terceros): ruido y tonos sintetizados aquí. Varias versiones de cada
uno, que Kiji elige al azar:
  splat_1..3   el tomate que se estrella (seco, jugoso, con rebote)
  boo_1..3     abucheos (grave, de muchos, con silbido)
  applause_1..3 aplausos (pocos, un grupo, una sala)
  ovation      ovación de pie: aplausos que crecen y gritos de "¡bravo!" (vocales sintetizadas)
  curtain      el telón que se cierra (un "fssh" de tela)

Uso: python tool/make_theater_sounds.py
"""
import math
import os
import random
import struct
import wave

R = 22050
OUT = 'assets/sounds'


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    k = 0.89 / peak if peak > 0.89 else 1.0
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(R)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * k)) * 32767)) for s in samples))


def splat(seed, length, cutoff, thump_hz, wet):
    random.seed(seed)
    out, lp = [], 0.0
    for i in range(int(R * length)):
        t = i / R
        noise = random.uniform(-1, 1)
        lp += (noise - lp) * cutoff
        body = lp * 2.2 * math.exp(-t * 13)
        thump = math.sin(2 * math.pi * thump_hz * t * (1 - t)) * math.exp(-t * 28) * 0.9
        # "Jugo": gotitas cortas al final.
        drip = 0.0
        if wet and t > 0.08:
            drip = sum(
                math.sin(2 * math.pi * (900 + 300 * j) * (t - d)) * math.exp(-(t - d) * 90)
                for j, d in enumerate((0.11, 0.17, 0.26)) if t >= d
            ) * 0.12
        out.append(0.75 * (body + thump + drip))
    return out


def boo(seed, length, freqs, vibrato, whistle):
    random.seed(seed)
    out = []
    for i in range(int(R * length)):
        t = i / R
        env = min(1, t / 0.1) * (1 - t / length) ** 1.2
        v = sum(math.sin(2 * math.pi * f * t + 2.4 * math.sin(2 * math.pi * (vibrato + 0.3 * j) * t)) for j, f in enumerate(freqs))
        v /= len(freqs)
        air = random.uniform(-1, 1) * 0.09
        w = 0.0
        if whistle and 0.15 < t < 0.7:
            # Un silbido que baja (el clásico de la platea).
            f = 2600 - 1400 * (t - 0.15) / 0.55
            w = math.sin(2 * math.pi * f * t) * 0.18 * math.sin(math.pi * (t - 0.15) / 0.55)
        out.append(0.6 * env * (v + air) + w)
    return out


def applause(seed, length, claps, room):
    random.seed(seed)
    n = int(R * length)
    out = [0.0] * n
    for _ in range(claps):
        start, lp = int(random.uniform(0, length - 0.15) * R), 0.0
        tone = random.uniform(0.45, 0.75)
        for k in range(int(R * 0.03)):
            if start + k >= n:
                break
            noise = random.uniform(-1, 1)
            lp += (noise - lp) * tone
            out[start + k] += (noise - lp) * math.exp(-k / (R * 0.005)) * 0.3
    # Sala: un eco corto.
    if room:
        d = int(R * 0.045)
        for i in range(d, n):
            out[i] += out[i - d] * 0.35
    fade = R * 0.35
    return [c * min(1, (n - i) / fade) * min(1, i / (R * 0.05)) for i, c in enumerate(out)]


def bravo(t0, pitch, n):
    """Un "¡bra-vo!" sintetizado: dos sílabas con formantes de "a" y "o"."""
    out = [0.0] * n
    for syl, (start, dur, f1, f2, glide) in enumerate([(0.0, 0.16, 750, 1250, 1.0), (0.18, 0.3, 500, 900, 0.85)]):
        for i in range(int(R * dur)):
            k = int(R * (t0 + start)) + i
            if k >= n:
                break
            t = i / R
            f0 = pitch * (1 + 0.15 * syl) * (1 - (1 - glide) * t / dur)
            env = math.sin(math.pi * min(1, t / dur)) ** 0.6
            src = sum(math.sin(2 * math.pi * f0 * h * t) / h for h in range(1, 12))
            # Dos formantes (resonancias de la vocal) aproximados con senos ponderados.
            form = sum(
                math.sin(2 * math.pi * f0 * h * t) * (math.exp(-((f0 * h - f1) / 180) ** 2) + 0.7 * math.exp(-((f0 * h - f2) / 260) ** 2))
                for h in range(1, 40)
            )
            out[k] += env * (0.15 * src + 0.6 * form) * 0.18
    return out


def ovation(seed):
    random.seed(seed)
    length = 3.2
    n = int(R * length)
    base = applause(seed, length, 520, True)
    out = [b * (0.35 + 0.65 * min(1, i / (R * 1.4))) for i, b in enumerate(base)]
    for j, (t0, pitch) in enumerate([(0.6, 190), (1.1, 240), (1.5, 160), (2.0, 210)]):
        voice = bravo(t0, pitch, n)
        for i in range(n):
            out[i] += voice[i]
    return out


def curtain(seed):
    random.seed(seed)
    out, lp, hp = [], 0.0, 0.0
    length = 0.7
    for i in range(int(R * length)):
        t = i / R
        noise = random.uniform(-1, 1)
        cut = 0.05 + 0.35 * math.sin(math.pi * t / length)
        lp += (noise - lp) * cut
        hp = lp - hp * 0.2
        env = math.sin(math.pi * t / length) ** 1.5
        out.append(hp * env * 1.4 + math.sin(2 * math.pi * 70 * t) * math.exp(-((t - length * 0.9) * 30) ** 2) * 0.4)
    return out


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for old in ('splat', 'boo', 'applause'):
        path = f'{OUT}/{old}.wav'
        if os.path.exists(path):
            os.remove(path)
    write('splat_1', splat(1, 0.35, 0.18, 90, False))
    write('splat_2', splat(2, 0.45, 0.32, 70, True))
    write('splat_3', splat(3, 0.3, 0.12, 120, True))
    write('boo_1', boo(4, 0.9, (110, 131, 147), 5.5, False))
    write('boo_2', boo(5, 1.3, (98, 117, 131, 147, 165), 4.2, False))
    write('boo_3', boo(6, 1.1, (123, 147), 6.5, True))
    write('applause_1', applause(7, 1.0, 60, False))
    write('applause_2', applause(8, 1.4, 160, False))
    write('applause_3', applause(9, 1.8, 300, True))
    write('ovation', ovation(10))
    write('curtain', curtain(11))
    print('ok')
