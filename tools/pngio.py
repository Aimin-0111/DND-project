"""Read and write PNG images with the Python standard library only.

Used by content_check.py (to read the team's map images) and by
make_placeholder_maps.py (to draw the placeholder art). Reads the PNG kinds
image editors produce: grey, RGB, palette (indexed), grey + alpha and RGBA,
8 or 16 bits (and 1/2/4-bit grey or palette). Interlaced PNGs are refused
with a message, because the game doesn't need them.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

SIGNATURE = b"\x89PNG\r\n\x1a\n"
CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


class PngError(ValueError):
    """The file is not a PNG this reader understands; the message says why."""


def read_size(path: Path) -> tuple[int, int]:
    """Width and height from the header, without decoding the pixels."""
    with Path(path).open("rb") as handle:
        head = handle.read(24)
    if len(head) < 24 or head[:8] != SIGNATURE or head[12:16] != b"IHDR":
        raise PngError("not a PNG image")
    return struct.unpack(">II", head[16:24])


def read_png(path: Path) -> tuple[int, int, list[list[tuple[int, int, int, int]]]]:
    """Returns (width, height, rows) where each pixel is (r, g, b, a), 0-255."""
    data = Path(path).read_bytes()
    if data[:8] != SIGNATURE:
        raise PngError("not a PNG image")
    pos = 8
    header = None
    palette = b""
    transparency = b""
    compressed = bytearray()
    while pos + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = body
        elif kind == b"tRNS":
            transparency = body
        elif kind == b"IDAT":
            compressed += body
        elif kind == b"IEND":
            break
    if header is None:
        raise PngError("the PNG has no header")
    width, height, depth, colour_type, _, _, interlace = header
    if colour_type not in CHANNELS:
        raise PngError(f"unknown PNG colour type {colour_type}")
    if interlace:
        raise PngError("interlaced PNG: save it again without interlacing")
    if width == 0 or height == 0:
        raise PngError("the image is empty (0 pixels)")
    try:
        raw = zlib.decompress(bytes(compressed))
    except zlib.error as exc:
        raise PngError(f"damaged PNG data ({exc})") from exc

    channels = CHANNELS[colour_type]
    bits_per_pixel = channels * depth
    stride = (width * bits_per_pixel + 7) // 8
    step = max(1, bits_per_pixel // 8)
    if len(raw) < height * (stride + 1):
        raise PngError("the PNG data is shorter than the image size")

    rows: list[list[tuple[int, int, int, int]]] = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        line = bytearray(raw[offset + 1:offset + 1 + stride])
        offset += 1 + stride
        _unfilter(line, previous, filter_type, step)
        rows.append(_decode_row(line, width, depth, colour_type, palette, transparency))
        previous = line
    return width, height, rows


def _unfilter(line: bytearray, previous: bytearray, filter_type: int, step: int) -> None:
    if filter_type == 0:
        return
    if filter_type > 4:
        raise PngError(f"unknown PNG filter {filter_type}")
    for i in range(len(line)):
        left = line[i - step] if i >= step else 0
        up = previous[i]
        up_left = previous[i - step] if i >= step else 0
        if filter_type == 1:
            line[i] = (line[i] + left) & 0xFF
        elif filter_type == 2:
            line[i] = (line[i] + up) & 0xFF
        elif filter_type == 3:
            line[i] = (line[i] + (left + up) // 2) & 0xFF
        else:
            guess = left + up - up_left
            near_left, near_up, near_corner = abs(guess - left), abs(guess - up), abs(guess - up_left)
            if near_left <= near_up and near_left <= near_corner:
                best = left
            elif near_up <= near_corner:
                best = up
            else:
                best = up_left
            line[i] = (line[i] + best) & 0xFF


def _samples(line: bytearray, count: int, depth: int) -> list[int]:
    """Unpacks `count` samples of `depth` bits, scaled to 0-255 (palette: raw index)."""
    if depth == 8:
        return list(line[:count])
    if depth == 16:
        return [line[i * 2] for i in range(count)]
    out = []
    mask = (1 << depth) - 1
    per_byte = 8 // depth
    for i in range(count):
        byte = line[i // per_byte]
        shift = 8 - depth * (i % per_byte + 1)
        out.append((byte >> shift) & mask)
    return out


def _decode_row(line, width, depth, colour_type, palette, transparency):
    channels = CHANNELS[colour_type]
    values = _samples(line, width * channels, depth)
    pixels = []
    if colour_type == 3:
        for index in values:
            if index * 3 + 2 >= len(palette):
                raise PngError(f"palette index {index} is missing from the palette")
            alpha = transparency[index] if index < len(transparency) else 255
            pixels.append((palette[index * 3], palette[index * 3 + 1], palette[index * 3 + 2], alpha))
        return pixels
    scale = 255 // ((1 << depth) - 1) if depth < 8 else 1
    for x in range(width):
        sample = values[x * channels:(x + 1) * channels]
        if colour_type == 0:
            grey = sample[0] * scale
            pixels.append((grey, grey, grey, 255))
        elif colour_type == 4:
            pixels.append((sample[0], sample[0], sample[0], sample[1]))
        elif colour_type == 2:
            pixels.append((sample[0], sample[1], sample[2], 255))
        else:
            pixels.append((sample[0], sample[1], sample[2], sample[3]))
    return pixels


def write_png(path: Path, width: int, height: int, rows, alpha: bool = True) -> None:
    """Writes 8-bit RGBA (alpha=True) or RGB pixels; `rows[y][x]` is (r, g, b[, a])."""
    size = 4 if alpha else 3
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for pixel in row:
            values = tuple(pixel) + (255,) * (4 - len(pixel))
            raw.extend(values[:size])

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    colour_type = 6 if alpha else 2
    header = struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0)
    Path(path).write_bytes(
        SIGNATURE + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    )
