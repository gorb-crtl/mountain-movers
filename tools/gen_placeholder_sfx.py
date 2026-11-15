#!/usr/bin/env python3
"""Generates placeholder sound effects into assets/sounds/ (16-bit mono WAV).

Replace any file with a real recording of the same name and the game uses it.
Usage: python3 tools/gen_placeholder_sfx.py   (standard library only)
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
random.seed(7)


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.9 / peak
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))
    print("wrote", name)


def n(sec):
    return int(sec * RATE)


def env(i, total, attack=0.005, curve=2.0):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * (1.0 - i / total) ** curve


def lowpass(samples, alpha):
    out, y = [], 0.0
    for s in samples:
        y += alpha * (s - y)
        out.append(y)
    return out


def noise(sec, curve=2.0, attack=0.002):
    total = n(sec)
    return [random.uniform(-1, 1) * env(i, total, attack, curve) for i in range(total)]


def tone(freq_fn, sec, wave_fn=math.sin, curve=1.5, attack=0.005):
    total = n(sec)
    out, ph = [], 0.0
    for i in range(total):
        ph += 2 * math.pi * freq_fn(i / total) / RATE
        out.append(wave_fn(ph) * env(i, total, attack, curve))
    return out


def square(ph):
    return 1.0 if math.sin(ph) >= 0 else -1.0


def saw(ph):
    return ((ph / (2 * math.pi)) % 1.0) * 2 - 1


def mix(*parts):
    length = max(len(p) for p in parts)
    return [sum(p[i] if i < len(p) else 0 for p in parts) for i in range(length)]


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(sec):
    return [0.0] * n(sec)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    # Pickaxe / hand hitting rock: short click + crunchy noise.
    write("dig", mix(lowpass(noise(0.09, 3), 0.35), [x * 0.5 for x in tone(lambda t: 900 - 500 * t, 0.04, square, 3)]))
    # Pixels crumbling off.
    write("crumble", lowpass(noise(0.22, 2.5), 0.18))
    # Grabbing rock into your hand: soft pop.
    write("grab", tone(lambda t: 300 + 500 * t, 0.07, math.sin, 2))
    # Rock landing in the truck bed: thud + rattle.
    write("drop", mix(tone(lambda t: 120 - 60 * t, 0.18, math.sin, 3), lowpass(noise(0.25, 2), 0.25)))
    # Rock hitting the ground.
    write("thud", mix(tone(lambda t: 90 - 40 * t, 0.12, math.sin, 3), lowpass(noise(0.1, 3), 0.15)))
    # Truck horn: two-tone honk.
    honk = mix(tone(lambda t: 330, 0.35, square, 0.6, 0.02), tone(lambda t: 415, 0.35, square, 0.6, 0.02))
    write("horn", concat(lowpass(honk, 0.3), silence(0.06), lowpass(honk, 0.3)))
    # Truck driving off: engine rumble that rises.
    write("engine", lowpass([math.sin(2 * math.pi * (45 + 30 * (i / n(1.2))) * i / RATE) * (0.6 + 0.4 * random.random()) * env(i, n(1.2), 0.1, 1) for i in range(n(1.2))], 0.2))
    # Cash register.
    write("cash", concat(tone(lambda t: 1568, 0.08, square, 1), tone(lambda t: 2093, 0.25, square, 2)))
    # Explosions.
    write("explosion", lowpass(noise(0.8, 2.2), 0.08))
    write("grenade", lowpass(noise(0.45, 2.5), 0.12))
    nuke = mix(lowpass(noise(2.6, 1.4, 0.05), 0.03), [x * 0.6 for x in tone(lambda t: 50 - 25 * t, 2.6, math.sin, 1.2, 0.05)])
    write("nuke", nuke)
    write("rumble", lowpass([random.uniform(-1, 1) * (0.5 + 0.5 * math.sin(i / RATE * 30)) * env(i, n(2.0), 0.3, 1) for i in range(n(2.0))], 0.03))
    # Guns.
    write("rifle", mix(lowpass(noise(0.12, 4), 0.5), [x * 0.4 for x in tone(lambda t: 200 - 150 * t, 0.06, square, 4)]))
    write("mg", lowpass(noise(0.06, 5), 0.6))
    write("bmg", mix(lowpass(noise(0.2, 3), 0.25), [x * 0.7 for x in tone(lambda t: 110 - 70 * t, 0.15, math.sin, 3)]))
    write("cannon", mix(lowpass(noise(0.6, 2.5), 0.06), tone(lambda t: 70 - 40 * t, 0.5, math.sin, 2)))
    # Bulldozer scrape.
    write("scrape", lowpass([random.uniform(-1, 1) * env(i, n(0.4), 0.05, 1) for i in range(n(0.4))], 0.1))
    # Bird screech: wobbling saw sweep.
    write("bird", lowpass(tone(lambda t: 1600 - 900 * t + 120 * math.sin(t * 60), 0.55, saw, 1.2, 0.02), 0.5))
    # UI.
    write("buy", concat(tone(lambda t: 523, 0.06, square, 1), tone(lambda t: 659, 0.06, square, 1), tone(lambda t: 784, 0.12, square, 2)))
    write("find", concat(*[tone(lambda t, f=f: f, 0.07, math.sin, 1) for f in (784, 988, 1175, 1568)]))
    write("deny", tone(lambda t: 140, 0.15, square, 1))
    blips = []
    for _ in range(6):
        f = random.choice([180, 220, 260, 200])
        blips += tone(lambda t, f=f: f, 0.05, square, 1) + silence(0.02)
    write("boss", lowpass(blips, 0.4))
    write("clear", concat(*[tone(lambda t, f=f: f, 0.12, square, 1) for f in (523, 659, 784, 1047)], tone(lambda t: 1047, 0.4, square, 2)))
