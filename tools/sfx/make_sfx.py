#!/usr/bin/env python3
"""Makes the built-in sound effects in audio/sfx/builtin/ (Phase 3).

Every sound is synthesized here from noise, sweeps and decaying partials
(no samples, no downloads, nothing to license). Needs numpy and ffmpeg.

    python3 -I tools/sfx/make_sfx.py            # all sounds
    python3 -I tools/sfx/make_sfx.py roll gem   # just these ids

Each id may have variations: roll.ogg, roll_2.ogg, roll_3.ogg. Beeper picks
one at random, never the same twice running. Ids and what they are for:
audio/sfx/README.md. Sounds are seeded, so a rerun makes the same files.

Levels: each sound is scaled so its loudest 50 ms sits at LEVEL dBFS (RMS),
then pulled down if a peak would pass -1 dBFS. Quiet, frequent sounds
(pegs, taps) get a lower level in SOUNDS.
"""
import math
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "audio", "sfx", "builtin")
DEFAULT_LEVEL = -16.0


# --- building blocks ---------------------------------------------------------

def silence(dur):
    return np.zeros(int(SR * dur))


def tvec(n):
    return np.arange(n) / SR


def mix_at(buf, x, at, gain=1.0):
    """Adds x into buf starting at time `at` (seconds), growing buf if needed."""
    i = int(at * SR)
    end = i + len(x)
    if end > len(buf):
        buf = np.concatenate([buf, np.zeros(end - len(buf))])
    buf[i:end] += x * gain
    return buf


def noise(dur, rng):
    return rng.standard_normal(int(SR * dur))


def exp_env(n, tau, attack=0.002):
    t = tvec(n)
    env = np.exp(-t / tau)
    a = max(1, int(attack * SR))
    env[:a] *= np.linspace(0.0, 1.0, a)
    return env


def ar_env(n, attack, release_tau):
    """Smooth attack (raised cosine) then exponential decay."""
    t = tvec(n)
    env = np.where(t < attack, 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(attack, 1e-6), 0, 1)),
                   np.exp(-(t - attack) / release_tau))
    return env


def hump(n, peak_at=0.3):
    """A swell and fade over the whole length (for whooshes)."""
    x = np.linspace(0, 1, n)
    up = np.clip(x / peak_at, 0, 1)
    down = np.clip((1 - x) / (1 - peak_at), 0, 1)
    return np.sin(np.pi / 2 * np.minimum(up, down)) ** 2


def sweep(f0, f1, dur, curve="exp", vib_rate=0.0, vib_depth=0.0, wave_fn=np.sin):
    n = int(SR * dur)
    k = np.linspace(0, 1, n)
    if curve == "exp":
        f = f0 * (f1 / f0) ** k
    else:
        f = f0 + (f1 - f0) * k ** curve
    if vib_depth:
        f = f * (1 + vib_depth * np.sin(2 * np.pi * vib_rate * tvec(n)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return wave_fn(ph)


def modal(freqs, amps, decays, dur, rng=None, attack=0.001):
    """Sum of decaying sine partials: bars, bells, wood, metal."""
    n = int(SR * dur)
    t = tvec(n)
    out = np.zeros(n)
    for f, a, d in zip(freqs, amps, decays):
        if f >= SR / 2 * 0.95:
            continue
        ph = rng.uniform(0, 2 * np.pi) if rng is not None else 0.0
        out += a * np.exp(-t / d) * np.sin(2 * np.pi * f * t + ph)
    a_n = max(1, int(attack * SR))
    out[:a_n] *= np.linspace(0, 1, a_n)
    return out


def biquad(x, kind, f0, q=0.707):
    """RBJ cookbook biquad; f0 may be a number or an array (a moving filter)."""
    n = len(x)
    f0s = np.broadcast_to(np.asarray(f0, dtype=float), (n,))
    y = np.zeros(n)
    x1 = x2 = y1 = y2 = 0.0
    xs = x.tolist()
    block = 32
    for start in range(0, n, block):
        f = min(float(f0s[start]), SR * 0.45)
        w = 2 * math.pi * f / SR
        cw, sw = math.cos(w), math.sin(w)
        alpha = sw / (2 * q)
        if kind == "lp":
            b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        elif kind == "hp":
            b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
        else:  # band pass, 0 dB peak
            b0, b1, b2 = alpha, 0.0, -alpha
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
        b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
        for i in range(start, min(start + block, n)):
            xi = xs[i]
            yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, xi, y1, yi
            y[i] = yi
    return y


def lp(x, f, q=0.707):
    return biquad(x, "lp", f, q)


def hp(x, f, q=0.707):
    return biquad(x, "hp", f, q)


def bp(x, f, q=1.0):
    return biquad(x, "bp", f, q)


def room(x, wet=0.15, size=1.0, tail=0.6):
    """A small, soft room (Schroeder combs + allpasses), for a little air."""
    pad = np.concatenate([x, np.zeros(int(SR * tail))])
    combs = [int(SR * d * size) for d in (0.0297, 0.0371, 0.0411, 0.0437)]
    out = np.zeros(len(pad))
    for d in combs:
        y = pad.copy()
        for k in range(d, len(y), d):
            y[k:k + d] += 0.72 * y[k - d:k][: len(y[k:k + d])]
        out += y
    out = lp(out / len(combs), 4500)
    for d, g in ((int(SR * 0.005), 0.7), (int(SR * 0.0017), 0.7)):
        y = np.zeros(len(out))
        xd = np.concatenate([np.zeros(d), out])
        for k in range(0, len(y), d):
            seg = slice(k, min(k + d, len(y)))
            prev = y[k - d:k][: seg.stop - seg.start] if k >= d else np.zeros(seg.stop - seg.start)
            y[seg] = -g * out[seg] + xd[seg] + g * prev
        out = y
    return pad * (1 - wet) + out * wet * 2.0


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# --- instruments ---------------------------------------------------------------

def marimba(f, dur=0.7, bright=1.0, rng=None):
    s = (440.0 / f) ** 0.4
    body = modal([f, f * 3.99, f * 9.86, f * 2.0],
                 [1.0, 0.32 * bright, 0.10 * bright, 0.04],
                 [0.38 * s, 0.07 * s, 0.025 * s, 0.2 * s], dur, rng, attack=0.0015)
    rng = rng or np.random.default_rng(1)
    knock = bp(noise(0.012, rng), min(f * 4, 6000), 1.5) * exp_env(int(SR * 0.012), 0.003) * 0.25
    return mix_at(body, knock, 0)


def bell(f, dur=1.0, decay=0.6, bright=1.0, rng=None):
    return modal([f, f * 2.0, f * 2.76, f * 4.07, f * 5.43],
                 [1.0, 0.45 * bright, 0.35 * bright, 0.18 * bright, 0.1 * bright],
                 [decay, decay * 0.6, decay * 0.4, decay * 0.25, decay * 0.15], dur, rng)


def glass(f, dur=0.6, decay=0.45, rng=None):
    """A free bar (glockenspiel/crystal): partials 1, 2.76, 5.40."""
    return modal([f, f * 2.756, f * 5.404, f * 1.003],
                 [1.0, 0.4, 0.15, 0.5], [decay, decay * 0.35, decay * 0.15, decay * 0.9], dur, rng)


def wood_click(f, rng, dur=0.05, amp=1.0):
    body = modal([f, f * 1.58, f * 2.43, f * 3.1], [1, 0.6, 0.35, 0.2],
                 [0.012, 0.008, 0.005, 0.004], dur, rng, attack=0.0004)
    tick = hp(noise(0.004, rng), 2500) * exp_env(int(SR * 0.004), 0.0012)
    return mix_at(body, tick * 0.5, 0) * amp


def soft_tone(f, dur, rng=None, vib=0.0):
    """A round, flute-ish note for the gentle 'not that one' sound."""
    n = int(SR * dur)
    t = tvec(n)
    ph = 2 * np.pi * f * t + vib * np.sin(2 * np.pi * 5.5 * t)
    x = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    return x * ar_env(n, 0.018, dur * 0.45)


def bubble(f, rng, dur=0.07):
    n = int(SR * dur)
    x = sweep(f, f * 1.9, dur)
    return x * exp_env(n, dur * 0.35, 0.002)


def creak(dur, rate0, rate1, rng, res=(620, 1150, 1900)):
    """Stick-slip friction: a jittery pulse train rung through wood resonances."""
    n = int(SR * dur)
    x = np.zeros(n)
    t = 0.0
    while t < dur:
        k = t / dur
        rate = rate0 + (rate1 - rate0) * k
        i = int(t * SR)
        if i < n:
            x[i] += rng.uniform(0.5, 1.0)
        t += (1.0 / rate) * rng.uniform(0.75, 1.25)
    out = np.zeros(n)
    for r, g in zip(res, (1.0, 0.7, 0.4)):
        out += bp(x, r, 6.0) * g
    out = out * hump(n, 0.25)
    return out / max(float(np.max(np.abs(out))), 1e-9)


def whoosh(dur, f0, f1, rng, q=1.5, peak_at=0.4):
    n = int(SR * dur)
    fc = f0 * (f1 / f0) ** np.linspace(0, 1, n)
    return bp(noise(dur, rng), fc, q) * hump(n, peak_at)


def glitter(dur, count, rng, lo=3000, hi=7000, amp=0.2):
    buf = silence(dur)
    for _ in range(count):
        f = rng.uniform(lo, hi)
        g = glass(f, 0.12, 0.05, rng) * amp * rng.uniform(0.4, 1.0)
        buf = mix_at(buf, g, rng.uniform(0, dur * 0.8))
    return buf


def arpeggio(notes_hz, step, inst, gains=None):
    buf = silence(0.01)
    for i, f in enumerate(notes_hz):
        g = 1.0 if gains is None else gains[i]
        buf = mix_at(buf, inst(f), i * step, g)
    return buf


# --- the sounds ---------------------------------------------------------------
# Each maker takes a seeded rng and the variation number (1, 2, 3...).

def s_roll(rng, v):
    """Two dice tumbling in a wooden tray, then settling."""
    buf = silence(0.7)
    for die in range(2):
        t = 0.0 + die * rng.uniform(0.015, 0.05)
        gap = rng.uniform(0.07, 0.1)
        amp = 1.0
        while t < 0.6 and amp > 0.08:
            f = rng.uniform(1300, 2700)
            buf = mix_at(buf, wood_click(f, rng, amp=amp), t)
            # the tray answers the bigger knocks
            if amp > 0.35:
                tray = modal([rng.uniform(190, 230), rng.uniform(330, 360), 520], [1, 0.6, 0.3],
                             [0.05, 0.035, 0.02], 0.12, rng)
                buf = mix_at(buf, tray, t, 0.45 * amp)
            t += gap * rng.uniform(0.75, 1.2)
            gap *= rng.uniform(0.78, 0.9)
            amp *= rng.uniform(0.78, 0.9)
        # a last few quick rattles as it settles
        for _ in range(3):
            buf = mix_at(buf, wood_click(rng.uniform(2500, 4000), rng, amp=0.12), t)
            t += rng.uniform(0.012, 0.025)
    return room(buf, 0.12, 0.6, 0.25)


def s_hop(rng, v):
    """A soft cartoon spring up."""
    k = [1.0, 1.08, 0.93][(v - 1) % 3]
    n = int(SR * 0.13)
    x = sweep(240 * k, 520 * k, 0.13)
    x = (x + 0.2 * sweep(480 * k, 1040 * k, 0.13)) * ar_env(n, 0.01, 0.05)
    air = lp(noise(0.13, rng), 1600) * ar_env(n, 0.02, 0.04) * 0.12
    return x + air


def s_land(rng, v):
    """A soft landing on stone: a padded thud and a small click."""
    n = int(SR * 0.18)
    thud = sweep(150, 70, 0.18) * exp_env(n, 0.05, 0.002)
    dust = lp(noise(0.18, rng), 450) * exp_env(n, 0.025) * 0.6
    click = wood_click(rng.uniform(1100, 1400), rng, amp=0.25)
    return mix_at(thud + dust, click, 0.002)


def s_stone_pick(rng, v):
    """Tapping a stone to choose it: a bright wooden tick."""
    f = [1400, 1520][(v - 1) % 2]
    tick = wood_click(f, rng, dur=0.08, amp=0.7)
    note = marimba(f * 0.75, 0.15, 0.5, rng) * 0.4
    return mix_at(tick, note, 0)


def s_tap(rng, v):
    """A soft button pop."""
    n = int(SR * 0.09)
    x = sweep(1100, 560, 0.03)
    x = np.concatenate([x, sweep(560, 520, 0.06)])[:n] * exp_env(n, 0.03, 0.001)
    return mix_at(x, wood_click(2200, rng, 0.03, 0.25), 0)


def s_nope(rng, v):
    """Can't do that right now: a soft, low, muted knock. Not a buzz."""
    a = marimba(midi(55), 0.3, 0.3, rng) * exp_env(int(SR * 0.3), 0.08)
    return lp(a, 1800)


def s_sink(rng, v):
    """The slime sinks into the lava: a wobbly gulp, then two bubble pops."""
    dur = 0.45
    n = int(SR * dur)
    gulp = sweep(320, 70, dur, curve=0.6, vib_rate=16, vib_depth=0.12)
    gulp = gulp + 0.3 * sweep(640, 140, dur, curve=0.6, vib_rate=16, vib_depth=0.12)
    gulp = lp(gulp * ar_env(n, 0.01, 0.2), 1400)
    slosh = lp(noise(0.25, rng), 700) * ar_env(int(SR * 0.25), 0.02, 0.06) * 0.35
    buf = mix_at(gulp, slosh, 0)
    buf = mix_at(buf, bubble(480, rng), 0.5, 0.55)
    buf = mix_at(buf, bubble(690, rng), 0.62, 0.45)
    buf = mix_at(buf, bubble(560, rng, 0.05), 0.71, 0.25)
    return room(buf, 0.1, 0.8, 0.3)


def s_chest_open(rng, v):
    """A chest lid creaks open, clunks, and a little shimmer spills out."""
    buf = creak(0.32, 35, 110, rng) * 0.5
    clunk = modal([170, 265, 410], [1, 0.6, 0.3], [0.07, 0.05, 0.03], 0.15, rng)
    buf = mix_at(buf, clunk + lp(noise(0.15, rng), 600) * exp_env(int(SR * 0.15), 0.02) * 0.3, 0.3, 0.9)
    buf = mix_at(buf, wood_click(1300, rng, amp=0.5), 0.3)
    shimmer = arpeggio([midi(84), midi(88), midi(91), midi(96)], 0.05,
                       lambda f: glass(f, 0.5, 0.25, rng), [0.25, 0.25, 0.25, 0.3])
    buf = mix_at(buf, shimmer, 0.36)
    buf = mix_at(buf, glitter(0.4, 8, rng, amp=0.12), 0.38)
    return room(buf, 0.12, 0.8, 0.3)


def s_gem(rng, v):
    """One gem: a crystal chime at C6 (Beeper raises the pitch per gem)."""
    x = glass(1046.5, 0.6, 0.4, rng)
    x = mix_at(x, glass(4186, 0.08, 0.03, rng) * 0.15, 0)
    return room(x, 0.1, 0.7, 0.25)


def s_coin(rng, v):
    """A small bright clink (gems pouring into the bucket, one each)."""
    f = 1568.0
    a = modal([f, f * 1.47, f * 2.09, f * 2.56], [1, 0.6, 0.4, 0.25], [0.15, 0.1, 0.07, 0.05], 0.35, rng)
    b = modal([f * 1.02, f * 1.5, f * 2.12], [0.5, 0.3, 0.2], [0.1, 0.07, 0.05], 0.3, rng)
    return mix_at(a, b, 0.035)


def s_bucket(rng, v):
    """The bucket catches: a wooden thunk with a few gems clattering in."""
    buf = modal([150, 238, 390, 610], [1, 0.7, 0.35, 0.15], [0.12, 0.08, 0.05, 0.03], 0.3, rng)
    buf = mix_at(buf, lp(noise(0.08, rng), 900) * exp_env(int(SR * 0.08), 0.015) * 0.4, 0)
    for i in range(4):
        buf = mix_at(buf, s_coin(rng, 1) * 0.3, 0.03 + i * rng.uniform(0.03, 0.06))
    return room(buf, 0.1, 0.7, 0.2)


def s_heart(rng, v):
    """A heart picked up: a quick sparkling run up and a warm swell."""
    notes = [midi(m) for m in (84, 88, 91, 96, 100)]
    buf = arpeggio(notes, 0.045, lambda f: glass(f, 0.45, 0.22, rng), [0.5, 0.5, 0.5, 0.55, 0.45])
    n = int(SR * 0.6)
    pad = (np.sin(2 * np.pi * midi(72) * tvec(n)) + 0.6 * np.sin(2 * np.pi * midi(79) * tvec(n)))
    pad *= hump(n, 0.25) * 0.25
    buf = mix_at(buf, pad, 0)
    buf = mix_at(buf, glitter(0.45, 10, rng, 5000, 9000, 0.1), 0.05)
    return room(buf, 0.15, 0.9, 0.35)


def s_heart_land(rng, v):
    """The heart lands in the row: a soft pop and a warm ding."""
    pop = sweep(600, 950, 0.03) * exp_env(int(SR * 0.03), 0.012)
    ding = mix_at(bell(midi(88), 0.6, 0.35, 0.6, rng) * 0.7, bell(midi(76), 0.5, 0.3, 0.3, rng), 0, 0.3)
    return room(mix_at(ding, pop, 0), 0.12, 0.8, 0.3)


def s_block(rng, v):
    """A shield blocks: a round metal clang, bright but not sharp."""
    f0 = [620, 660][(v - 1) % 2]
    ratios = [1, 1.52, 2.27, 2.91, 3.6, 4.4]
    freqs = [f0 * r for r in ratios] + [f0 * r * 1.006 for r in ratios[:3]]
    amps = [1, 0.7, 0.5, 0.35, 0.22, 0.14, 0.6, 0.4, 0.3]
    decs = [0.45, 0.32, 0.25, 0.18, 0.12, 0.09, 0.42, 0.3, 0.22]
    ring = modal(freqs, amps, decs, 0.8, rng, attack=0.0008)
    hit = bp(noise(0.01, rng), 2800, 1.2) * exp_env(int(SR * 0.01), 0.003) * 1.5
    thump = sweep(130, 80, 0.08) * exp_env(int(SR * 0.08), 0.03) * 0.7
    buf = mix_at(mix_at(ring, hit, 0), thump, 0)
    return room(lp(buf, 6500), 0.12, 0.8, 0.3)


def s_hit(rng, v):
    """A friendly bonk: a padded thud with a little slap on top."""
    k = [1.0, 0.9][(v - 1) % 2]
    n = int(SR * 0.25)
    thud = sweep(190 * k, 65 * k, 0.25, curve=0.5) * exp_env(n, 0.07, 0.001)
    slap = lp(noise(0.05, rng), 1500) * exp_env(int(SR * 0.05), 0.01) * 0.6
    return mix_at(thud, slap, 0)


def s_poof(rng, v):
    """A monster is beaten: a soft puff of smoke and a sparkle."""
    n = int(SR * 0.55)
    fc = 1800 * (450 / 1800) ** np.linspace(0, 1, n)
    puff = lp(bp(noise(0.55, rng), fc, 0.9), 2800) * ar_env(n, 0.015, 0.14)
    pop = sweep(320, 110, 0.06) * exp_env(int(SR * 0.06), 0.02) * 0.8
    buf = mix_at(puff, pop, 0)
    sparkle = arpeggio([midi(91), midi(96), midi(100)], 0.06, lambda f: glass(f, 0.35, 0.15, rng), [0.18] * 3)
    buf = mix_at(buf, sparkle, 0.3)
    return room(buf, 0.15, 0.9, 0.35)


def s_win(rng, v):
    """The win jingle: a bright run up to a held chord."""
    buf = silence(0.1)
    mel = [(0.0, 72), (0.11, 76), (0.22, 79), (0.36, 84)]
    for t, m in mel:
        last = m == 84
        buf = mix_at(buf, marimba(midi(m), 1.0 if last else 0.5, 1.0, rng), t, 0.7)
        buf = mix_at(buf, bell(midi(m), 1.2 if last else 0.4, 0.6 if last else 0.2, 0.6, rng), t, 0.35)
    for m in (88, 91):
        buf = mix_at(buf, bell(midi(m), 1.2, 0.55, 0.5, rng), 0.36, 0.22)
    buf = mix_at(buf, marimba(midi(48), 0.8, 0.5, rng), 0.0, 0.4)
    buf = mix_at(buf, marimba(midi(48), 1.0, 0.5, rng), 0.36, 0.45)
    buf = mix_at(buf, marimba(midi(55), 1.0, 0.5, rng), 0.36, 0.3)
    buf = mix_at(buf, glitter(0.7, 16, rng, 4000, 9000, 0.08), 0.36)
    return room(buf, 0.15, 1.0, 0.5)


def s_good(rng, v):
    """That's right: three quick rising notes."""
    buf = silence(0.1)
    for i, m in enumerate((72, 76, 79)):
        buf = mix_at(buf, marimba(midi(m), 0.5, 0.9, rng), i * 0.085, 0.7)
        buf = mix_at(buf, glass(midi(m + 12), 0.4, 0.18 + 0.1 * i, rng), i * 0.085, 0.22)
    return room(buf, 0.12, 0.9, 0.3)


def s_wrong(rng, v):
    """Not that one: two soft notes stepping down, round and friendly."""
    a = soft_tone(midi(64), 0.2, rng, vib=0.0)
    b = soft_tone(midi(60), 0.32, rng, vib=0.25)
    buf = mix_at(a * 0.9, b, 0.17)
    buf = mix_at(buf, marimba(midi(52), 0.3, 0.2, rng), 0.0, 0.25)
    buf = mix_at(buf, marimba(midi(48), 0.4, 0.2, rng), 0.17, 0.25)
    return room(lp(buf, 2500), 0.1, 0.8, 0.25)


def s_door(rng, v):
    """A door swings open: a short creak, a breath of air, a rising shimmer."""
    buf = creak(0.26, 60, 150, rng, (800, 1400, 2300)) * 0.35
    buf = mix_at(buf, whoosh(0.45, 300, 1600, rng, 1.2, 0.5) * 0.5, 0.1)
    notes = [midi(m) for m in (79, 81, 84, 86, 88, 91)]
    buf = mix_at(buf, arpeggio(notes, 0.055, lambda f: glass(f, 0.4, 0.2, rng), [0.22] * 6), 0.15)
    return room(buf, 0.18, 1.0, 0.4)


PEG_NOTES = [midi(m) for m in (79, 81, 84, 86)]


def s_peg(rng, v):
    """The ball bounces off a wall or bumper: a small glassy tok."""
    f = PEG_NOTES[(v - 1) % len(PEG_NOTES)]
    x = modal([f, f * 2.76, f * 0.5], [1, 0.25, 0.3], [0.08, 0.03, 0.04], 0.18, rng, attack=0.0006)
    return mix_at(x, wood_click(f * 1.6, rng, 0.03, 0.3), 0)


def s_peg_mod(rng, v):
    """A plus-or-minus-one peg: a quick twinkle up."""
    notes = [midi(m) for m in (91, 95, 98)]
    return room(arpeggio(notes, 0.03, lambda f: glass(f, 0.3, 0.12, rng)), 0.12, 0.7, 0.2)


def s_whiff(rng, v):
    """The ball ghosts through a peg: a faint airy whoosh."""
    n = int(SR * 0.2)
    air = whoosh(0.2, 1100, 2300, rng, 2.0, 0.35)
    ooo = np.sin(2 * np.pi * 1480 * tvec(n) + 0.5 * np.sin(2 * np.pi * 6 * tvec(n))) * hump(n, 0.3) * 0.15
    return air + ooo


def s_launch(rng, v):
    """The ball is launched: a springy thwip."""
    n = int(SR * 0.3)
    up = sweep(200, 900, 0.08) * ar_env(int(SR * 0.08), 0.005, 0.05)
    spring = np.sin(2 * np.pi * 420 * tvec(n) + 3 * np.sin(2 * np.pi * 28 * tvec(n))) * exp_env(n, 0.07) * 0.3
    air = whoosh(0.2, 600, 2500, rng, 1.0, 0.2) * 0.4
    return mix_at(mix_at(spring, up, 0), air, 0)


def s_buy(rng, v):
    """Bought it: coins clink, then a happy ta-da."""
    buf = silence(0.1)
    for i in range(3):
        buf = mix_at(buf, s_coin(rng, 1) * 0.45, i * 0.06)
    buf = mix_at(buf, marimba(midi(79), 0.4, 0.8, rng), 0.2, 0.6)
    buf = mix_at(buf, bell(midi(84), 0.9, 0.45, 0.6, rng), 0.32, 0.5)
    buf = mix_at(buf, marimba(midi(84), 0.7, 0.8, rng), 0.32, 0.6)
    buf = mix_at(buf, glitter(0.4, 8, rng, amp=0.1), 0.34)
    return room(buf, 0.14, 0.9, 0.35)


def s_select(rng, v):
    """Something picked in the shop: a bright little ding."""
    return room(bell(midi(91), 0.45, 0.25, 0.6, rng), 0.12, 0.8, 0.2)


def s_crack(rng, v):
    """A shield or a heart cracks: small brittle snaps over a soft thunk."""
    buf = sweep(170, 110, 0.12) * exp_env(int(SR * 0.12), 0.04) * 0.6
    t = 0.0
    for _ in range(7):
        snap = bp(noise(0.006, rng), rng.uniform(2200, 5000), 2.0) * exp_env(int(SR * 0.006), 0.0015)
        buf = mix_at(buf, snap, t, rng.uniform(0.6, 1.4))
        t += rng.uniform(0.006, 0.018)
    buf = mix_at(buf, glass(midi(81), 0.25, 0.08, rng) * 0.25, 0.02)
    return room(buf, 0.1, 0.7, 0.2)


def s_miss(rng, v):
    """A swing that misses: a swish of air."""
    n = int(SR * 0.28)
    fc = np.interp(np.linspace(0, 1, n), [0, 0.45, 1], [450, 1700, 600])
    return lp(bp(noise(0.28, rng), fc, 1.3), 3500) * hump(n, 0.45)


def s_peek(rng, v):
    """A die peeks: a tiny glint."""
    a = glass(midi(100), 0.12, 0.04, rng)
    b = glass(midi(105), 0.15, 0.05, rng)
    return mix_at(a * 0.7, b, 0.04)


def s_lantern(rng, v):
    """The lantern goes out: a soft puff."""
    n = int(SR * 0.3)
    puff = lp(noise(0.3, rng), 900) * ar_env(n, 0.012, 0.07)
    low = np.sin(2 * np.pi * 90 * tvec(n)) * exp_env(n, 0.05) * 0.3
    return puff + low


def s_reveal(rng, v):
    """A hidden space shows what it holds: a rising shwing."""
    buf = lp(whoosh(0.28, 700, 3000, rng, 2.2, 0.8), 4000) * 0.6
    buf = mix_at(buf, bell(midi(88), 0.5, 0.3, 0.6, rng) * 0.4, 0.22)
    buf = mix_at(buf, bell(midi(95), 0.5, 0.25, 0.5, rng) * 0.3, 0.25)
    return room(buf, 0.12, 0.8, 0.3)


def s_count(rng, v):
    """One counting note: a marimba A4. Beeper climbs a major scale from it."""
    return room(marimba(440.0, 0.7, 1.0, rng), 0.08, 0.6, 0.2)


def s_mallet(rng, v):
    """The fallback for any other Beeper.tone(): a soft mallet A4, pitched."""
    x = mix_at(marimba(440.0, 0.5, 0.6, rng) * 0.8, glass(880.0, 0.4, 0.15, rng), 0, 0.15)
    return room(x, 0.08, 0.6, 0.2)


def s_warble(rng, v):
    """The last heart: time slows, the sound falls and wobbles."""
    dur = 0.95
    n = int(SR * dur)
    k = np.linspace(0, 1, n)
    f = (620 * (330 / 620) ** k) * (1 + 0.08 * np.sin(2 * np.pi * (7 - 3 * k) * tvec(n)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)
    x *= ar_env(n, 0.02, 0.5) * (1 - k) ** 0.5
    x = mix_at(x, glass(1240, 0.6, 0.3, rng) * 0.2, 0)
    return room(lp(x, 3000), 0.2, 1.2, 0.5)


# id -> (maker, variations, level dBFS)
SOUNDS = {
    "roll": (s_roll, 3, -15),
    "hop": (s_hop, 3, -19),
    "land": (s_land, 2, -18),
    "stone_pick": (s_stone_pick, 2, -18),
    "tap": (s_tap, 1, -19),
    "nope": (s_nope, 1, -19),
    "sink": (s_sink, 1, -14),
    "chest_open": (s_chest_open, 1, -16),
    "gem": (s_gem, 1, -18),
    "coin": (s_coin, 1, -20),
    "bucket": (s_bucket, 1, -17),
    "heart": (s_heart, 1, -16),
    "heart_land": (s_heart_land, 1, -17),
    "block": (s_block, 2, -16),
    "hit": (s_hit, 2, -15),
    "poof": (s_poof, 1, -15),
    "win": (s_win, 1, -14),
    "good": (s_good, 1, -15),
    "wrong": (s_wrong, 1, -17),
    "door": (s_door, 1, -16),
    "peg": (s_peg, 4, -22),
    "peg_mod": (s_peg_mod, 1, -18),
    "whiff": (s_whiff, 1, -25),
    "launch": (s_launch, 1, -17),
    "buy": (s_buy, 1, -15),
    "select": (s_select, 1, -18),
    "crack": (s_crack, 1, -16),
    "miss": (s_miss, 1, -18),
    "peek": (s_peek, 1, -21),
    "lantern": (s_lantern, 1, -18),
    "reveal": (s_reveal, 1, -17),
    "count": (s_count, 1, -16),
    "mallet": (s_mallet, 1, -17),
    "warble": (s_warble, 1, -15),
}


# --- finishing ---------------------------------------------------------------

def finish(x, level_db):
    x = np.asarray(x, dtype=float)
    # trim the silent tail, then a short fade so nothing clicks
    thresh = np.max(np.abs(x)) * 10 ** (-60 / 20)
    idx = np.nonzero(np.abs(x) > thresh)[0]
    end = int(idx[-1]) + 1 if len(idx) else len(x)
    x = x[: min(len(x), end + int(SR * 0.01))]
    fade = min(len(x) // 4, int(SR * 0.02))
    x[-fade:] *= np.linspace(1, 0, fade)
    x[: int(SR * 0.0005)] *= np.linspace(0, 1, int(SR * 0.0005))
    w = int(SR * 0.05)
    if len(x) > w:
        sq = np.convolve(x * x, np.ones(w) / w, mode="valid")
        rms = math.sqrt(float(np.max(sq)))
    else:
        rms = math.sqrt(float(np.mean(x * x)))
    x = x * (10 ** (level_db / 20) / max(rms, 1e-9))
    peak_cap = 10 ** (-1 / 20)
    peak = float(np.max(np.abs(x)))
    if peak > peak_cap:
        x *= peak_cap / peak
    return x


def write_ogg(x, path):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "s.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav_path, "-ac", "1",
                        "-c:a", "libvorbis", "-q:a", "4", "-map_metadata", "-1", path], check=True)


def file_name(sound_id, v):
    return "%s.ogg" % sound_id if v == 1 else "%s_%d.ogg" % (sound_id, v)


def main(argv):
    only = set(argv)
    unknown = only - set(SOUNDS)
    if unknown:
        sys.exit("unknown ids: " + ", ".join(sorted(unknown)))
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for i, (sound_id, (maker, variations, level)) in enumerate(SOUNDS.items()):
        if only and sound_id not in only:
            continue
        for v in range(1, variations + 1):
            rng = np.random.default_rng(1000 * i + v)
            x = finish(maker(rng, v), level)
            path = os.path.join(OUT, file_name(sound_id, v))
            write_ogg(x, path)
            size = os.path.getsize(path)
            total += size
            print("%-22s %5.2f s %6.1f KB" % (os.path.basename(path), len(x) / SR, size / 1024))
    print("total %.1f KB" % (total / 1024))


if __name__ == "__main__":
    main(sys.argv[1:])
