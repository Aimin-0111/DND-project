"""Draw the Beta-0.5 rooms and add the mill's front door to the Mill Road.

Usage:
    python tools/make_rooms.py            # writes missing rooms only
    python tools/make_rooms.py --force    # rewrites the rooms and the Mill Road

A room is a box of any size, off the world grid, reached through doors
(maps/doors.csv). Like a hand-made square, its PNG has one pixel per tile, in
the colours of maps/tiles.csv, so the artist can repaint it in any paint
program. This script only makes the first versions from the text plans below.
Needs Pillow.

It writes, in game/content/maps/:
- rooms/mill-inside.png   18 x 12, indoor: the mill's ground floor
- rooms/mill-cellar.png   14 x 10, indoor: the cellar, where the boss waits
- rooms/mill-yard.png     24 x 16, outdoor: the yard behind the mill
- squares/mill-road.png   the mill gets a roof, a front wall and a door
  (with --force only: the artist may have changed this file)
"""

from __future__ import annotations

import argparse
import csv
import random
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
MAPS = REPO_ROOT / "game" / "content" / "maps"

LEGEND = {
    "W": "wall", "D": "door", ".": "floor", "s": "stone_floor", "c": "cave_floor",
    "R": "rug", "T": "table", "B": "barrel", "C": "chest", "H": "hearth", "b": "bed",
    "S": "stairs", "g": "grass", "t": "tree", "u": "bush", ",": "tall_grass",
    "f": "flowers", "p": "path", "d": "dirt", "~": "water", "r": "rock", "o": "roof",
}

MILL_INSIDE = [
    "WWWWWWWWWWWWWWWWWW",
    "WWWWWWWHHWWWWWWWWW",
    "W.....TT...B.B..bW",
    "W...............bW",
    "W.......RRRR.....W",
    "W..T....RRRR.....D",
    "W..T....RRRR.....W",
    "W.......RRRR..C..W",
    "WB...............W",
    "WBB.........S....W",
    "W................W",
    "WWWWWWWWDWWWWWWWWW",
]

MILL_CELLAR = [
    "WWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWW",
    "WcccsssssscBBW",
    "WccssssssssccW",
    "WcsssssssssscW",
    "WcsssssssssscW",
    "WccssssssssccW",
    "WBcccsssscccCW",
    "WScccccccccccW",
    "WWWWWWWWWWWWWW",
]


def yard(rng: random.Random) -> list[str]:
    width, height = 24, 16
    rows = [["g"] * width for _ in range(height)]
    for y in range(height):
        for x in range(width):
            roll = rng.random()
            if roll < 0.12:
                rows[y][x] = ","
            elif roll < 0.17:
                rows[y][x] = "f"
    for x in range(width):  # trees and bushes all round, the mill's back wall on the west
        rows[0][x] = rows[height - 1][x] = "t" if rng.random() < 0.7 else "u"
    for y in range(height):
        rows[y][width - 1] = "t" if rng.random() < 0.7 else "u"
        rows[y][0] = "W"
    rows[7][0] = "D"
    for x in range(1, 15):  # a dirt path from the back door to the pond
        rows[7][x] = "d" if x < 13 else "p"
    for y in range(8, 12):
        rows[y][14] = "p"
    for y in range(10, 14):  # the pond
        for x in range(16, 22):
            if (x - 18.5) ** 2 / 9 + (y - 11.5) ** 2 / 3 <= 1.0:
                rows[y][x] = "~"
    for x, y in ((5, 3), (9, 12), (20, 4)):
        rows[y][x] = "r"
    for x, y in ((3, 11), (11, 3), (18, 6)):
        rows[y][x] = "u"
    return ["".join(row) for row in rows]


def colours() -> dict[str, tuple[int, int, int]]:
    out = {}
    with (MAPS / "tiles.csv").open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            text = row["colour"].lstrip("#")
            out[row["id"]] = (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16))
    return out


def paint(plan: list[str], path: Path, table: dict) -> None:
    width = len(plan[0])
    for line in plan:
        if len(line) != width:
            raise SystemExit(f"{path.name}: every row of the plan must be {width} characters: {line!r}")
    image = Image.new("RGB", (width, len(plan)))
    for y, line in enumerate(plan):
        for x, symbol in enumerate(line):
            image.putpixel((x, y), table[LEGEND[symbol]])
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def add_mill_door(table: dict) -> None:
    """The mill on the Mill Road (x 50-59, y 19-27) was an open floor; it gets
    a roof, a two-tile front wall and the door at (54, 27)."""
    path = MAPS / "squares" / "mill-road.png"
    image = Image.open(path).convert("RGB")
    for y in range(19, 28):
        for x in range(50, 60):
            tile = "roof" if y < 26 else "wall"
            image.putpixel((x, y), table[tile])
    image.putpixel((54, 27), table["door"])
    image.save(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="rewrite the rooms and the Mill Road")
    args = parser.parse_args()
    table = colours()
    rooms = {
        "mill-inside.png": MILL_INSIDE,
        "mill-cellar.png": MILL_CELLAR,
        "mill-yard.png": yard(random.Random("mill-yard")),
    }
    for name, plan in rooms.items():
        path = MAPS / "rooms" / name
        if path.exists() and not args.force:
            print(f"kept    {path.relative_to(REPO_ROOT)}")
            continue
        paint(plan, path, table)
        print(f"wrote   {path.relative_to(REPO_ROOT)}")
    if args.force:
        add_mill_door(table)
        print("wrote   game/content/maps/squares/mill-road.png (the mill door)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
