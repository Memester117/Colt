#!/usr/bin/env python3
"""Clean, quiet crush + sweaty-sole SFX — sparse hits, no noisy bed."""

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
    if ni < n:
        env[:ni] *= np.linspace(0, 1, ni)
    if no < n:
        env[-no:] *= np.linspace(1, 0, no)
    return env


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n).astype(np.float64)


def lowpass(x: np.ndarray, cutoff_hz: float, passes: int = 2) -> np.ndarray:
    """Multi-pass one-pole lowpass (gentler than single pass)."""
    y = x.astype(np.float64, copy=True)
    for _ in range(passes):
        rc = 1.0 / (2 * np.pi * max(cutoff_hz, 1.0))
        a = (1.0 / SR) / (rc + 1.0 / SR)
        acc = 0.0
        out = np.empty_like(y)
        for i, v in enumerate(y):
            acc += a * (v - acc)
            out[i] = acc
        y = out
    return y


def highpass(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    return x - lowpass(x, cutoff_hz, passes=1)


def write_wav(path: Path, mono: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    clipped = np.clip(mono, -1.0, 1.0)
    pcm = (clipped * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())


def soft_air(dur: float, rng: np.random.Generator) -> np.ndarray:
    """Very soft filtered air for foot descending — barely there."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = lowpass(noise(n, rng), 600, passes=3)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    return sig * env * 0.045


def wet_tap(rng: np.random.Generator) -> np.ndarray:
    """Soft sweaty skin tap / droplet — mostly tonal, little noise."""
    dur = rng.uniform(0.06, 0.11)
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(380, 720)
    tone = np.sin(2 * np.pi * f0 * t) * np.exp(-t * 38)
    tone += 0.35 * np.sin(2 * np.pi * f0 * 1.7 * t) * np.exp(-t * 50)
    # tiny soft tick
    tick = lowpass(noise(n, rng), 1800, passes=2) * np.exp(-t * 70) * 0.12
    return (tone * 0.22 + tick) * fade(n, 0.001, 0.03)


def wet_press(rng: np.random.Generator, dur: float = 0.28) -> np.ndarray:
    """Soft sticky press of damp sole — muted, no harsh noise."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    # low soft body
    body = lowpass(noise(n, rng), 180, passes=3) * np.exp(-t * 5.5)
    # gentle mid “peel”
    peel_f = 120 + 40 * np.sin(2 * np.pi * 5 * t)
    peel = np.sin(2 * np.pi * np.cumsum(peel_f) / SR) * np.exp(-t * 4.0) * 0.08
    env = fade(n, 0.01, 0.08) * (0.55 + 0.45 * np.sin(np.pi * np.clip(t / dur, 0, 1)))
    return (body * 0.18 + peel) * env


def soft_thud(rng: np.random.Generator) -> np.ndarray:
    """Quiet fleshy impact — sub + soft mid, no crack/hiss."""
    dur = 0.55
    n = int(dur * SR)
    t = np.arange(n) / SR
    # pitched thump
    thud = np.sin(2 * np.pi * 48 * t) * np.exp(-t * 7.5)
    thud += 0.55 * np.sin(2 * np.pi * 72 * t) * np.exp(-t * 10)
    thud += 0.25 * np.sin(2 * np.pi * 110 * t) * np.exp(-t * 16)
    # soft flesh pad (heavily filtered)
    pad = lowpass(noise(n, rng), 220, passes=3) * np.exp(-t * 9) * 0.22
    # short wet kiss on contact
    kiss_n = int(0.12 * SR)
    kiss_t = np.arange(kiss_n) / SR
    kiss = np.sin(2 * np.pi * 260 * kiss_t) * np.exp(-kiss_t * 28) * 0.12
    kiss = np.pad(kiss, (0, n - kiss_n))
    sig = (thud * 0.42 + pad + kiss) * fade(n, 0.002, 0.12)
    return sig


def soft_breath(rng: np.random.Generator, dur: float = 0.45) -> np.ndarray:
    """Very quiet breathy exhale — non-verbal, soft."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    air = lowpass(highpass(noise(n, rng), 400), 2800, passes=2)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.6
    return air * env * 0.035


def place(dest: np.ndarray, src: np.ndarray, at_sec: float, gain: float = 1.0) -> None:
    start = int(at_sec * SR)
    if start >= len(dest):
        return
    end = min(len(dest), start + len(src))
    dest[start:end] += src[: end - start] * gain


def build_bed(duration: float, impact_time: float) -> np.ndarray:
    """Sparse, quiet, clean bed — silence + a few soft events."""
    rng = np.random.default_rng(42)
    n = int(duration * SR)
    bed = np.zeros(n, dtype=np.float64)

    # Soft descent air (quiet)
    place(bed, soft_air(0.9, rng), max(0.0, impact_time - 2.2), 0.7)
    place(bed, soft_air(0.7, rng), max(0.0, impact_time - 1.15), 0.85)

    # A few sweaty micro-taps as sole looms
    for t in (impact_time - 1.2, impact_time - 0.85, impact_time - 0.55, impact_time - 0.28):
        if t > 0.05:
            place(bed, wet_tap(rng), t, 0.55)

    # Soft sticky presses around sweaty reveal
    place(bed, wet_press(rng, 0.32), max(0.05, impact_time - 0.95), 0.5)
    place(bed, wet_press(rng, 0.26), max(0.05, impact_time - 0.4), 0.6)

    # Quiet breath before crush
    place(bed, soft_breath(rng, 0.4), max(0.05, impact_time - 0.7), 0.7)

    # Impact — soft thud + one wet press (no rumble bed, no slap crack)
    place(bed, soft_thud(rng), impact_time, 1.0)
    place(bed, wet_press(rng, 0.35), impact_time + 0.02, 0.65)

    # Mild post-crush presses while smothering
    place(bed, wet_press(rng, 0.3), impact_time + 0.45, 0.4)
    place(bed, wet_tap(rng), impact_time + 0.7, 0.35)
    place(bed, soft_breath(rng, 0.5), impact_time + 0.55, 0.45)

    # Keep overall quiet — peak around ~0.28
    peak = float(np.max(np.abs(bed))) + 1e-9
    bed = bed / peak * 0.28
    return bed


def main() -> None:
    import argparse

    p = argparse.ArgumentParser()
    p.add_argument("--duration", type=float, default=6.0)
    p.add_argument("--impact", type=float, default=4.41)
    p.add_argument("--out", type=Path, default=AUDIO_DIR / "crush_bed.wav")
    args = p.parse_args()
    bed = build_bed(args.duration, args.impact)
    write_wav(args.out, bed)
    print(f"Wrote {args.out} ({args.duration:.2f}s, impact@{args.impact:.2f}s, peak={np.max(np.abs(bed)):.3f})")


if __name__ == "__main__":
    main()
