#!/usr/bin/env python3
"""Synthesize crush + sweaty sole SFX bed timed to the POV video."""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

SR = 44100
AUDIO_DIR = Path("/workspace/echidna-crush/audio")


def fade(n: int, ain: float = 0.01, aout: float = 0.05) -> np.ndarray:
    env = np.ones(n, dtype=np.float64)
    ni = max(1, int(ain * SR))
    no = max(1, int(aout * SR))
    env[:ni] *= np.linspace(0, 1, ni)
    env[-no:] *= np.linspace(1, 0, no)
    return env


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n).astype(np.float64)


def lowpass(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    """Simple one-pole lowpass."""
    if len(x) == 0:
        return x
    rc = 1.0 / (2 * np.pi * cutoff_hz)
    dt = 1.0 / SR
    a = dt / (rc + dt)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    return x - lowpass(x, cutoff_hz)


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    return lowpass(highpass(x, lo), hi)


def write_wav(path: Path, mono: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    clipped = np.clip(mono, -1.0, 1.0)
    pcm = (clipped * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())


def whoosh(dur: float, rng: np.random.Generator, pitch_start: float = 900, pitch_end: float = 180) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    # Sweeping band-limited noise
    raw = noise(n, rng)
    # Chirp envelope modulating filter proxy via amplitude + AM
    sweep = np.linspace(pitch_start, pitch_end, n)
    carrier = np.sin(2 * np.pi * np.cumsum(sweep) / SR)
    sig = bandpass(raw, 120, 4000) * (0.55 + 0.45 * carrier)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.4
    return sig * env * 0.55


def wet_drip(rng: np.random.Generator, dur: float = 0.12) -> np.ndarray:
    """Tiny wet droplet / sweat bead sound."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(700, 1400)
    # Decaying sine + soft noise pop
    tone = np.sin(2 * np.pi * f0 * t) * np.exp(-t * rng.uniform(28, 55))
    pop = highpass(noise(n, rng), 1500) * np.exp(-t * 80) * 0.35
    # Soft bubble-ish second harmonic
    bub = np.sin(2 * np.pi * f0 * 0.45 * t + 0.3) * np.exp(-t * 20) * 0.25
    return (tone * 0.5 + pop + bub) * fade(n, 0.001, 0.04) * 0.45


def wet_squelch(rng: np.random.Generator, dur: float = 0.35) -> np.ndarray:
    """Sticky sweaty skin squelch / peel."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    # Low wet body + mid sticky friction
    body = lowpass(noise(n, rng), 280) * np.exp(-t * 4.5)
    sticky = bandpass(noise(n, rng), 400, 2200)
    # Amplitude modulation for squish pulses
    pulses = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(9, 16) * t + rng.uniform(0, 3))
    pulses = pulses ** 2
    sticky *= pulses * np.exp(-t * 3.2)
    # Soft tonal gurgle
    gurg = np.sin(2 * np.pi * (90 + 40 * np.sin(2 * np.pi * 6 * t)) * t)
    gurg *= np.exp(-t * 5) * 0.2
    sig = body * 0.7 + sticky * 0.55 + gurg
    return sig * fade(n, 0.005, 0.08) * 0.7


def wet_slap(rng: np.random.Generator, dur: float = 0.45) -> np.ndarray:
    """Heavy wet sole slap / crush contact."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    # Transient crack
    crack = highpass(noise(n, rng), 2000) * np.exp(-t * 90) * 0.9
    # Mid slap body
    slap = bandpass(noise(n, rng), 200, 1800) * np.exp(-t * 18)
    # Sub thump
    thump = np.sin(2 * np.pi * 55 * t) * np.exp(-t * 8)
    thump += np.sin(2 * np.pi * 90 * t) * np.exp(-t * 12) * 0.5
    # Wet bloom after contact
    bloom = lowpass(noise(n, rng), 350) * (1 - np.exp(-t * 40)) * np.exp(-t * 3.5) * 0.45
    squish = wet_squelch(rng, dur * 0.85) 
    # Align squish length
    if len(squish) < n:
        squish = np.pad(squish, (0, n - len(squish)))
    else:
        squish = squish[:n]
    sig = crack * 0.55 + slap * 0.7 + thump * 0.85 + bloom + squish * 0.55
    return sig * fade(n, 0.001, 0.12) * 0.95


def deep_crush(rng: np.random.Generator, dur: float = 0.8) -> np.ndarray:
    """Deep crushing pressure rumble."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    rumble = lowpass(noise(n, rng), 90) * (0.4 + 0.6 * np.exp(-t * 1.8))
    boom = np.sin(2 * np.pi * 42 * t) * np.exp(-t * 3.5)
    boom += np.sin(2 * np.pi * 28 * t) * np.exp(-t * 2.2) * 0.7
    # Slow pressure swell then settle
    env = np.clip(t / 0.08, 0, 1) * np.exp(-t * 1.4)
    creak = bandpass(noise(n, rng), 80, 400) * env * 0.25
    return (rumble * 0.55 + boom * 0.9 + creak) * fade(n, 0.01, 0.2) * 0.85


def soft_breath(rng: np.random.Generator, dur: float = 0.55) -> np.ndarray:
    """Soft smug breathy exhale (non-verbal)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    air = bandpass(noise(n, rng), 800, 4500)
    # Formant-ish shaping
    form = 0.5 + 0.5 * np.sin(2 * np.pi * 4.5 * t)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.2
    # Gentle pitch dip
    hum = np.sin(2 * np.pi * (180 - 30 * t / dur) * t) * 0.08 * env
    return (air * form * env * 0.22 + hum) * fade(n, 0.05, 0.12)


def soft_hum_smirk(rng: np.random.Generator, dur: float = 0.7) -> np.ndarray:
    """Quiet amused hmm under breath."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 210 + 18 * np.sin(2 * np.pi * 2.2 * t)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
    tone += 0.35 * np.sin(2 * np.pi * np.cumsum(f * 2) / SR)
    air = bandpass(noise(n, rng), 1000, 3500) * 0.15
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return (tone * 0.12 + air) * env * fade(n, 0.04, 0.1)


def place(dest: np.ndarray, src: np.ndarray, at_sec: float, gain: float = 1.0) -> None:
    start = int(at_sec * SR)
    end = start + len(src)
    if start >= len(dest):
        return
    if end > len(dest):
        src = src[: len(dest) - start]
        end = len(dest)
    dest[start:end] += src * gain


def build_bed(duration: float, impact_time: float) -> np.ndarray:
    rng = np.random.default_rng(117)
    n = int(duration * SR) + SR  # small pad
    bed = np.zeros(n, dtype=np.float64)

    # Quiet air bed
    bed += lowpass(noise(n, rng), 200) * 0.03

    # Approach whoosh building into descent
    place(bed, whoosh(1.1, rng, 700, 260), 0.35, 0.35)
    place(bed, whoosh(0.9, rng, 1100, 200), 1.5, 0.55)
    place(bed, whoosh(0.7, rng, 1400, 160), impact_time - 0.85, 0.75)

    # Sweaty micro-drips as sole gets close
    for i, t in enumerate(np.linspace(impact_time - 1.35, impact_time - 0.15, 9)):
        place(bed, wet_drip(rng, rng.uniform(0.08, 0.16)), float(t), 0.35 + 0.05 * i)

    # Sticky squelches while looming / sweaty reveal
    place(bed, wet_squelch(rng, 0.4), impact_time - 1.05, 0.55)
    place(bed, wet_squelch(rng, 0.32), impact_time - 0.55, 0.7)
    place(bed, wet_squelch(rng, 0.28), impact_time - 0.28, 0.85)

    # Soft smug breath just before crush
    place(bed, soft_breath(rng, 0.5), impact_time - 0.95, 0.9)
    place(bed, soft_hum_smirk(rng, 0.65), impact_time - 0.55, 0.7)

    # IMPACT
    place(bed, wet_slap(rng, 0.5), impact_time, 1.15)
    place(bed, deep_crush(rng, 0.95), impact_time, 1.0)
    place(bed, wet_squelch(rng, 0.55), impact_time + 0.05, 0.95)

    # Post-crush press / sweaty smother squirm
    for i, t in enumerate(np.linspace(impact_time + 0.25, impact_time + 1.4, 6)):
        place(bed, wet_squelch(rng, rng.uniform(0.25, 0.45)), float(t), 0.55 - i * 0.05)
        place(bed, wet_drip(rng, 0.1), float(t) + 0.08, 0.25)

    place(bed, deep_crush(rng, 1.1), impact_time + 0.35, 0.55)
    place(bed, soft_breath(rng, 0.7), impact_time + 0.5, 0.55)

    # Soft low rumble under smother
    smother_n = int(1.6 * SR)
    smother_t = np.arange(smother_n) / SR
    smother = lowpass(noise(smother_n, rng), 70) * (0.2 + 0.8 * np.exp(-smother_t * 0.9))
    place(bed, smother * fade(smother_n, 0.05, 0.4), impact_time + 0.2, 0.45)

    # Normalize softly
    peak = np.max(np.abs(bed)) + 1e-9
    bed = bed / peak * 0.92
    # Trim to duration
    out_n = int(duration * SR)
    return bed[:out_n]


def main() -> None:
    # Default duration/impact — make_video overrides via args if needed
    import argparse

    p = argparse.ArgumentParser()
    p.add_argument("--duration", type=float, default=6.2)
    p.add_argument("--impact", type=float, default=3.55)
    p.add_argument("--out", type=Path, default=AUDIO_DIR / "crush_bed.wav")
    args = p.parse_args()

    bed = build_bed(args.duration, args.impact)
    write_wav(args.out, bed)
    print(f"Wrote {args.out} ({args.duration:.2f}s, impact@{args.impact:.2f}s)")


if __name__ == "__main__":
    main()
