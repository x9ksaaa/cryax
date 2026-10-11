from __future__ import annotations

import io
import math
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageSequence

MAX_UPLOAD_BYTES = 8 * 1024 * 1024
MAX_FRAMES = 48
ICON_MAX = (128, 128)
BG_MAX = (512, 256)
PREVIEW_SIZE = (420, 72)


@dataclass
class ProcessedImage:
    static_png: bytes
    frames_png: list[bytes]
    delay: float
    animated: bool
    source_kind: str
    filename: str = ""


class ImageError(ValueError):
    pass


def sniff_kind(data: bytes) -> str:
    if data[:6] in (b"GIF87a", b"GIF89a"):
        return "gif"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"
    if data[:2] == b"\xff\xd8":
        return "jpg"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    return "unknown"


def _png_bytes(image: Image.Image) -> bytes:
    buf = io.BytesIO()
    image.convert("RGBA").save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def _fit(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    image = image.convert("RGBA")
    image.thumbnail(max_size, Image.Resampling.LANCZOS)
    return image


def _ffmpeg_frames(data: bytes) -> list[bytes]:
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "in.bin"
        src.write_bytes(data)
        pattern = Path(tmp) / "frame_%03d.png"
        result = subprocess.run(
            ["ffmpeg", "-y", "-i", str(src), "-vsync", "0", str(pattern)],
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            raise ImageError("ffmpeg could not split that animation")
        frames: list[bytes] = []
        for path in sorted(Path(tmp).glob("frame_*.png")):
            frames.append(path.read_bytes())
        return frames


def _pillow_frames(data: bytes, max_size: tuple[int, int]) -> tuple[list[bytes], float]:
    image = Image.open(io.BytesIO(data))
    n_frames = getattr(image, "n_frames", 1) or 1
    durations: list[float] = []
    raw_frames: list[Image.Image] = []
    for index, frame in enumerate(ImageSequence.Iterator(image)):
        duration_ms = frame.info.get("duration", 80) or 80
        durations.append(max(30, float(duration_ms)) / 1000.0)
        raw_frames.append(_fit(frame, max_size))
        if index + 1 >= 128:
            break
    if not raw_frames:
        raise ImageError("no frames in image")
    if len(raw_frames) > MAX_FRAMES:
        step = math.ceil(len(raw_frames) / MAX_FRAMES)
        raw_frames = raw_frames[::step][:MAX_FRAMES]
        durations = durations[::step][:MAX_FRAMES]
    pngs = [_png_bytes(frame) for frame in raw_frames]
    delay = sum(durations) / len(durations) if durations else 0.08
    delay = min(2.0, max(0.03, delay))
    return pngs, delay


def process_upload(data: bytes, kind: str) -> ProcessedImage:
    if not data:
        raise ImageError("empty file")
    if len(data) > MAX_UPLOAD_BYTES:
        raise ImageError("file is larger than 8 MB")
    source = sniff_kind(data)
    if source == "unknown":
        raise ImageError("use a PNG, JPG, or GIF")
    max_size = ICON_MAX if kind == "icon" else BG_MAX
    frames: list[bytes] = []
    delay = 0.08
    animated = source in {"gif", "webp"}
    try:
        frames, delay = _pillow_frames(data, max_size)
    except Exception:
        frames = []
    if animated and len(frames) < 2:
        try:
            ffmpeg_pngs = _ffmpeg_frames(data)
            fitted: list[bytes] = []
            for blob in ffmpeg_pngs[:128]:
                frame = _fit(Image.open(io.BytesIO(blob)), max_size)
                fitted.append(_png_bytes(frame))
            if len(fitted) > MAX_FRAMES:
                step = math.ceil(len(fitted) / MAX_FRAMES)
                fitted = fitted[::step][:MAX_FRAMES]
            if fitted:
                frames = fitted
        except Exception:
            pass
    if not frames:
        raise ImageError("could not read that image")
    # Roblox cannot display GIF/WEBP. Always persist PNG frames.
    static = frames[0]
    is_anim = len(frames) > 1
    return ProcessedImage(
        static_png=static,
        frames_png=frames if is_anim else [static],
        delay=delay if is_anim else 0.08,
        animated=is_anim,
        source_kind=source,
    )


def hex_to_rgba(value: str, fallback: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    clean = (value or "").strip().lstrip("#")
    if len(clean) == 6:
        try:
            r = int(clean[0:2], 16)
            g = int(clean[2:4], 16)
            b = int(clean[4:6], 16)
            return (r, g, b, 255)
        except ValueError:
            return fallback
    return fallback


def render_preview(
    display_name: str,
    username: str,
    outline: str,
    text_color: str,
    background: str,
    icon_png: bytes | None,
    bg_png: bytes | None,
    staff: bool,
    shape: str = "Pill",
    glitch: bool = False,
    verified_badge: bool = False,
) -> bytes:
    width, height = PREVIEW_SIZE
    radius = 36
    lowered = str(shape or "Pill").strip().lower()
    if lowered == "square":
        radius = 6
    elif lowered == "rounded":
        radius = 16
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    fill = Image.new("RGBA", (width, height), hex_to_rgba(background, (16, 16, 24, 255)))
    if bg_png:
        try:
            bg = Image.open(io.BytesIO(bg_png)).convert("RGBA")
            bg = bg.resize((width, height), Image.Resampling.LANCZOS)
            fill = Image.alpha_composite(fill, bg)
        except Exception:
            pass
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    canvas.paste(fill, (0, 0), mask)
    draw = ImageDraw.Draw(canvas)
    stroke = hex_to_rgba(outline, (0, 0, 0, 255))
    draw.rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, outline=stroke, width=2)
    try:
        font_name = ImageFont.truetype("DejaVuSans-Bold.ttf", 18)
        font_user = ImageFont.truetype("DejaVuSans.ttf", 12)
    except OSError:
        font_name = ImageFont.load_default()
        font_user = font_name
    icon_box = 48
    pad = 10
    if icon_png:
        try:
            icon = Image.open(io.BytesIO(icon_png)).convert("RGBA")
            icon.thumbnail((icon_box, icon_box), Image.Resampling.LANCZOS)
            x = pad + (icon_box - icon.width) // 2
            y = (height - icon.height) // 2
            canvas.paste(icon, (x, y), icon)
        except Exception:
            pass
    text_x = pad + icon_box + 10
    fill = hex_to_rgba(text_color, (255, 255, 255, 255))
    stroke = hex_to_rgba(outline, (0, 0, 0, 255))
    label = display_name or username or "nametag"
    if staff and not label.lower().startswith("[staff]"):
        label = f"[STAFF] {label}"
    if glitch:
        draw.text((text_x - 2, 16), label, font=font_name, fill=(255, 70, 90, 180))
        draw.text((text_x + 2, 16), label, font=font_name, fill=(80, 220, 255, 180))
    draw.text(
        (text_x, 16),
        label,
        font=font_name,
        fill=fill,
        stroke_width=2,
        stroke_fill=stroke,
    )
    if verified_badge:
        try:
            bbox = draw.textbbox((text_x, 16), label, font=font_name, stroke_width=2)
            bx = int(bbox[2]) + 6
        except Exception:
            bx = text_x + max(24, 8 * len(label)) + 6
        draw_verified_badge(draw, bx, 18, 16)
    draw.text((text_x, 42), f"@{username}" if username else "", font=font_user, fill=(220, 220, 228, 255))
    return _png_bytes(canvas)


def draw_verified_badge(draw: ImageDraw.ImageDraw, x: int, y: int, size: int = 16) -> None:
    radius = max(3, round(size * 0.22))
    draw.rounded_rectangle((x, y, x + size - 1, y + size - 1), radius=radius, fill=(0, 102, 255, 255))
    stroke = max(2, size // 7)
    w = float(size)
    draw.line(
        [
            (x + w * 0.20, y + w * 0.50),
            (x + w * 0.40, y + w * 0.70),
            (x + w * 0.78, y + w * 0.28),
        ],
        fill=(255, 255, 255, 255),
        width=stroke,
    )
