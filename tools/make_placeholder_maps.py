"""Draw the Beta-0.3 placeholder map art (Python standard library only).

Usage:
    python3 tools/make_placeholder_maps.py            # writes missing files only
    python3 tools/make_placeholder_maps.py --force    # rewrites all three

Colours come from game/content/maps/tiles.csv and kinds.csv, so the images
always match the tables. It writes:
- game/content/art/tiles-placeholder.png: the tileset, 8 cells of 32 px per
  row. Cells 0-3 (grass, path, water, tree) are copied from the existing file.
- game/content/maps/world.png: a 48 x 48 world map (one pixel = one square).
- game/content/maps/squares/mill-road.png: the 64 x 64 start square (one
  pixel = one tile) with the Beta-0.2 Mill Road content.

Existing files are kept unless --force is given, so the artist's own images
are never overwritten by accident. Placeholder art only: CC0, see
game/content/art/CREDITS.md.
"""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

from pngio import read_png, write_png

REPO_ROOT = Path(__file__).resolve().parent.parent
CONTENT = REPO_ROOT / "game" / "content"
TILESET = CONTENT / "art" / "tiles-placeholder.png"
WORLD = CONTENT / "maps" / "world.png"
START_SQUARE = CONTENT / "maps" / "squares" / "mill-road.png"

CELL = 32
TILESET_COLUMNS = 8
WORLD_SIZE = 48
SQUARE = 64
CLEAR = (0, 0, 0, 0)


def hex_colour(text: str) -> tuple[int, int, int]:
    text = text.strip().lstrip("#")
    return int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16)


def read_table(path: Path) -> dict[str, dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return {row["id"].strip(): row for row in csv.DictReader(handle)}


class Noise:
    """Tiny deterministic generator so the placeholders are the same every run."""

    def __init__(self, seed: int) -> None:
        self.state = seed & 0xFFFFFFFF

    def next(self) -> int:
        self.state = (self.state * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.state >> 8

    def below(self, limit: int) -> int:
        return self.next() % limit

    def chance(self, percent: int) -> bool:
        return self.below(100) < percent


def jitter(x: int, y: int, salt: int = 0) -> int:
    """0-99, fixed per position: makes region borders look natural."""
    value = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
    value = (value ^ (value >> 13)) * 1274126177 & 0xFFFFFFFF
    return (value >> 8) % 100


# --- Tileset ---------------------------------------------------------------


class Cell:
    """One 32 x 32 tile being drawn."""

    def __init__(self, fill=CLEAR) -> None:
        self.px = [[fill for _ in range(CELL)] for _ in range(CELL)]

    def put(self, x: int, y: int, colour) -> None:
        if 0 <= x < CELL and 0 <= y < CELL:
            self.px[y][x] = tuple(colour) + (255,) * (4 - len(colour))

    def rect(self, x: int, y: int, w: int, h: int, colour) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, colour)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, colour) -> None:
        for y in range(CELL):
            for x in range(CELL):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, colour)

    def speckle(self, noise: Noise, count: int, colour, size: int = 2) -> None:
        for _ in range(count):
            self.rect(noise.below(CELL - size), noise.below(CELL - size), size, size, colour)


def draw_rock() -> Cell:
    cell = Cell()
    cell.ellipse(16, 18, 13, 10, (78, 78, 82))
    cell.ellipse(15.5, 17, 11.5, 8.5, (128, 128, 132))
    cell.ellipse(12, 13.5, 5, 3, (166, 166, 170))
    cell.rect(19, 21, 4, 2, (98, 98, 102))
    return cell


def draw_floor() -> Cell:
    cell = Cell((185, 138, 82))
    for y in range(0, CELL, 8):
        cell.rect(0, y, CELL, 1, (142, 101, 54))
    for row, x in enumerate((6, 21, 13, 27)):
        cell.rect(x, row * 8 + 1, 1, 7, (158, 114, 64))
    noise = Noise(5)
    cell.speckle(noise, 6, (201, 156, 98), 1)
    return cell


def draw_wall() -> Cell:
    cell = Cell((110, 98, 90))
    for y in range(0, CELL, 8):
        cell.rect(0, y, CELL, 1, (74, 63, 58))
        offset = 0 if (y // 8) % 2 == 0 else 8
        for x in range(offset, CELL, 16):
            cell.rect(x, y, 1, 8, (74, 63, 58))
    noise = Noise(6)
    cell.speckle(noise, 8, (130, 118, 108), 2)
    return cell


def draw_bridge() -> Cell:
    cell = Cell((156, 107, 58))
    for x in range(0, CELL, 6):
        cell.rect(x, 0, 1, CELL, (110, 72, 35))
    cell.rect(0, 0, CELL, 3, (90, 58, 28))
    cell.rect(0, CELL - 3, CELL, 3, (90, 58, 28))
    for x in range(3, CELL, 12):
        cell.rect(x, 1, 2, 1, (201, 162, 39))
        cell.rect(x, CELL - 2, 2, 1, (201, 162, 39))
    return cell


def draw_sand() -> Cell:
    cell = Cell((220, 197, 140))
    noise = Noise(8)
    cell.speckle(noise, 10, (196, 171, 112), 2)
    cell.speckle(noise, 6, (236, 218, 170), 1)
    return cell


def draw_flowers(grass: Cell) -> Cell:
    cell = Cell()
    cell.px = [row[:] for row in grass.px]
    noise = Noise(9)
    for colour in ((228, 143, 192), (243, 211, 74), (240, 240, 240), (228, 143, 192)):
        for _ in range(3):
            x, y = 2 + noise.below(27), 2 + noise.below(27)
            cell.rect(x, y, 2, 2, colour)
            cell.put(x + 1, y + 2, (40, 80, 36))
    return cell


def draw_forest_floor() -> Cell:
    cell = Cell((47, 90, 41))
    noise = Noise(10)
    cell.speckle(noise, 8, (91, 74, 46), 2)
    cell.speckle(noise, 8, (36, 72, 33), 2)
    return cell


def draw_dirt() -> Cell:
    cell = Cell((142, 108, 69))
    noise = Noise(11)
    cell.speckle(noise, 7, (110, 82, 54), 2)
    cell.speckle(noise, 5, (168, 134, 90), 2)
    return cell


def draw_mud() -> Cell:
    cell = Cell((95, 84, 52))
    noise = Noise(12)
    for _ in range(4):
        cell.rect(noise.below(26), noise.below(28), 4 + noise.below(3), 2, (74, 90, 90))
    cell.speckle(noise, 6, (78, 68, 40), 2)
    return cell


def draw_reeds() -> Cell:
    cell = Cell()
    noise = Noise(13)
    for x in range(2, CELL - 2, 3):
        top = 6 + noise.below(12)
        colour = (154, 162, 58) if noise.chance(50) else (192, 192, 96)
        cell.rect(x, top, 1, CELL - 2 - top, colour)
        cell.rect(x, top - 3, 1, 3, (122, 90, 42))
    return cell


def draw_wheel() -> Cell:
    cell = Cell()
    for y in range(2, CELL, 8):
        cell.rect(1, y, CELL - 2, 4, (122, 82, 48))
        cell.rect(1, y, CELL - 2, 1, (150, 104, 62))
    cell.rect(14, 0, 4, CELL, (201, 162, 39))
    cell.rect(15, 0, 1, CELL, (232, 196, 82))
    return cell


def draw_tileset(tiles: dict[str, dict[str, str]]) -> list[list[tuple]]:
    rows_needed = max(int(row["tileset_index"]) for row in tiles.values()) // TILESET_COLUMNS + 1
    width, height = TILESET_COLUMNS * CELL, rows_needed * CELL
    canvas = [[CLEAR for _ in range(width)] for _ in range(height)]

    old_width, old_height, old = read_png(TILESET)
    keep = min(4, old_width // CELL) if old_height >= CELL else 0
    old_cells = {}
    for index in range(keep):
        cell = Cell()
        cell.px = [old[y][index * CELL:(index + 1) * CELL] for y in range(CELL)]
        old_cells[index] = cell

    drawers = {
        "rock": draw_rock, "floor": draw_floor, "wall": draw_wall, "bridge": draw_bridge,
        "sand": draw_sand, "forest_floor": draw_forest_floor, "dirt": draw_dirt,
        "mud": draw_mud, "reeds": draw_reeds, "wheel": draw_wheel,
    }
    grass = old_cells.get(int(tiles["grass"]["tileset_index"]), Cell((58, 107, 53)))
    for tile_id, row in tiles.items():
        index = int(row["tileset_index"])
        if index in old_cells:
            cell = old_cells[index]
        elif tile_id == "flowers":
            cell = draw_flowers(grass)
        elif tile_id in drawers:
            cell = drawers[tile_id]()
        else:
            cell = Cell(hex_colour(row["colour"]))
        ox, oy = (index % TILESET_COLUMNS) * CELL, (index // TILESET_COLUMNS) * CELL
        for y in range(CELL):
            canvas[oy + y][ox:ox + CELL] = cell.px[y]
    return canvas


# --- World map ---------------------------------------------------------------


def inside_ellipse(x: int, y: int, cx: float, cy: float, rx: float, ry: float, salt: int) -> bool:
    wobble = 1.0 + (jitter(x, y, salt) - 50) / 250.0
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= wobble


def draw_world(kinds: dict[str, dict[str, str]]) -> list[list[tuple]]:
    grid = [["meadow"] * WORLD_SIZE for _ in range(WORLD_SIZE)]
    regions = [
        ("forest", 14, 12, 12, 8),
        ("hills", 38, 23, 8, 9),
        ("marsh", 10, 37, 8, 6),
        ("lake", 36, 38, 6, 4),
        ("mountain", 40, 6, 9, 5),
        ("mountain", 44, 44, 4, 3),
        ("lake", 10, 10, 1.6, 1.6),
    ]
    for salt, (kind, cx, cy, rx, ry) in enumerate(regions):
        for y in range(WORLD_SIZE):
            for x in range(WORLD_SIZE):
                if inside_ellipse(x, y, cx, cy, rx, ry, salt):
                    grid[y][x] = kind
    for x in range(WORLD_SIZE):
        grid[0][x] = "mountain"
        if jitter(x, 1, 9) < 45:
            grid[1][x] = "mountain"
    for x in range(4, 45):
        grid[24][x] = "road"
    for y in range(8, 24):
        grid[y][12] = "road"
    grid[23][24] = "meadow"
    grid[25][24] = "meadow"
    grid[24][24] = "handmade"
    return [[hex_colour(kinds[kind]["colour"]) for kind in row] for row in grid]


# --- Start square (Mill Road) ------------------------------------------------


def draw_start_square(tiles: dict[str, dict[str, str]]) -> list[list[tuple]]:
    grid = [["grass"] * SQUARE for _ in range(SQUARE)]
    noise = Noise(2024)
    middle = range(30, 34)

    def put(x: int, y: int, tile: str) -> None:
        if 0 <= x < SQUARE and 0 <= y < SQUARE:
            grid[y][x] = tile

    # Forest edge in the north-west, thinning towards the road.
    for y in range(1, 23):
        for x in range(1, 28):
            depth = min(23 - y, 28 - x)
            if noise.chance(min(70, 20 + depth * 6)):
                put(x, y, "tree")
            elif noise.chance(25):
                put(x, y, "forest_floor")
    # Scattered trees, rocks and flowers elsewhere.
    for y in range(1, SQUARE - 1):
        for x in range(1, SQUARE - 1):
            if grid[y][x] != "grass":
                continue
            roll = noise.below(1000)
            if roll < 18:
                put(x, y, "tree")
            elif roll < 24:
                put(x, y, "rock")
    for cx, cy in ((10, 44), (22, 52), (36, 47), (56, 40), (14, 58), (50, 56), (60, 50)):
        for y in range(cy - 2, cy + 3):
            for x in range(cx - 3, cx + 4):
                if grid[y][x] == "grass" and noise.chance(55):
                    put(x, y, "flowers")

    # Border: trees all round.
    for i in range(SQUARE):
        for x, y in ((i, 0), (i, SQUARE - 1), (0, i), (SQUARE - 1, i)):
            put(x, y, "tree")

    # Trails north and south (grass), the road west to east (path).
    for y in range(0, SQUARE):
        for x in middle:
            if grid[y][x] in ("tree", "rock", "flowers", "forest_floor"):
                put(x, y, "grass")
    for x in range(0, SQUARE):
        for y in middle:
            put(x, y, "path" if y in (31, 32) else "grass")

    # The Sombrecuivre river, its sandy banks and the bridge.
    for y in range(0, SQUARE):
        for x in (44, 45, 46):
            put(x, y, "water")
        if 0 < y < SQUARE - 1 and y not in range(19, 35):
            if noise.chance(60):
                put(43, y, "sand")
            if noise.chance(60):
                put(47, y, "sand")
    for x in (43, 44, 45, 46, 47):
        put(x, 31, "bridge")
        put(x, 32, "bridge")
    for x in (43, 47):
        put(x, 30, "grass")
        put(x, 33, "grass")

    # The old mill: stone walls, a wooden floor, a door on the road side and
    # the brass-axled wheel turning (once) in the river.
    for y in range(19, 28):
        for x in range(50, 60):
            edge = y in (19, 27) or x in (50, 59)
            put(x, y, "wall" if edge else "floor")
    put(54, 27, "floor")
    put(55, 27, "floor")
    for y in range(21, 25):
        put(47, y, "wheel")
        put(48, y, "wheel")
    for y in range(28, 30):
        for x in range(51, 59):
            put(x, y, "grass")

    # Markers stand on open ground: keep them and their neighbours clear.
    for mx, my in ((16, 31), (45, 31), (54, 29)):
        for y in range(my - 1, my + 2):
            for x in range(mx - 1, mx + 2):
                if grid[y][x] in ("tree", "rock"):
                    put(x, y, "grass")

    return [[hex_colour(tiles[tile]["colour"]) for tile in row] for row in grid]


def main() -> int:
    parser = argparse.ArgumentParser(description="Draw the placeholder map art.")
    parser.add_argument("--force", action="store_true", help="overwrite existing images")
    args = parser.parse_args()

    tiles = read_table(CONTENT / "maps" / "tiles.csv")
    kinds = read_table(CONTENT / "maps" / "kinds.csv")
    jobs = [
        (TILESET, lambda: draw_tileset(tiles), True),
        (WORLD, lambda: draw_world(kinds), False),
        (START_SQUARE, lambda: draw_start_square(tiles), False),
    ]
    for path, draw, alpha in jobs:
        if path.exists() and not args.force and not (path == TILESET and _is_old_tileset()):
            print(f"kept {path.relative_to(REPO_ROOT)} (use --force to redraw)")
            continue
        rows = draw()
        path.parent.mkdir(parents=True, exist_ok=True)
        write_png(path, len(rows[0]), len(rows), rows, alpha=alpha)
        print(f"wrote {path.relative_to(REPO_ROOT)} ({len(rows[0])} x {len(rows)})")
    return 0


def _is_old_tileset() -> bool:
    """The Beta-0.2 tileset had only 4 tiles; it is always extended."""
    width, height, _ = read_png(TILESET)
    return (width, height) == (4 * CELL, CELL)


if __name__ == "__main__":
    raise SystemExit(main())
