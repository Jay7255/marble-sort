"""Synthesises the game's sound effects into assets/sounds/*.wav (run: python3 tool/make_sounds.py)."""
import math, struct, wave, os, random
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')

def env(t, dur, attack=0.004):
    if t < attack: return t / attack
    return math.exp(-6.0 * (t - attack) / max(dur - attack, 1e-6))

def render(notes, length):
    """notes: list of (start, freq, dur, wave, vol)."""
    n = int(SR * length); buf = [0.0] * n
    for start, f, dur, kind, vol in notes:
        s0 = int(start * SR)
        for i in range(int(dur * SR)):
            j = s0 + i
            if j >= n: break
            t = i / SR; ph = 2 * math.pi * f * t
            if kind == 'sine': v = math.sin(ph)
            elif kind == 'tri': v = 2 / math.pi * math.asin(math.sin(ph))
            elif kind == 'square': v = 1.0 if math.sin(ph) >= 0 else -1.0
            else: v = random.uniform(-1, 1)
            buf[j] += v * vol * env(t, dur)
    peak = max(1e-9, max(abs(x) for x in buf))
    if peak > 0.95: buf = [x * 0.95 / peak for x in buf]
    return buf

def save(name, buf):
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 32767)) for x in buf))

random.seed(1)
save('pick.wav', render([(0, 660, .08, 'tri', .5), (0, 1320, .05, 'sine', .15)], .12))
for k in range(4):  # glass clink, rising with the slot it lands in
    f = 1900 + k * 180
    save(f'clink{k}.wav', render([(0, f, .22, 'sine', .55), (0, f * 1.51, .14, 'sine', .25), (0, f * 2.76, .06, 'sine', .1)], .25))
save('bad.wav', render([(0, 170, .18, 'square', .25), (0, 120, .18, 'sine', .4)], .2))
save('cork.wav', render([(0, 520, .09, 'tri', .6), (0, 0, .03, 'noise', .25)] + [(.08 + i * .07, f, .4, 'sine', .35) for i, f in enumerate([1046, 1318, 1568])], .7))
save('win.wav', render([(i * .11, f, .55, 'tri', .4) for i, f in enumerate([523, 659, 784, 1046, 1318])] + [(.55, 1568, .7, 'sine', .25)], 1.3))
save('coin.wav', render([(0, 1318, .1, 'square', .18), (.07, 1760, .2, 'square', .18)], .3))
save('star.wav', render([(0, 1175, .25, 'tri', .4), (0, 2350, .12, 'sine', .12)], .3))
save('start.wav', render([(i * .09, f, .3, 'sine', .3) for i, f in enumerate([523, 659, 784])], .5))
save('pop.wav', render([(0, 880, .12, 'tri', .45), (.05, 1320, .18, 'sine', .3)], .3))
print('ok', sorted(os.listdir(OUT)))
