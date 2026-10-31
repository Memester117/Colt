#!/usr/bin/env python3
"""Assemble Echidna crush keyframes into a smooth POV video with SFX."""

from __future__ import annotations

import math
import subprocess
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

from make_sfx import build_bed, write_wav

SRC = Path("/opt/cursor/artifacts/assets")
KEY_DIR = Path("/workspace/echidna-crush/keyframes")
OUT_DIR = Path("/workspace/echidna-crush/frames")
VIDEO_DIR = Path("/workspace/echidna-crush/out")
AUDIO_DIR = Path("/workspace/echidna-crush/audio")
ARTIFACT = Path("/opt/cursor/artifacts/echidna_sole_crush.mp4")
DEMO = Path("/opt/cursor/artifacts/recording_demo.mp4")

W, H = 720, 960  # 3:4
FPS = 30

# Keyframe paths in order (local keyframes preferred)
def resolve(name: str) -> Path:
    local = KEY_DIR / name
    art = SRC / name
    if local.exists():
        return local
    return art


KEYS = [
    resolve("crush_01_approach.jpg"),
    resolve("crush_02_descend.jpg"),
    resolve("crush_03_loom.jpg"),
    resolve("crush_04_fill.jpg"),
    resolve("crush_04b_sweaty.jpg"),  # new sweaty sole macro
    resolve("crush_05_impact.jpg"),
    resolve("crush_06_smother.jpg"),
]

# Segment durations in seconds
SEGMENT_SECS = [0.95, 0.7, 0.55, 0.45, 0.7, 0.5, 1.05]
CROSSFADE_SECS = [0.3, 0.24, 0.18, 0.16, 0.18, 0.18]


def ease_in_cubic(t: float) -> float:
    return t * t * t


def ease_in_quad(t: float) -> float:
    return t * t


def ease_out_cubic(t: float) -> float:
    return 1 - (1 - t) ** 3


def load_fit(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    scale = max(W / im.width, H / im.height)
    nw, nh = int(im.width * scale + 0.5), int(im.height * scale + 0.5)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - W) // 2
    top = (nh - H) // 2
    return im.crop((left, top, left + W, top + H))


def zoom_crop(im: Image.Image, zoom: float, cx: float = 0.5, cy: float = 0.55) -> Image.Image:
    zoom = max(1.0, zoom)
    sw, sh = im.size
    cw, ch = int(sw / zoom), int(sh / zoom)
    cx_px = int(cx * sw)
    cy_px = int(cy * sh)
    left = max(0, min(sw - cw, cx_px - cw // 2))
    top = max(0, min(sh - ch, cy_px - ch // 2))
    cropped = im.crop((left, top, left + cw, top + ch))
    return cropped.resize((W, H), Image.Resampling.LANCZOS)


def blend(a: Image.Image, b: Image.Image, t: float) -> Image.Image:
    t = max(0.0, min(1.0, t))
    return Image.blend(a, b, t)


def darken(im: Image.Image, amount: float) -> Image.Image:
    amount = max(0.0, min(1.0, amount))
    return ImageEnhance.Brightness(im).enhance(1.0 - amount * 0.85)


def shake_offset(frame_i: int, intensity: float) -> tuple[int, int]:
    if intensity <= 0:
        return 0, 0
    ox = int(math.sin(frame_i * 3.4) * intensity * 28 + math.sin(frame_i * 7.1) * intensity * 10)
    oy = int(math.cos(frame_i * 4.2) * intensity * 22 + math.cos(frame_i * 9.3) * intensity * 8)
    return ox, oy


def apply_offset(im: Image.Image, ox: int, oy: int) -> Image.Image:
    if ox == 0 and oy == 0:
        return im
    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    canvas.paste(im, (ox, oy))
    return canvas


def segment_start_times() -> list[float]:
    """Cumulative start time of each segment including prior fades."""
    starts = [0.0]
    t = 0.0
    for i, seg in enumerate(SEGMENT_SECS):
        t += seg
        if i < len(CROSSFADE_SECS):
            t += CROSSFADE_SECS[i]
        starts.append(t)
    return starts


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    VIDEO_DIR.mkdir(parents=True, exist_ok=True)
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob("frame_*.png"):
        old.unlink()

    missing = [p for p in KEYS if not p.exists()]
    if missing:
        raise SystemExit(f"Missing keyframes: {missing}")

    images = [load_fit(p) for p in KEYS]
    frames: list[Image.Image] = []

    seg_frames = [max(1, int(s * FPS)) for s in SEGMENT_SECS]
    fade_frames = [max(1, int(s * FPS)) for s in CROSSFADE_SECS]

    # Zoom progression: sweaty macro should feel closest before impact
    total_progress_zooms = [1.0, 1.08, 1.18, 1.32, 1.48, 1.62, 1.78]

    # Index map:
    # 0 approach, 1 descend, 2 loom, 3 fill, 4 sweaty, 5 impact, 6 smother
    sweaty_i = 4
    impact_i = 5
    smother_i = 6

    for si, img in enumerate(images):
        n = seg_frames[si]
        z0 = total_progress_zooms[si]
        z1 = total_progress_zooms[min(si + 1, len(total_progress_zooms) - 1)]
        for fi in range(n):
            t = fi / max(1, n - 1)
            if si >= sweaty_i:
                te = ease_in_cubic(t)
            elif si >= 1:
                te = ease_in_quad(t)
            else:
                te = t * 0.5
            zoom = z0 + (z1 - z0) * te
            cy = 0.50 + 0.08 * (si / (len(images) - 1))
            # Bias sweaty sole toward ball/toes
            if si == sweaty_i:
                cy = 0.42 + 0.08 * te
            frame = zoom_crop(img, zoom, cx=0.5, cy=cy)

            if si == 3:
                frame = darken(frame, 0.03 * te)
            elif si == sweaty_i:
                frame = darken(frame, 0.06 * te)
            elif si == impact_i:
                pulse = abs(math.sin(te * math.pi)) * 0.18
                frame = darken(frame, pulse)
            elif si == smother_i:
                frame = darken(frame, 0.25 + 0.6 * te)

            shake = 0.0
            if si == impact_i:
                shake = 1.2 * (1.0 - ease_out_cubic(te) * 0.55)
            elif si == smother_i and t < 0.45:
                shake = (1.0 - t / 0.45) * 0.75
            elif si == sweaty_i and te > 0.7:
                # Subtle tremble as sweaty sole looms
                shake = (te - 0.7) / 0.3 * 0.25
            ox, oy = shake_offset(len(frames), shake)
            frame = apply_offset(frame, ox, oy)

            if si == impact_i and te < 0.18:
                frame = frame.filter(ImageFilter.GaussianBlur(radius=1.8 * (1 - te / 0.18)))
            elif si == smother_i and te > 0.4:
                frame = frame.filter(ImageFilter.GaussianBlur(radius=2.5 * ((te - 0.4) / 0.6)))

            frames.append(frame)

        if si < len(images) - 1:
            nf = fade_frames[si]
            next_img = images[si + 1]
            z_a = z1
            z_b = total_progress_zooms[si + 1]
            for fi in range(nf):
                t = (fi + 1) / (nf + 1)
                te = ease_out_cubic(t) if si < sweaty_i else ease_in_quad(t)
                a = zoom_crop(img, z_a + (z_b - z_a) * te * 0.3, cx=0.5, cy=0.52)
                b = zoom_crop(next_img, z_b * (0.95 + 0.05 * te), cx=0.5, cy=0.48 if si + 1 == sweaty_i else 0.55)
                frame = blend(a, b, te)
                if si >= 3:
                    frame = darken(frame, 0.08 * te)
                frames.append(frame)

    duration = len(frames) / FPS
    starts = segment_start_times()
    impact_time = starts[impact_i]
    print(f"Writing {len(frames)} frames @ {FPS}fps ({duration:.2f}s), impact@{impact_time:.2f}s...")
    for i, fr in enumerate(frames):
        fr.save(OUT_DIR / f"frame_{i:04d}.png", optimize=True)

    # Quiet clean stereo SFX (no loudnorm / no noisy maximize)
    import numpy as np
    import wave as _wave

    wav_path = AUDIO_DIR / "crush_bed.wav"
    stereo_path = AUDIO_DIR / "crush_bed_stereo.wav"
    bed = build_bed(duration, impact_time)
    write_wav(wav_path, bed)

    left = bed
    right = bed * 0.96
    stereo = np.stack([left, right], axis=1)
    pcm = (np.clip(stereo, -1, 1) * 32767.0).astype(np.int16)
    with _wave.open(str(stereo_path), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(44100)
        wf.writeframes(pcm.tobytes())
    print(f"SFX bed -> {stereo_path} (peak={float(np.max(np.abs(bed))):.3f})")

    raw_mp4 = VIDEO_DIR / "echidna_sole_crush_silent.mp4"
    final_mp4 = VIDEO_DIR / "echidna_sole_crush.mp4"

    subprocess.run(
        [
            "ffmpeg", "-y",
            "-framerate", str(FPS),
            "-i", str(OUT_DIR / "frame_%04d.png"),
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-crf", "18",
            "-preset", "medium",
            "-an",
            "-movflags", "+faststart",
            str(raw_mp4),
        ],
        check=True,
    )

    # Color grade + quiet stereo AAC (no gain boost)
    subprocess.run(
        [
            "ffmpeg", "-y",
            "-i", str(raw_mp4),
            "-i", str(stereo_path),
            "-filter_complex",
            "[0:v]eq=contrast=1.05:saturation=1.08:brightness=0.01,vignette=PI/5[v];"
            "[1:a]volume=0.7[a]",
            "-map", "[v]",
            "-map", "[a]",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-crf", "18",
            "-preset", "medium",
            "-c:a", "aac",
            "-profile:a", "aac_low",
            "-b:a", "192k",
            "-ac", "2",
            "-ar", "44100",
            "-shortest",
            "-movflags", "+faststart",
            "-disposition:a:0", "default",
            str(final_mp4),
        ],
        check=True,
    )

    mp3_path = VIDEO_DIR / "echidna_sole_crush_sfx.mp3"
    subprocess.run(
        [
            "ffmpeg", "-y",
            "-i", str(stereo_path),
            "-filter:a", "volume=0.7",
            "-c:a", "libmp3lame",
            "-b:a", "160k",
            str(mp3_path),
        ],
        check=True,
    )
    Path("/opt/cursor/artifacts/echidna_sole_crush_sfx.mp3").write_bytes(mp3_path.read_bytes())

    ARTIFACT.parent.mkdir(parents=True, exist_ok=True)
    data = final_mp4.read_bytes()
    ARTIFACT.write_bytes(data)
    DEMO.write_bytes(data)
    print(f"Wrote {final_mp4} and {ARTIFACT}")
    print(f"Size: {ARTIFACT.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()
