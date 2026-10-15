#!/usr/bin/env python3
"""Create our own seamless procedural crowd loop; no recordings or third-party audio."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
SECONDS = 2.4
rng = random.Random(452)
count = round(RATE * SECONDS)
voices = [(rng.randrange(170, 330), rng.random() * math.tau) for _ in range(14)]
# Every oscillator completes an integer number of cycles, so the endpoints join.
values = []
for i in range(count):
    t = i / count
    chant = (0.45 + 0.55 * (0.5 - 0.5 * math.cos(math.tau * 4 * t)))
    sample = sum(math.sin(math.tau * n * t + phase) + 0.35 * math.sin(math.tau * 2 * n * t + phase)
                 for n, phase in voices) / len(voices)
    clap = (max(0, math.cos(math.tau * 8 * t)) ** 40) * sum(math.sin(math.tau * n * t) for n in (1147, 1823, 2269)) / 3
    values.append((sample * chant + clap * 0.25) * 0.75)
path = Path(__file__).resolve().parents[1] / 'assets/stands/audio/opponent_cheer_loop.wav'
path.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(path), 'wb') as output:
    output.setparams((1, 2, RATE, count, 'NONE', 'not compressed'))
    output.writeframes(struct.pack('<' + 'h' * count, *(round(max(-1, min(1, s)) * 32767) for s in values)))
print(f'Created {path.relative_to(path.parents[3])}: {count} mono PCM samples; original synthesis.')
