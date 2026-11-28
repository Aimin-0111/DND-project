"""Paint the Beta-0.5 pixel art: the tileset, the edge overlays and the sprites.

Usage:
    python tools/make_art.py            # writes missing files only
    python tools/make_art.py --force    # rewrites every file

Needs Pillow (python -m pip install pillow). Everything is painted from code
with a fixed random seed, so the same files come out every time. The artist
can replace any file without changing the game code, as long as the sizes and
the cell order stay the same (see game/content/art/CREDITS.md).

It writes, in game/content/art/:
- tiles.png: 32 px tiles, 8 cells per row. Each tile of maps/tiles.csv gets
  `variants` cells in a row, starting at its `tileset_index`; the world picks
  one variant per tile so big fields don't repeat.
- edges.png: overlays drawn over a tile where it meets another terrain:
  row 0 the grass fringe (N, E, S, W, then the corners NE, SE, SW, NW),
  row 1 the shore foam on water, same order.
- hero.png: the hero sheet, 4 frames x 6 rows of 32 px (idle_down, walk_down,
  walk_up, walk_left, walk_right, attack_down).
- creature-rust-wolf.png, creature-brass-beetle.png: 32 x 32 sprites.
- creature-mill-golem.png: the boss, 64 x 64.
"""

from __future__ import annotations

import argparse
import csv
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
CONTENT = REPO_ROOT / "game" / "content"
ART = CONTENT / "art"
TILES_CSV = CONTENT / "maps" / "tiles.csv"

T = 32
COLUMNS = 8
CLEAR = (0, 0, 0, 0)


# --- small helpers -----------------------------------------------------------

def hexc(text: str, alpha: int = 255) -> tuple[int, int, int, int]:
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), alpha)


def shade(colour, amount: float):
    """amount > 0 lightens, < 0 darkens."""
    r, g, b, a = colour
    if amount >= 0:
        return (int(r + (255 - r) * amount), int(g + (255 - g) * amount), int(b + (255 - b) * amount), a)
    k = 1.0 + amount
    return (int(r * k), int(g * k), int(b * k), a)


def new(size=(T, T), fill=CLEAR) -> Image.Image:
    return Image.new("RGBA", size, fill)


def px(img: Image.Image, x: int, y: int, colour) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), colour)


def speckle(img, rng, colours, count, size=1) -> None:
    for _ in range(count):
        x, y = rng.randrange(img.width), rng.randrange(img.height)
        colour = rng.choice(colours)
        for dx in range(size):
            for dy in range(size):
                px(img, x + dx, y + dy, colour)


def disc(img, cx, cy, r, colour) -> None:
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                px(img, x, y, colour)


def ellipse(img, cx, cy, rx, ry, colour) -> None:
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                px(img, x, y, colour)


def rect(img, x0, y0, x1, y1, colour) -> None:
    """Inclusive corners."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, colour)


def outline(img, colour) -> None:
    """A 1 px dark outline around every opaque shape (classic sprite look)."""
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and src.getpixel((nx, ny))[3] > 128:
                    img.putpixel((x, y), colour)
                    break


def shadow(img, cx, cy, rx, ry, alpha=70) -> None:
    ellipse(img, cx, cy, rx, ry, (20, 30, 15, alpha))


# --- ground tiles ------------------------------------------------------------

GRASS = hexc("5fae3c")
GRASS_LIGHT = hexc("7cc94a")
GRASS_DARK = hexc("478f30")
GRASS_DEEP = hexc("3a7a2a")


def grass_base(rng, base=GRASS, light=GRASS_LIGHT, dark=GRASS_DARK, blades=14) -> Image.Image:
    img = new(fill=base)
    # Soft blotches give the field its texture.
    for _ in range(5):
        disc(img, rng.randrange(T), rng.randrange(T), rng.uniform(2, 4.5), shade(base, rng.uniform(-0.07, 0.07)))
    speckle(img, rng, [light, dark], 26)
    for _ in range(blades // 3):  # tufts: a dark V with light tips
        x, y = rng.randrange(2, T - 2), rng.randrange(4, T - 1)
        for dx, h in ((-1, 2), (0, 3), (1, 2)):
            for i in range(h):
                px(img, x + dx * (1 if i else 0) + (dx if i == h - 1 else 0), y - i, GRASS_DEEP if i == 0 else dark)
            px(img, x + dx * 2, y - h, light)
    for _ in range(blades):
        x, y = rng.randrange(1, T - 1), rng.randrange(3, T)
        h = rng.randint(2, 3)
        for i in range(h):
            px(img, x, y - i, light if i == h - 1 else dark)
        px(img, x - 1 if rng.random() < 0.5 else x + 1, y - h + 1, light)
    return img


def tile_grass(rng, v):
    img = grass_base(rng)
    if v == 3:
        for _ in range(2):
            x, y = rng.randrange(3, T - 3), rng.randrange(3, T - 3)
            px(img, x, y, hexc("f4f1d0"))
    return img


def tile_flowers(rng, v):
    img = grass_base(rng)
    petals = [hexc("f25f7a"), hexc("ffd44d"), hexc("f7f3e8"), hexc("b07ce8"), hexc("ff9d3b")]
    for _ in range(9 + v):
        x, y = rng.randrange(2, T - 2), rng.randrange(2, T - 2)
        colour = rng.choice(petals)
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            px(img, x + dx, y + dy, colour)
        px(img, x, y, hexc("ffe9a0"))
        px(img, x, y + 2, GRASS_DEEP)
    return img


def tile_tall_grass(rng, v):
    img = grass_base(rng, blades=6)
    for _ in range(22):
        x, y = rng.randrange(0, T), rng.randrange(6, T + 4)
        h = rng.randint(4, 7)
        lean = rng.choice((-1, 0, 1))
        for i in range(h):
            colour = GRASS_DEEP if i < 2 else (GRASS_DARK if i < h - 2 else GRASS_LIGHT)
            px(img, x + (lean if i > h // 2 else 0), y - i, colour)
    return img


def tile_forest_floor(rng, v):
    base = hexc("4d7a2c")
    img = grass_base(rng, base=base, light=hexc("6b9a3a"), dark=hexc("3b5f22"), blades=6)
    leaves = [hexc("8a6a2a"), hexc("a07b34"), hexc("6e5424"), hexc("5e7f2a")]
    speckle(img, rng, leaves, 18, size=2)
    for _ in range(2):  # twigs
        x, y = rng.randrange(4, T - 8), rng.randrange(4, T - 4)
        for i in range(rng.randint(3, 6)):
            px(img, x + i, y + (i // 3), hexc("5a3e22"))
    return img


def earth_tile(rng, base, light, dark, pebbles=5):
    img = new(fill=base)
    for _ in range(6):
        disc(img, rng.randrange(T), rng.randrange(T), rng.uniform(2, 5), shade(base, rng.uniform(-0.06, 0.06)))
    speckle(img, rng, [light, dark], 40)
    for _ in range(pebbles):
        x, y = rng.randrange(1, T - 2), rng.randrange(1, T - 2)
        rect(img, x, y, x + 1, y, light)
        px(img, x, y + 1, shade(light, -0.05))
        px(img, x + 1, y + 1, dark)
    return img


def tile_path(rng, v):
    img = earth_tile(rng, hexc("d2a866"), hexc("e6c48a"), hexc("ad8248"), pebbles=4 + v)
    if v == 2:  # a wheel rut
        y = rng.randrange(8, 24)
        for x in range(T):
            if rng.random() < 0.8:
                px(img, x, y, hexc("b88d52"))
    return img


def tile_dirt(rng, v):
    return earth_tile(rng, hexc("9a7148"), hexc("b48a5c"), hexc("76552f"), pebbles=6)


def tile_sand(rng, v):
    img = earth_tile(rng, hexc("e8d49a"), hexc("f5e6b8"), hexc("cdb57a"), pebbles=2)
    if v % 2:
        for i in range(3):  # ripples
            y = 6 + i * 9 + rng.randrange(3)
            for x in range(2, T - 2):
                if (x + i) % 5:
                    px(img, x, y, hexc("d9c286"))
    return img


def tile_mud(rng, v):
    img = earth_tile(rng, hexc("6e5f3a"), hexc("857448"), hexc("54472a"), pebbles=1)
    for _ in range(2):
        cx, cy = rng.randrange(6, 26), rng.randrange(6, 26)
        ellipse(img, cx, cy, rng.uniform(3, 5), rng.uniform(1.5, 3), hexc("4b5a5a"))
        px(img, cx - 1, cy - 1, hexc("9fb4b4"))
    return img


WATER = hexc("3b7fd0")


def tile_water(rng, v):
    img = new(fill=WATER)
    for _ in range(7):
        disc(img, rng.randrange(T), rng.randrange(T), rng.uniform(3, 6), shade(WATER, rng.uniform(-0.08, 0.05)))
    for _ in range(5):  # wave crests
        x, y = rng.randrange(0, T - 6), rng.randrange(2, T - 2)
        w = rng.randint(3, 6)
        for i in range(w):
            px(img, x + i, y, hexc("6aaaf0"))
        px(img, x + 1, y - 1, hexc("a8d4ff"))
    speckle(img, rng, [hexc("2f6bb8")], 14)
    if v == 1:
        px(img, rng.randrange(4, 28), rng.randrange(4, 28), hexc("ffffff"))
    return img


def tile_bridge(rng, v):
    img = new(fill=hexc("7a4f2a"))
    for i in range(4):  # boards run north-south, across a river flowing north-south
        x0 = i * 8
        wood = shade(hexc("a8733f"), rng.uniform(-0.08, 0.08))
        rect(img, x0 + 1, 0, x0 + 6, T - 1, wood)
        for y in range(0, T, rng.randint(5, 9)):
            px(img, x0 + rng.randint(2, 5), y, shade(wood, -0.2))
        px(img, x0 + 3, 4, hexc("4a2f18"))
        px(img, x0 + 3, 27, hexc("4a2f18"))
    return img


def tile_floor(rng, v):
    img = new(fill=hexc("6b4426"))
    for row in range(4):
        y0 = row * 8
        offset = rng.randrange(0, 16)
        wood = shade(hexc("b07a46"), rng.uniform(-0.06, 0.06))
        rect(img, 0, y0 + 1, T - 1, y0 + 6, wood)
        for x in range(T):
            if rng.random() < 0.25:
                px(img, x, y0 + rng.randint(2, 5), shade(wood, -0.12))
        rect(img, 0, y0 + 1, T - 1, y0 + 1, shade(wood, 0.12))
        px(img, (offset + 16) % T, y0 + 3, hexc("5a3a20"))
        rect(img, offset, y0 + 1, offset, y0 + 6, hexc("6b4426"))
    return img


def tile_stone_floor(rng, v):
    img = new(fill=hexc("5c5a58"))
    stones = [(0, 0, 15, 11), (16, 0, 31, 11), (0, 12, 9, 31), (10, 12, 23, 22), (24, 12, 31, 31), (10, 23, 23, 31)]
    for x0, y0, x1, y1 in stones:
        colour = shade(hexc("8e8a84"), rng.uniform(-0.1, 0.08))
        rect(img, x0 + 1, y0 + 1, x1 - 1, y1 - 1, colour)
        rect(img, x0 + 1, y0 + 1, x1 - 1, y0 + 1, shade(colour, 0.15))
        speckle_area(img, rng, x0 + 2, y0 + 2, x1 - 2, y1 - 2, shade(colour, -0.12), 4)
    return img


def speckle_area(img, rng, x0, y0, x1, y1, colour, count) -> None:
    if x1 <= x0 or y1 <= y0:
        return
    for _ in range(count):
        px(img, rng.randint(x0, x1), rng.randint(y0, y1), colour)


def tile_cave_floor(rng, v):
    img = earth_tile(rng, hexc("4a3f38"), hexc("5e524a"), hexc("362e29"), pebbles=5)
    return img


def tile_rug(rng, v):
    img = new(fill=hexc("8e2a2a"))
    rect(img, 0, 0, T - 1, 1, hexc("d4a63a"))
    rect(img, 0, T - 2, T - 1, T - 1, hexc("d4a63a"))
    for cx in (8, 24):
        for cy in (8, 24):
            for d in range(5):
                px(img, cx - d, cy - 4 + d, hexc("d4a63a"))
                px(img, cx + d, cy - 4 + d, hexc("d4a63a"))
                px(img, cx - d, cy + 4 - d, hexc("d4a63a"))
                px(img, cx + d, cy + 4 - d, hexc("d4a63a"))
            px(img, cx, cy, hexc("2d5f8a"))
    speckle(img, rng, [hexc("7a2222")], 30)
    return img


def tile_door(rng, v):
    img = wall_face(rng)
    rect(img, 7, 4, 24, T - 1, hexc("3a2412"))
    for i, x0 in enumerate((8, 13, 18)):
        rect(img, x0, 5, x0 + 4, T - 1, shade(hexc("8a5a2e"), 0.05 * i))
    rect(img, 8, 12, 22, 13, hexc("4e4e56"))
    rect(img, 8, 24, 22, 25, hexc("4e4e56"))
    px(img, 20, 19, hexc("e8c24a"))
    px(img, 20, 20, hexc("a8862a"))
    return img


def tile_stairs(rng, v):
    img = new(fill=hexc("2a2420"))
    for i in range(5):
        y0 = i * 6
        colour = shade(hexc("8e8a84"), -0.12 * i)
        rect(img, 3, y0, T - 4, y0 + 3, colour)
        rect(img, 3, y0, T - 4, y0, shade(colour, 0.2))
    rect(img, 0, 0, 2, T - 1, hexc("5c5a58"))
    rect(img, T - 3, 0, T - 1, T - 1, hexc("5c5a58"))
    return img


# --- walls and roofs (opaque obstacles) ---------------------------------------

def wall_face(rng) -> Image.Image:
    img = new(fill=hexc("4a3f3a"))
    for row in range(5):
        y0 = row * 6 + 2
        offset = 0 if row % 2 else 5
        for x0 in range(-offset, T, 10):
            colour = shade(hexc("9a8a7a"), rng.uniform(-0.12, 0.06))
            rect(img, max(0, x0 + 1), y0, min(T - 1, x0 + 8), y0 + 4, colour)
            rect(img, max(0, x0 + 1), y0, min(T - 1, x0 + 8), y0, shade(colour, 0.15))
    rect(img, 0, 0, T - 1, 1, hexc("2e2724"))
    return img


def tile_wall(rng, v):
    img = wall_face(rng)
    if v == 2:  # a little moss
        speckle_area(img, rng, 0, 20, T - 1, T - 1, hexc("5e8a3a"), 12)
    return img


def tile_roof(rng, v):
    img = new(fill=hexc("6e2e22"))
    for row in range(6):
        y0 = row * 6 - 1
        offset = 0 if row % 2 else 4
        for x0 in range(-offset, T, 8):
            colour = shade(hexc("b2503a"), rng.uniform(-0.1, 0.06) - row * 0.015)
            rect(img, max(0, x0), max(0, y0), min(T - 1, x0 + 6), min(T - 1, y0 + 4), colour)
            rect(img, max(0, x0), min(T - 1, y0 + 4), min(T - 1, x0 + 6), min(T - 1, y0 + 4), shade(colour, -0.25))
    return img


def tile_cliff(rng, v):
    base = hexc("8b6b4e")
    img = new(fill=base)
    for _ in range(9):  # rock facets: light top-left, dark bottom-right
        cx, cy = rng.randrange(-4, T + 4), rng.randrange(-4, T + 4)
        r = rng.uniform(4, 9)
        disc(img, cx + 1, cy + 1, r, hexc("5e4632"))
        disc(img, cx, cy, r - 1, shade(base, rng.uniform(-0.05, 0.12)))
        disc(img, cx - r / 3, cy - r / 3, r / 3, hexc("b89a78"))
    for i in range(3):  # strata
        y = rng.randrange(T)
        for x in range(T):
            if rng.random() < 0.6:
                px(img, x, y + (x // 9) % 2, hexc("6e5340"))
    if v == 3:  # snow cap
        for x in range(T):
            for y in range(rng.randint(2, 6)):
                px(img, x, y, hexc("f2f4f7") if y else hexc("ffffff"))
    return img


# --- objects on the obstacle layer (transparent background) -------------------

def tile_tree(rng, v):
    img = new()
    if v >= 2:  # a pine
        shadow(img, 16, 29, 9, 3)
        rect(img, 15, 24, 17, 30, hexc("5a3a20"))
        for i, (y, w) in enumerate(((22, 12), (16, 10), (10, 7), (5, 4))):
            colour = (hexc("2a5e2a"), hexc("2f6b2e"), hexc("3a7d34"), hexc("4a8f3c"))[i]
            for dy in range(7):
                half = int(w * (dy + 1) / 7)
                for x in range(16 - half, 16 + half + 1):
                    px(img, x, y - 6 + dy, colour)
            px(img, 16 - w // 2, y - 1, hexc("5ea84a"))
        outline(img, hexc("173a1a"))
        return img
    shadow(img, 16, 28, 11, 4)
    rect(img, 14, 21, 18, 30, hexc("6b4226"))
    rect(img, 14, 21, 14, 30, hexc("4e2f1a"))
    px(img, 13, 30, hexc("6b4226"))
    px(img, 19, 30, hexc("6b4226"))
    cx, cy = 16, 13
    disc(img, cx, cy + 1, 13, hexc("2d6e2a"))
    for ox, oy, r in ((-6, 2, 7), (6, 2, 7), (0, -4, 8), (-3, 4, 7), (4, 5, 6)):
        disc(img, cx + ox, cy + oy, r, hexc("3f8f35"))
    for ox, oy, r in ((-5, -3, 4.5), (2, -7, 4), (-8, 1, 3)):
        disc(img, cx + ox, cy + oy, r, hexc("5aa843"))
    for ox, oy in ((-6, -5), (1, -9), (-9, -1), (3, -5)):
        px(img, cx + ox, cy + oy, hexc("8fd65a"))
        px(img, cx + ox + 1, cy + oy, hexc("8fd65a"))
    speckle_area(img, rng, 6, 10, 26, 24, hexc("2d6e2a"), 10)
    if v == 1:  # apples
        for _ in range(4):
            px(img, rng.randrange(8, 24), rng.randrange(6, 20), hexc("d83a2a"))
    outline(img, hexc("173a1a"))
    return img


def tile_rock(rng, v):
    img = new()
    shadow(img, 16, 26, 12, 4)
    base = hexc("9a9690")
    ellipse(img, 16, 18, 12 - v, 9 - v // 2, shade(base, -0.25))
    ellipse(img, 15, 17, 11 - v, 8 - v // 2, base)
    ellipse(img, 12, 14, 5, 3, hexc("c4c0b8"))
    px(img, 10, 13, hexc("e6e2da"))
    for _ in range(4):
        x = rng.randrange(8, 22)
        px(img, x, rng.randrange(17, 23), shade(base, -0.3))
    if v == 3:
        speckle_area(img, rng, 8, 12, 22, 16, hexc("6b9a3a"), 8)
    outline(img, hexc("3a3836"))
    return img


def tile_bush(rng, v):
    img = new()
    shadow(img, 16, 26, 11, 4)
    for ox, oy, r in ((-5, 2, 6), (5, 2, 6), (0, -2, 7)):
        disc(img, 16 + ox, 18 + oy, r, hexc("3a7d34"))
    for ox, oy, r in ((-4, 0, 3.5), (3, -4, 3)):
        disc(img, 16 + ox, 18 + oy, r, hexc("5aa843"))
    if v % 2:
        for _ in range(5):
            px(img, rng.randrange(8, 24), rng.randrange(12, 24), hexc("e84a6a") if v == 1 else hexc("4a5ad8"))
    outline(img, hexc("173a1a"))
    return img


def tile_reeds(rng, v):
    img = new()
    for _ in range(14):
        x = rng.randrange(3, 29)
        h = rng.randint(10, 20)
        for i in range(h):
            px(img, x + (1 if i > h - 4 and x % 2 else 0), 30 - i, hexc("8a9a3a") if i < h - 3 else hexc("b5b84a"))
        if rng.random() < 0.5:  # cattail head
            rect(img, x, 30 - h - 1, x, 30 - h + 2, hexc("6e4a2a"))
    return img


def tile_wheel(rng, v):
    """A slice of the mill's paddle wheel seen from above: wet paddles between
    two brass-bound rims. It tiles in any direction, so a block of wheel tiles
    reads as one big wheel turning in the river."""
    img = new(fill=hexc("2c4f7a"))  # dark water between the paddles
    for y0 in range(0, T, 8):
        rect(img, 3, y0 + 1, T - 4, y0 + 5, hexc("8a5a2e"))
        rect(img, 3, y0 + 1, T - 4, y0 + 1, hexc("b07a46"))
        rect(img, 3, y0 + 5, T - 4, y0 + 5, hexc("5a3a20"))
        px(img, rng.randrange(5, T - 5), y0 + 3, hexc("a8d4ff"))  # a drop of water
    for x0 in (0, T - 3):  # the rims
        rect(img, x0, 0, x0 + 2, T - 1, hexc("5a3a20"))
        for y in range(2, T, 8):
            px(img, x0 + 1, y, hexc("e0b043"))
    return img


def furniture(rng, v, kind):
    img = new()
    if kind == "table":
        shadow(img, 16, 27, 13, 3)
        rect(img, 4, 8, 27, 22, hexc("8a5a2e"))
        rect(img, 4, 8, 27, 9, hexc("b07a46"))
        rect(img, 5, 23, 6, 28, hexc("5a3a20"))
        rect(img, 25, 23, 26, 28, hexc("5a3a20"))
        for x in range(6, 26, 6):
            rect(img, x, 10, x, 21, hexc("7a4f2a"))
        if v == 1:  # a candle and a mug
            rect(img, 10, 10, 11, 14, hexc("f2ead0"))
            px(img, 10, 9, hexc("ffb43a"))
            rect(img, 19, 12, 22, 15, hexc("c9a227"))
    elif kind == "bed":
        rect(img, 5, 2, 26, 29, hexc("5a3a20"))
        rect(img, 6, 3, 25, 28, hexc("2d5f8a"))
        rect(img, 6, 3, 25, 10, hexc("f2ead0"))
        rect(img, 8, 5, 23, 8, hexc("ffffff"))
        for y in range(12, 28, 4):
            rect(img, 6, y, 25, y, hexc("24507a"))
    elif kind == "barrel":
        shadow(img, 16, 28, 10, 3)
        ellipse(img, 16, 17, 9, 11, hexc("8a5a2e"))
        for x in range(8, 25, 3):
            rect(img, x, 8, x, 26, hexc("74481f"))
        rect(img, 7, 11, 25, 12, hexc("4e4e56"))
        rect(img, 7, 22, 25, 23, hexc("4e4e56"))
        ellipse(img, 16, 8, 8, 3, hexc("a8733f"))
    elif kind == "chest":
        shadow(img, 16, 27, 12, 3)
        rect(img, 5, 12, 26, 26, hexc("8a5a2e"))
        rect(img, 5, 9, 26, 15, hexc("a8733f"))
        rect(img, 5, 15, 26, 16, hexc("c9a227"))
        rect(img, 9, 9, 10, 26, hexc("c9a227"))
        rect(img, 21, 9, 22, 26, hexc("c9a227"))
        rect(img, 15, 15, 16, 19, hexc("e8d27a"))
    elif kind == "hearth":
        img = wall_face(rng)
        rect(img, 6, 10, 25, T - 1, hexc("2a2420"))
        rect(img, 4, 8, 27, 10, hexc("5c5a58"))
        for _ in range(14):
            x, y = rng.randrange(9, 23), rng.randrange(18, 31)
            px(img, x, y, rng.choice([hexc("ff8a2a"), hexc("ffd23a"), hexc("e84a1a")]))
        rect(img, 10, 28, 21, 29, hexc("6b4226"))
    if kind != "hearth":
        outline(img, hexc("2e1c10"))
    return img


# --- the tile list: tiles.csv id -> painter -----------------------------------

PAINTERS = {
    "grass": tile_grass,
    "path": tile_path,
    "water": tile_water,
    "tree": tile_tree,
    "rock": tile_rock,
    "floor": tile_floor,
    "wall": tile_wall,
    "bridge": tile_bridge,
    "sand": tile_sand,
    "flowers": tile_flowers,
    "forest_floor": tile_forest_floor,
    "dirt": tile_dirt,
    "mud": tile_mud,
    "reeds": tile_reeds,
    "wheel": tile_wheel,
    "door": tile_door,
    "stone_floor": tile_stone_floor,
    "rug": tile_rug,
    "table": lambda rng, v: furniture(rng, v, "table"),
    "bed": lambda rng, v: furniture(rng, v, "bed"),
    "barrel": lambda rng, v: furniture(rng, v, "barrel"),
    "chest": lambda rng, v: furniture(rng, v, "chest"),
    "hearth": lambda rng, v: furniture(rng, v, "hearth"),
    "cliff": tile_cliff,
    "cave_floor": tile_cave_floor,
    "stairs": tile_stairs,
    "bush": tile_bush,
    "tall_grass": tile_tall_grass,
    "roof": tile_roof,
}


def make_tileset(path: Path) -> None:
    with TILES_CSV.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    last = max(int(r["tileset_index"]) + int(r.get("variants") or 1) for r in rows)
    rows_needed = (last + COLUMNS - 1) // COLUMNS
    sheet = new((COLUMNS * T, rows_needed * T))
    for row in rows:
        painter = PAINTERS.get(row["id"])
        if painter is None:
            print(f"  no painter for tile {row['id']!r}: its cells stay empty")
            continue
        start = int(row["tileset_index"])
        for v in range(int(row.get("variants") or 1)):
            rng = random.Random(f"{row['id']}-{v}")
            cell = start + v
            sheet.paste(painter(rng, v), ((cell % COLUMNS) * T, (cell // COLUMNS) * T))
    sheet.save(path)


# --- edge overlays -------------------------------------------------------------

def fringe(rng, side: str, corner: bool = False) -> Image.Image:
    """Grass spilling over the edge of the tile on `side` (N/E/S/W), or a
    corner (NE/SE/SW/NW) when both neighbours on that diagonal are grass."""
    img = new()
    if corner:
        for y in range(T):
            for x in range(T):
                d = math.hypot(x + 0.5, y + 0.5)
                if d < 5 + rng.random() * 2.2:
                    img.putpixel((x, y), GRASS_DARK if d > 4.5 else GRASS)
        img = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if side in ("NE", "SE") else img
        img = img.transpose(Image.Transpose.FLIP_TOP_BOTTOM) if side in ("SE", "SW") else img
        return img
    depth = [3 + int(2.5 * (1 + math.sin(x * 0.7 + rng.random()))) + rng.randint(0, 1) for x in range(T)]
    for x in range(T):
        for y in range(depth[x]):
            img.putpixel((x, y), GRASS if y < depth[x] - 1 else GRASS_DARK)
        if rng.random() < 0.35:  # a blade sticking out
            img.putpixel((x, min(T - 1, depth[x])), GRASS_LIGHT)
        if rng.random() < 0.2:
            img.putpixel((x, max(0, depth[x] - 3)), GRASS_LIGHT)
    rotate = {"N": None, "E": Image.Transpose.ROTATE_270, "S": Image.Transpose.ROTATE_180, "W": Image.Transpose.ROTATE_90}
    return img if rotate[side] is None else img.transpose(rotate[side])


def foam(rng, side: str, corner: bool = False) -> Image.Image:
    img = new()
    edge = (226, 240, 255, 230)
    band = (90, 150, 220, 150)
    if corner:
        for y in range(5):
            for x in range(5):
                if x + y < 4:
                    img.putpixel((x, y), edge if x + y < 2 else band)
    else:
        for x in range(T):
            img.putpixel((x, 0), edge)
            if rng.random() < 0.7:
                img.putpixel((x, 1), edge)
            for y in range(2, 4 + rng.randint(0, 1)):
                img.putpixel((x, y), band)
    if corner:
        img = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if side in ("NE", "SE") else img
        img = img.transpose(Image.Transpose.FLIP_TOP_BOTTOM) if side in ("SE", "SW") else img
        return img
    rotate = {"N": None, "E": Image.Transpose.ROTATE_270, "S": Image.Transpose.ROTATE_180, "W": Image.Transpose.ROTATE_90}
    return img if rotate[side] is None else img.transpose(rotate[side])


def make_edges(path: Path) -> None:
    sheet = new((COLUMNS * T, 2 * T))
    order = ["N", "E", "S", "W", "NE", "SE", "SW", "NW"]
    for i, side in enumerate(order):
        rng = random.Random(f"edge-{side}")
        sheet.paste(fringe(rng, side, len(side) == 2), (i * T, 0))
        sheet.paste(foam(rng, side, len(side) == 2), (i * T, T))
    sheet.save(path)


# --- characters ------------------------------------------------------------------

SKIN = hexc("f0c8a0")
SKIN_DARK = hexc("d09a74")
HAIR = hexc("7a4a24")
HAIR_DARK = hexc("54321a")
TUNIC = hexc("2f7a6a")
TUNIC_DARK = hexc("235a4f")
BELT = hexc("6b4226")
BRASS = hexc("e0b043")
PANTS = hexc("4a4038")
BOOTS = hexc("3a2a1e")
INK = hexc("1e1a24")


def hero_frame(view: str, step: int, attack: int = -1) -> Image.Image:
    """One 32 x 32 hero frame. view: down / up / right. step: 0-3."""
    img = new()
    bob = 1 if step in (1, 3) else 0
    leg = (0, 2, 0, -2)[step]
    shadow(img, 16, 29, 7, 2, alpha=80)
    # legs
    if view == "right":
        rect(img, 13 + leg // 2, 22, 15 + leg // 2, 27, PANTS)
        rect(img, 16 - leg // 2, 22, 18 - leg // 2, 27, shade(PANTS, -0.15))
        rect(img, 13 + leg // 2, 27, 16 + leg // 2, 28, BOOTS)
        rect(img, 16 - leg // 2, 27, 19 - leg // 2, 28, BOOTS)
    else:
        rect(img, 12, 22, 14, 27 - max(0, leg), PANTS)
        rect(img, 17, 22, 19, 27 - max(0, -leg), PANTS)
        rect(img, 12, 27 - max(0, leg), 14, 28 - max(0, leg), BOOTS)
        rect(img, 17, 27 - max(0, -leg), 19, 28 - max(0, -leg), BOOTS)
    top = 13 - bob
    # body
    if view == "right":
        rect(img, 12, top, 19, 22 - bob, TUNIC)
        rect(img, 12, top, 13, 22 - bob, TUNIC_DARK)
        rect(img, 12, 19 - bob, 19, 20 - bob, BELT)
        px(img, 17, 19 - bob, BRASS)
        arm = (0, 1, 0, -1)[step]
        rect(img, 14 + arm, top + 2, 16 + arm, top + 7, TUNIC_DARK)
        rect(img, 14 + arm, top + 8, 16 + arm, top + 8, SKIN)
    else:
        rect(img, 11, top, 20, 22 - bob, TUNIC)
        rect(img, 11, top, 11, 22 - bob, TUNIC_DARK)
        rect(img, 20, top, 20, 22 - bob, TUNIC_DARK)
        rect(img, 11, 19 - bob, 20, 20 - bob, BELT)
        if view == "down":
            px(img, 15, 19 - bob, BRASS)
            px(img, 16, 19 - bob, BRASS)
            rect(img, 14, top, 17, top + 1, shade(TUNIC, 0.15))
        swing = (0, 1, 0, -1)[step]
        rect(img, 9, top + 1 + swing, 10, top + 7 + swing, TUNIC_DARK)
        rect(img, 21, top + 1 - swing, 22, top + 7 - swing, TUNIC_DARK)
        rect(img, 9, top + 8 + swing, 10, top + 8 + swing, SKIN)
        rect(img, 21, top + 8 - swing, 22, top + 8 - swing, SKIN)
    # head
    hy = 3 - bob
    if view == "right":
        rect(img, 12, hy + 2, 20, hy + 10, SKIN)
        rect(img, 11, hy, 19, hy + 4, HAIR)
        rect(img, 11, hy + 4, 13, hy + 9, HAIR)
        rect(img, 11, hy + 2, 12, hy + 3, HAIR_DARK)
        px(img, 18, hy + 6, INK)
        rect(img, 15, hy + 3, 20, hy + 4, BRASS)  # goggles strap
        px(img, 19, hy + 3, hexc("8ad8ff"))
        px(img, 20, hy + 7, SKIN_DARK)
    elif view == "up":
        rect(img, 11, hy + 1, 20, hy + 9, HAIR)
        rect(img, 12, hy + 10, 19, hy + 10, SKIN_DARK)  # the neck
        rect(img, 11, hy + 4, 20, hy + 4, BRASS)
        for x in (13, 16, 18):  # light streaks so it reads as hair
            rect(img, x, hy + 1, x, hy + 3, hexc("9a6434"))
            rect(img, x - 1, hy + 6, x - 1, hy + 8, hexc("9a6434"))
    else:
        rect(img, 11, hy + 2, 20, hy + 10, SKIN)
        rect(img, 11, hy, 20, hy + 3, HAIR)
        rect(img, 10, hy + 2, 11, hy + 8, HAIR)
        rect(img, 20, hy + 2, 21, hy + 8, HAIR)
        rect(img, 11, hy + 3, 20, hy + 4, BRASS)  # goggles on the forehead
        px(img, 13, hy + 3, hexc("8ad8ff"))
        px(img, 18, hy + 3, hexc("8ad8ff"))
        px(img, 13, hy + 6, INK)
        px(img, 18, hy + 6, INK)
        rect(img, 15, hy + 8, 16, hy + 8, SKIN_DARK)
    if attack >= 0:  # the sword swings from the right side down to the front
        blade = hexc("d8dde4")
        angle = (-1.2, -0.4, 0.4, 1.1)[attack]
        for r in range(4, 13):
            px(img, int(22 + math.cos(angle) * r), int(16 + math.sin(angle) * r), blade)
        px(img, 22, 16, BRASS)
        px(img, 23, 16, BRASS)
    outline(img, INK)
    return img


def make_hero(path: Path) -> None:
    sheet = new((4 * T, 6 * T))
    rows = [("down", False, False), ("down", True, False), ("up", True, False),
            ("right", True, True), ("right", True, False), ("down", False, False)]
    for r, (view, walking, mirror) in enumerate(rows):
        for f in range(4):
            frame = hero_frame(view, f if walking else 0, attack=f if r == 5 else -1)
            if r == 0 and f in (2, 3):  # idle breathing
                frame = hero_frame(view, 1)
            if mirror:
                frame = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            sheet.paste(frame, (f * T, r * T))
    sheet.save(path)


def make_wolf(path: Path) -> None:
    img = new()
    fur, dark, light = hexc("b5562a"), hexc("7e3518"), hexc("e08a4a")
    shadow(img, 16, 27, 12, 3)
    ellipse(img, 15, 18, 9, 5, fur)          # body
    ellipse(img, 15, 15, 8, 2, dark)         # back
    for x in (8, 11, 18, 21):                # legs
        rect(img, x, 21, x + 1, 26, dark)
    ellipse(img, 24, 14, 5, 4, fur)          # head
    rect(img, 27, 15, 30, 17, light)         # muzzle
    px(img, 30, 15, INK)
    px(img, 25, 13, hexc("ffe24a"))          # eye
    rect(img, 21, 8, 22, 11, dark)           # ears
    rect(img, 24, 8, 25, 11, dark)
    for i in range(6):                       # tail
        px(img, 6 - i // 2, 15 - i, fur)
        px(img, 7 - i // 2, 15 - i, dark)
    for x in (10, 14, 18):                   # rusty plates
        px(img, x, 17, hexc("8a8a8a"))
        px(img, x + 1, 17, hexc("c9a227"))
    outline(img, INK)
    img.save(path)


def make_beetle(path: Path) -> None:
    img = new()
    shadow(img, 16, 27, 11, 3)
    for i, x in enumerate((7, 10, 22, 25)):  # legs
        rect(img, x, 20, x, 25, hexc("4e4e56"))
    ellipse(img, 16, 18, 10, 8, hexc("a8782a"))
    ellipse(img, 16, 17, 9, 7, hexc("d4a63a"))
    rect(img, 16, 10, 16, 25, hexc("8a5a17"))      # shell seam
    for x, y in ((11, 15), (21, 15), (12, 21), (20, 21)):
        px(img, x, y, hexc("fff0b0"))               # rivets
    ellipse(img, 16, 9, 5, 3, hexc("5a5a66"))
    px(img, 14, 8, hexc("6af0ff"))
    px(img, 18, 8, hexc("6af0ff"))
    rect(img, 12, 4, 13, 6, hexc("4e4e56"))
    rect(img, 19, 4, 20, 6, hexc("4e4e56"))
    outline(img, INK)
    img.save(path)


def make_golem(path: Path) -> None:
    S = 64
    img = new((S, S))
    brass, brass_dark, brass_light = hexc("c9922a"), hexc("8a5a17"), hexc("f0c860")
    iron = hexc("5a5a66")
    shadow(img, 32, 59, 22, 4, alpha=90)
    for x in (18, 38):                                     # legs
        rect(img, x, 44, x + 8, 57, iron)
        rect(img, x - 1, 55, x + 9, 58, hexc("3a3a44"))
    ellipse(img, 32, 32, 20, 16, brass_dark)               # body
    ellipse(img, 31, 31, 19, 15, brass)
    ellipse(img, 26, 24, 8, 5, brass_light)
    disc(img, 32, 35, 7, hexc("2a1a10"))                   # furnace
    disc(img, 32, 35, 5, hexc("ff7a1a"))
    disc(img, 32, 36, 3, hexc("ffd23a"))
    for a in range(12):                                    # rivets around it
        angle = a * math.pi / 6
        px(img, int(32 + math.cos(angle) * 9), int(35 + math.sin(angle) * 9), hexc("fff0b0"))
    disc(img, 10, 28, 9, hexc("8e8a84"))                   # millstone shoulder
    disc(img, 10, 28, 3, hexc("5c5a58"))
    for a in range(8):
        angle = a * math.pi / 4
        px(img, int(10 + math.cos(angle) * 6), int(28 + math.sin(angle) * 6), hexc("6e6a64"))
    rect(img, 49, 22, 58, 46, iron)                        # piston arm
    rect(img, 50, 23, 51, 45, hexc("8a8a96"))
    rect(img, 47, 44, 60, 50, brass_dark)                  # fist
    ellipse(img, 32, 12, 10, 8, iron)                      # head
    rect(img, 24, 10, 40, 13, hexc("2a2420"))
    rect(img, 26, 11, 29, 12, hexc("ff3a1a"))              # eyes
    rect(img, 35, 11, 38, 12, hexc("ff3a1a"))
    rect(img, 30, 2, 33, 6, iron)                          # chimney
    for i, (x, y) in enumerate(((31, 0), (34, 1), (28, 1))):
        px(img, x, y, hexc("d8d8d8"))
    outline(img, INK)
    img.save(path)


OUTPUTS = {
    "tiles.png": make_tileset,
    "edges.png": make_edges,
    "hero.png": make_hero,
    "creature-rust-wolf.png": make_wolf,
    "creature-brass-beetle.png": make_beetle,
    "creature-mill-golem.png": make_golem,
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="rewrite files that already exist")
    args = parser.parse_args()
    for name, maker in OUTPUTS.items():
        path = ART / name
        if path.exists() and not args.force:
            print(f"kept    {path.relative_to(REPO_ROOT)}")
            continue
        maker(path)
        print(f"wrote   {path.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
