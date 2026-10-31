#!/usr/bin/env python3
"""Assemble Echidna crush keyframes into a smooth POV video."""

from __future__ import annotations

import math
import subprocess
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

SRC = Path("/opt/cursor/artifacts/assets")
OUT_DIR = Path("/workspace/echidna-crush/frames")
VIDEO_DIR = Path("/workspace/echidna-crush/out")
ARTIFACT = Path("/opt/cursor/artifacts/echidna_sole_crush.mp4")

W, H = 720, 960  # 3:4
FPS = 30

# Keyframe paths in order
KEYS = [
    SRC / "crush_01_approach.jpg",
    SRC / "crush_02_descend.jpg",
    SRC / "crush_03_loom.jpg",
    SRC / "crush_04_fill.jpg",
    SRC / "crush_05_impact.jpg",
    SRC / "crush_06_smother.jpg",
]

# Segment durations in seconds (hold on approach, accelerate into crush)
SEGMENT_SECS = [1.0, 0.75, 0.6, 0.55, 0.55, 1.1]
CROSSFADE_SECS = [0.32, 0.26, 0.2, 0.16, 0.2]


def ease_in_cubic(t: float) -> float:
    return t * t * t


def ease_in_quad(t: float) -> float:
    return t * t


def ease_out_cubic(t: float) -> float:
    return 1 - (1 - t) ** 3


def load_fit(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    # Cover-fit into W x H
    scale = max(W / im.width, H / im.height)
    nw, nh = int(im.width * scale + 0.5), int(im.height * scale + 0.5)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - W) // 2
    top = (nh - H) // 2
    return im.crop((left, top, left + W, top + H))


def zoom_crop(im: Image.Image, zoom: float, cx: float = 0.5, cy: float = 0.55) -> Image.Image:
    """Zoom into image around (cx, cy) normalized center. zoom >= 1."""
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
    """amount 0=no change, 1=black."""
    amount = max(0.0, min(1.0, amount))
    return ImageEnhance.Brightness(im).enhance(1.0 - amount * 0.85)


def shake_offset(frame_i: int, intensity: float) -> tuple[int, int]:
    if intensity <= 0:
        return 0, 0
    # Stronger deterministic pseudo-shake for crush impact
    ox = int(math.sin(frame_i * 3.4) * intensity * 28 + math.sin(frame_i * 7.1) * intensity * 10)
    oy = int(math.cos(frame_i * 4.2) * intensity * 22 + math.cos(frame_i * 9.3) * intensity * 8)
    return ox, oy


def apply_offset(im: Image.Image, ox: int, oy: int) -> Image.Image:
    if ox == 0 and oy == 0:
        return im
    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    canvas.paste(im, (ox, oy))
    return canvas


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    VIDEO_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob("frame_*.png"):
        old.unlink()

    images = [load_fit(p) for p in KEYS]
    frames: list[Image.Image] = []

    # Precompute per-segment frame counts
    seg_frames = [max(1, int(s * FPS)) for s in SEGMENT_SECS]
    fade_frames = [max(1, int(s * FPS)) for s in CROSSFADE_SECS]

    # Build timeline: for each segment, hold/advance with zoom, then crossfade
    # Overall zoom progression across the whole sequence
    total_progress_zooms = [1.0, 1.08, 1.18, 1.35, 1.55, 1.75]

    for si, img in enumerate(images):
        n = seg_frames[si]
        z0 = total_progress_zooms[si]
        z1 = total_progress_zooms[min(si + 1, len(total_progress_zooms) - 1)]
        # During last segment, stay zoomed and darken
        for fi in range(n):
            t = fi / max(1, n - 1)
            # Accelerate zoom more on later segments
            if si >= 3:
                te = ease_in_cubic(t)
            elif si >= 1:
                te = ease_in_quad(t)
            else:
                te = t * 0.5  # slow start
            zoom = z0 + (z1 - z0) * te
            # Bias crop center toward ball of foot / center-lower
            cy = 0.52 + 0.06 * (si / (len(images) - 1))
            frame = zoom_crop(img, zoom, cx=0.5, cy=cy)

            # Keep sole readable on impact; darken mainly on smother
            if si == 3:
                frame = darken(frame, 0.04 * te)
            elif si == 4:
                # Brief dark pulse at contact, then stay readable
                pulse = abs(math.sin(te * math.pi)) * 0.18
                frame = darken(frame, pulse)
            elif si == 5:
                frame = darken(frame, 0.25 + 0.6 * te)

            # Impact shake: sharp hit on segment 4, residual on 5
            shake = 0.0
            if si == 4:
                # Peak shake at start of contact, then decay
                shake = 1.15 * (1.0 - ease_out_cubic(te) * 0.55)
            elif si == 5 and t < 0.45:
                shake = (1.0 - t / 0.45) * 0.7
            ox, oy = shake_offset(len(frames), shake)
            frame = apply_offset(frame, ox, oy)

            # Soft blur flash only at the first instant of impact
            if si == 4 and te < 0.18:
                frame = frame.filter(ImageFilter.GaussianBlur(radius=1.8 * (1 - te / 0.18)))
            elif si == 5 and te > 0.4:
                # Progressive smother blur
                frame = frame.filter(ImageFilter.GaussianBlur(radius=2.5 * ((te - 0.4) / 0.6)))

            frames.append(frame)

        # Crossfade into next keyframe
        if si < len(images) - 1:
            nf = fade_frames[si]
            next_img = images[si + 1]
            z_a = z1
            z_b = total_progress_zooms[si + 1]
            for fi in range(nf):
                t = (fi + 1) / (nf + 1)
                te = ease_out_cubic(t) if si < 3 else ease_in_quad(t)
                a = zoom_crop(img, z_a + (z_b - z_a) * te * 0.3, cx=0.5, cy=0.55)
                b = zoom_crop(next_img, z_b * (0.95 + 0.05 * te), cx=0.5, cy=0.55)
                frame = blend(a, b, te)
                if si >= 3:
                    frame = darken(frame, 0.08 * te)
                frames.append(frame)

    # Write numbered frames
    print(f"Writing {len(frames)} frames @ {FPS}fps ({len(frames)/FPS:.2f}s)...")
    for i, fr in enumerate(frames):
        fr.save(OUT_DIR / f"frame_{i:04d}.png", optimize=True)

    raw_mp4 = VIDEO_DIR / "echidna_sole_crush_raw.mp4"
    final_mp4 = VIDEO_DIR / "echidna_sole_crush.mp4"

    # Encode with ffmpeg
    cmd = [
        "ffmpeg", "-y",
        "-framerate", str(FPS),
        "-i", str(OUT_DIR / "frame_%04d.png"),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-preset", "medium",
        "-movflags", "+faststart",
        str(raw_mp4),
    ]
    subprocess.run(cmd, check=True)

    # Light vignette + subtle contrast via ffmpeg filters for polish
    vf = (
        "eq=contrast=1.05:saturation=1.08:brightness=0.01,"
        "vignette=PI/5"
    )
    cmd2 = [
        "ffmpeg", "-y",
        "-i", str(raw_mp4),
        "-vf", vf,
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-preset", "medium",
        "-movflags", "+faststart",
        str(final_mp4),
    ]
    subprocess.run(cmd2, check=True)

    ARTIFACT.parent.mkdir(parents=True, exist_ok=True)
    ARTIFACT.write_bytes(final_mp4.read_bytes())
    print(f"Wrote {final_mp4} and {ARTIFACT}")
    print(f"Size: {ARTIFACT.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()
