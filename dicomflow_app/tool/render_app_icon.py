#!/usr/bin/env python3
"""Rasterize the in-app BrandMark into platform launcher icons (stdlib only)."""

from __future__ import annotations

import struct
import subprocess
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAC_DIR = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID_RES = ROOT / "android/app/src/main/res"
WIN_ICO = ROOT / "windows/runner/resources/app_icon.ico"

C0 = (37, 99, 235)
C1 = (249, 115, 22)


def lerp(a: int, b: int, t: float) -> int:
    return int(round(a + (b - a) * t))


def write_png(path: Path, size: int, rgba: bytes) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + rgba[y * size * 4 : (y + 1) * size * 4] for y in range(size))
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def set_pixel(buf: bytearray, size: int, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < size and 0 <= y < size:
        i = (y * size + x) * 4
        buf[i : i + 4] = bytes(color)


def blend_pixel(buf: bytearray, size: int, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if not (0 <= x < size and 0 <= y < size):
        return
    a = color[3] / 255.0
    if a <= 0:
        return
    i = (y * size + x) * 4
    r, g, b = buf[i], buf[i + 1], buf[i + 2]
    buf[i] = int(round(r * (1 - a) + color[0] * a))
    buf[i + 1] = int(round(g * (1 - a) + color[1] * a))
    buf[i + 2] = int(round(b * (1 - a) + color[2] * a))
    buf[i + 3] = 255


def fill_circle(buf: bytearray, size: int, cx: float, cy: float, radius: float, color: tuple[int, int, int, int]) -> None:
    r0 = int(cx - radius) - 1
    r1 = int(cx + radius) + 1
    for y in range(r0, r1 + 1):
        for x in range(r0, r1 + 1):
            d = ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5
            coverage = max(0.0, min(1.0, radius + 0.5 - d))
            if coverage > 0:
                blend_pixel(buf, size, x, y, (color[0], color[1], color[2], int(round(color[3] * coverage))))


def stroke_circle(buf: bytearray, size: int, cx: float, cy: float, radius: float, width: float) -> None:
    half = width / 2
    r0 = int(cx - radius - half) - 1
    r1 = int(cx + radius + half) + 1
    for y in range(r0, r1 + 1):
        for x in range(r0, r1 + 1):
            d = abs((((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5) - radius)
            coverage = max(0.0, min(1.0, half + 0.5 - d))
            if coverage > 0:
                blend_pixel(buf, size, x, y, (255, 255, 255, int(round(255 * coverage))))


def stroke_line(buf: bytearray, size: int, x0: float, y0: float, x1: float, y1: float, width: float) -> None:
    dx = x1 - x0
    dy = y1 - y0
    length = max((dx * dx + dy * dy) ** 0.5, 1e-6)
    ux, uy = dx / length, dy / length
    half = width / 2
    pad = half + 1
    xmin = int(min(x0, x1) - pad)
    xmax = int(max(x0, x1) + pad)
    ymin = int(min(y0, y1) - pad)
    ymax = int(max(y0, y1) + pad)
    for y in range(ymin, ymax + 1):
        for x in range(xmin, xmax + 1):
            px, py = x + 0.5 - x0, y + 0.5 - y0
            t = max(0.0, min(1.0, (px * ux + py * uy) / length))
            qx, qy = t * dx - px, t * dy - py
            d = (qx * qx + qy * qy) ** 0.5
            coverage = max(0.0, min(1.0, half + 0.5 - d))
            if coverage > 0:
                blend_pixel(buf, size, x, y, (255, 255, 255, int(round(255 * coverage))))
    fill_circle(buf, size, x0, y0, half, (255, 255, 255, 255))
    fill_circle(buf, size, x1, y1, half, (255, 255, 255, 255))


def raster_master(size: int = 1024) -> bytes:
    buf = bytearray(size * size * 4)
    denom = max(1, 2 * (size - 1))
    for y in range(size):
        for x in range(size):
            t = (x + y) / denom
            i = (y * size + x) * 4
            buf[i] = lerp(C0[0], C1[0], t)
            buf[i + 1] = lerp(C0[1], C1[1], t)
            buf[i + 2] = lerp(C0[2], C1[2], t)
            buf[i + 3] = 255
    c = size / 2
    stroke = size * 0.07
    stroke_line(buf, size, size * 0.28, c, size * 0.72, c, stroke)
    stroke_line(buf, size, c, size * 0.28, c, size * 0.72, stroke)
    stroke_circle(buf, size, c, c, size * 0.16, size * 0.047)
    return bytes(buf)


def sips_resize(src: Path, dest: Path, size: int) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["sips", "-z", str(size), str(size), str(src), "--out", str(dest)],
        check=True,
        capture_output=True,
    )


def write_ico(png_by_size: dict[int, bytes], dest: Path) -> None:
    sizes = sorted(png_by_size)
    count = len(sizes)
    offset = 6 + 16 * count
    entries = b""
    payload = b""
    for size in sizes:
        data = png_by_size[size]
        w = 0 if size == 256 else size
        entries += struct.pack("<BBBBHHII", w, w, 0, 0, 1, 32, len(data), offset)
        payload += data
        offset += len(data)
    dest.write_bytes(struct.pack("<HHH", 0, 1, count) + entries + payload)


def main() -> None:
    master = raster_master(1024)
    MAC_DIR.mkdir(parents=True, exist_ok=True)
    master_path = MAC_DIR / "app_icon_1024.png"
    write_png(master_path, 1024, master)

    for size in (16, 32, 64, 128, 256, 512):
        sips_resize(master_path, MAC_DIR / f"app_icon_{size}.png", size)

    android = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android.items():
        sips_resize(master_path, ANDROID_RES / folder / "ic_launcher.png", size)

    ico_pngs: dict[int, bytes] = {}
    tmp = Path("/tmp/dicomflow_ico")
    tmp.mkdir(exist_ok=True)
    for size in (16, 32, 48, 256):
        out = tmp / f"{size}.png"
        sips_resize(master_path, out, size)
        ico_pngs[size] = out.read_bytes()
    WIN_ICO.parent.mkdir(parents=True, exist_ok=True)
    write_ico(ico_pngs, WIN_ICO)
    print(f"wrote mac icons in {MAC_DIR}")
    print(f"wrote android mipmaps")
    print(f"wrote {WIN_ICO}")


if __name__ == "__main__":
    main()
