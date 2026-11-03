"""Check Brasswake Reach content before the game loads it.

Usage:
    python3 tools/content_check.py --check --langs fr,en

The checker is deliberately dependency-free and strict: it validates CSV
schemas, ids, dice notation, bilingual strings, keyword pairs, matching lore
files and (Beta-0.3) the map files: world.png, the hand-made square PNGs,
kinds.csv, tiles.csv, squares.csv and the place markers. It exits non-zero
on the first batch of problems so a typo never reaches the game. Warnings
are printed but don't fail the check.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

from pngio import PngError, read_png, read_size

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONTENT = REPO_ROOT / "game" / "content"

ID_RE = re.compile(r"^[a-z0-9_]+$")
DICE_RE = re.compile(r"^(\d*)d(\d+)([+-]\d+)?$")
EFFECTS = {"burn", "freeze", "shock", "poison", "whisper", "holy"}
M1_EFFECTS = ("burn", "freeze", "shock")

DATA_SCHEMAS = {
    "monsters.csv": ("id", "level", "hp", "ac", "attack_bonus", "damage", "xp"),
    "items.csv": ("id", "type", "price"),
    "locations.csv": ("id",),
    "quests.csv": ("id", "max_stage"),
}

REQUIRED_IDS = {
    "monsters.csv": {"rust_wolf"},
    "items.csv": {"rusty_sword", "healing_draught"},
    "locations.csv": {"mill_road", "mill_bridge", "old_mill"},
    "quests.csv": {"the_silent_mill"},
}

REQUIRED_KEYS = {
    "ui.title",
    "ui.act",
    "ui.roll",
    "ui.save",
    "ui.load",
    "ui.language",
    "ui.error",
    "ui.ready",
    "ui.turn_action",
    "hero.kael.name",
    "location.mill_road.name",
    "location.mill_bridge.name",
    "location.old_mill.name",
    "npc.oda.name",
    "monster.rust_wolf.name",
    "item.rusty_sword.name",
    "item.healing_draught.name",
    "quest.the_silent_mill.title",
    "quest.the_silent_mill.stage0",
    "quest.the_silent_mill.stage1",
    "quest.the_silent_mill.stage2",
    "travel.north",
    "travel.east",
    "travel.south",
    "travel.west",
    "ui.way_blocked",
}

# Beta-0.3 map files (SPEC-map.md, SPEC-content.md).
SQUARE_SIZE = 64
TILE_PX = 32
EXIT_CELLS = range(30, 34)
COLOUR_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
SQUARE_ID_RE = re.compile(r"^sq_(0|[1-9][0-9]*)_(0|[1-9][0-9]*)$")
SQUARE_FILE_RE = re.compile(r"^[a-z0-9_-]+\.png$")
HANDMADE = "handmade"
LAYERS = {"ground", "obstacle"}
# Tile ids the square generator paints with (game/map/square_generator.gd).
GENERATOR_TILES = {"grass", "path", "water", "tree", "rock", "flowers", "forest_floor", "dirt", "mud", "reeds"}
# Kinds the generator has a recipe for; other passable kinds look like meadows.
GENERATOR_KINDS = {"meadow", "forest", "hills", "road", "marsh"}
MAX_PIXELS_REPORTED = 20
BIG_WORLD = 1024
TILESET = Path("art") / "tiles-placeholder.png"

INT_COLUMNS = {
    "level",
    "hp",
    "ac",
    "attack_bonus",
    "xp",
    "price",
    "max_stage",
}


def read_csv(path: Path, problems: list[str]) -> list[dict[str, str]]:
    if not path.exists():
        problems.append(f"missing file: {path}")
        return []
    try:
        with path.open(encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            rows = list(reader)
    except OSError as exc:
        problems.append(f"{path}: cannot read ({exc})")
        return []
    if not reader.fieldnames:
        problems.append(f"{path}: empty file")
        return []
    return rows


def check_data(content: Path, problems: list[str]) -> None:
    for name, required_columns in DATA_SCHEMAS.items():
        path = content / "data" / name
        rows = read_csv(path, problems)
        if not rows:
            if path.exists():
                problems.append(f"{path}: no data rows")
            continue

        header = list(rows[0].keys())
        missing = [column for column in required_columns if column not in header]
        if missing:
            problems.append(f"{path}: missing columns {missing}")
            continue

        seen: set[str] = set()
        for line, row in enumerate(rows, start=2):
            row_id = (row.get("id") or "").strip()
            if not row_id:
                problems.append(f"{path}:{line}: empty id")
            elif not ID_RE.fullmatch(row_id):
                problems.append(f"{path}:{line}: id {row_id!r} must match [a-z0-9_]+")
            elif row_id in seen:
                problems.append(f"{path}:{line}: duplicate id {row_id!r}")
            seen.add(row_id)

            for column in INT_COLUMNS & set(required_columns):
                value = (row.get(column) or "").strip()
                if value == "":
                    problems.append(f"{path}:{line}: empty {column}")
                    continue
                try:
                    int(value)
                except ValueError:
                    problems.append(f"{path}:{line}: {column} must be an integer, got {value!r}")

            if "damage" in required_columns:
                damage = (row.get("damage") or "").strip()
                if not DICE_RE.fullmatch(damage):
                    problems.append(f"{path}:{line}: bad dice notation {damage!r}")

        required = REQUIRED_IDS.get(name, set())
        missing_ids = required - seen
        if missing_ids:
            problems.append(f"{path}: missing M1 ids {sorted(missing_ids)}")


def check_keywords(content: Path, langs: list[str], problems: list[str]) -> None:
    path = content / "data" / "keywords.csv"
    rows = read_csv(path, problems)
    if not rows:
        return

    header = set(rows[0].keys())
    if not {"effect", "lang", "words"} <= header:
        problems.append(f"{path}: must contain effect,lang,words")
        return

    found: dict[tuple[str, str], set[str]] = {}
    for line, row in enumerate(rows, start=2):
        effect = (row.get("effect") or "").strip()
        lang = (row.get("lang") or "").strip()
        words = (row.get("words") or "").strip()
        if effect not in EFFECTS:
            problems.append(f"{path}:{line}: unknown effect {effect!r}")
            continue
        if lang not in langs:
            problems.append(f"{path}:{line}: unknown lang {lang!r}")
            continue
        parsed = [word.strip() for word in words.split("|") if word.strip()]
        if not parsed:
            problems.append(f"{path}:{line}: empty words")
            continue
        bucket = found.setdefault((effect, lang), set())
        for word in parsed:
            key = word.casefold()
            if key in bucket:
                problems.append(f"{path}:{line}: duplicate word {word!r}")
            bucket.add(key)

    for lang in langs:
        for effect in M1_EFFECTS:
            if not found.get((effect, lang)):
                problems.append(f"{path}: missing {effect!r} words for {lang!r}")


def check_strings(content: Path, langs: list[str], problems: list[str]) -> set[str]:
    """Checks strings.csv and returns its keys (the map check needs them)."""
    path = content / "i18n" / "strings.csv"
    rows = read_csv(path, problems)
    if not rows:
        return set()

    header = set(rows[0].keys())
    if not {"key", *langs} <= header:
        problems.append(f"{path}: must contain key,{','.join(langs)}")
        return set()

    seen: set[str] = set()
    for line, row in enumerate(rows, start=2):
        key = (row.get("key") or "").strip()
        if not key:
            problems.append(f"{path}:{line}: empty key")
            continue
        if key in seen:
            problems.append(f"{path}:{line}: duplicate key {key!r}")
        seen.add(key)
        for lang in langs:
            if not (row.get(lang) or "").strip():
                problems.append(f"{path}:{line}: missing {lang!r} for {key!r}")

    missing = REQUIRED_KEYS - seen
    if missing:
        problems.append(f"{path}: missing required keys {sorted(missing)}")
    return seen


def check_lore(content: Path, langs: list[str], problems: list[str]) -> None:
    rules = content / "writing" / "dm-rules.md"
    if not rules.exists() or not rules.read_text(encoding="utf-8").strip():
        problems.append(f"missing or empty: {rules}")
    elif "<<STATE>>" not in rules.read_text(encoding="utf-8"):
        problems.append(f"{rules}: missing <<STATE>> format reminder")

    files_by_lang: dict[str, set[str]] = {}
    for lang in langs:
        folder = content / "writing" / lang
        if not folder.is_dir():
            problems.append(f"missing folder: {folder}")
            files_by_lang[lang] = set()
            continue
        files = {path.name for path in folder.glob("*.md") if path.is_file()}
        files_by_lang[lang] = files
        if not files:
            problems.append(f"{folder}: no .md lore file")
        for path in folder.glob("*.md"):
            if not path.read_text(encoding="utf-8").strip():
                problems.append(f"{path}: empty lore file")

    if not langs:
        return
    reference = files_by_lang[langs[0]]
    for lang in langs[1:]:
        missing = reference - files_by_lang[lang]
        extra = files_by_lang[lang] - reference
        if missing:
            problems.append(f"writing/{lang}: missing lore files {sorted(missing)}")
        if extra:
            problems.append(f"writing/{lang}: extra lore files {sorted(extra)}")


def parse_bool(text: str) -> bool | None:
    value = (text or "").strip().lower()
    if value in {"true", "yes", "1"}:
        return True
    if value in {"false", "no", "0"}:
        return False
    return None


def colour_key(text: str) -> int | None:
    value = (text or "").strip()
    return int(value[1:], 16) if COLOUR_RE.fullmatch(value) else None


def colour_name(key: int) -> str:
    return f"#{key:06x}"


def read_image(path: Path, problems: list[str]):
    """Pixels as 0xRRGGBB rows (alpha ignored), or None with a problem."""
    if not path.exists():
        problems.append(f"missing file: {path}")
        return None
    try:
        width, height, rows = read_png(path)
    except (OSError, PngError) as exc:
        problems.append(f"{path}: cannot read the image ({exc})")
        return None
    return width, height, [[(r << 16) | (g << 8) | b for r, g, b, _ in row] for row in rows]


def report_unknown(path: Path, pixels: list[tuple[int, int, int]], table: str, problems: list[str]) -> None:
    for x, y, key in pixels[:MAX_PIXELS_REPORTED]:
        problems.append(f"{path}: unknown colour {colour_name(key)} at ({x}, {y}); add it to {table} or use a listed colour")
    if len(pixels) > MAX_PIXELS_REPORTED:
        problems.append(f"{path}: and {len(pixels) - MAX_PIXELS_REPORTED} more pixels with unknown colours")


def check_columns(path: Path, rows: list[dict[str, str]], columns: tuple[str, ...], problems: list[str]) -> bool:
    missing = [column for column in columns if column not in rows[0]]
    if missing:
        problems.append(f"{path}: missing columns {missing}")
        return False
    return True


def check_tile_table(content: Path, problems: list[str]) -> dict[int, tuple[str, bool]]:
    """tiles.csv: returns colour -> (tile id, walkable)."""
    path = content / "maps" / "tiles.csv"
    rows = read_csv(path, problems)
    if not rows or not check_columns(path, rows, ("id", "colour", "walkable", "layer", "tileset_index"), problems):
        return {}
    cells = 0
    tileset = content / TILESET
    try:
        width, height = read_size(tileset)
        if width % TILE_PX or height % TILE_PX:
            problems.append(f"{tileset}: {width} x {height} is not a whole number of {TILE_PX} px tiles")
        cells = (width // TILE_PX) * (height // TILE_PX)
    except (OSError, PngError) as exc:
        problems.append(f"{tileset}: cannot read the tileset ({exc})")
    by_colour: dict[int, tuple[str, bool]] = {}
    ids: set[str] = set()
    for line, row in enumerate(rows, start=2):
        tile_id = (row.get("id") or "").strip()
        key = colour_key(row.get("colour") or "")
        walkable = parse_bool(row.get("walkable") or "")
        layer = (row.get("layer") or "").strip()
        index_text = (row.get("tileset_index") or "").strip()
        where = f"{path}:{line}"
        if not ID_RE.fullmatch(tile_id):
            problems.append(f"{where}: id {tile_id!r} must match [a-z0-9_]+")
            continue
        if tile_id in ids:
            problems.append(f"{where}: duplicate id {tile_id!r}")
        ids.add(tile_id)
        if key is None:
            problems.append(f"{where}: colour {row.get('colour')!r} must look like #4c9a3c")
            continue
        if key in by_colour:
            problems.append(f"{where}: colour {colour_name(key)} is already used by {by_colour[key][0]!r}")
        if walkable is None:
            problems.append(f"{where}: walkable must be true or false")
            walkable = False
        if layer not in LAYERS:
            problems.append(f"{where}: layer must be ground or obstacle, got {layer!r}")
        if layer == "obstacle" and walkable:
            problems.append(f"{where}: {tile_id!r} is an obstacle, so walkable must be false")
        if not index_text.isdigit():
            problems.append(f"{where}: tileset_index must be a whole number, got {index_text!r}")
        elif cells and int(index_text) >= cells:
            problems.append(f"{where}: tileset_index {index_text} is outside the tileset ({cells} tiles)")
        by_colour.setdefault(key, (tile_id, bool(walkable) and layer == "ground"))
    for tile_id in sorted(GENERATOR_TILES - ids):
        problems.append(f"{path}: the square generator needs a tile with id {tile_id!r}")
    return by_colour


def check_kind_table(content: Path, string_keys: set[str], problems: list[str], warnings: list[str]) -> dict[int, tuple[str, bool]]:
    """kinds.csv: returns colour -> (kind id, passable)."""
    path = content / "maps" / "kinds.csv"
    rows = read_csv(path, problems)
    if not rows or not check_columns(path, rows, ("id", "colour", "passable"), problems):
        return {}
    by_colour: dict[int, tuple[str, bool]] = {}
    ids: set[str] = set()
    for line, row in enumerate(rows, start=2):
        kind = (row.get("id") or "").strip()
        key = colour_key(row.get("colour") or "")
        passable = parse_bool(row.get("passable") or "")
        where = f"{path}:{line}"
        if not ID_RE.fullmatch(kind):
            problems.append(f"{where}: id {kind!r} must match [a-z0-9_]+")
            continue
        if kind in ids:
            problems.append(f"{where}: duplicate id {kind!r}")
        ids.add(kind)
        if key is None:
            problems.append(f"{where}: colour {row.get('colour')!r} must look like #8fd16a")
            continue
        if key in by_colour:
            problems.append(f"{where}: colour {colour_name(key)} is already used by {by_colour[key][0]!r}")
        if passable is None:
            problems.append(f"{where}: passable must be true or false")
            passable = False
        if kind != HANDMADE:
            if f"kind.{kind}.name" not in string_keys:
                problems.append(f"{where}: add kind.{kind}.name to i18n/strings.csv (French and English)")
            if passable and kind not in GENERATOR_KINDS:
                warnings.append(f"{where}: the generator has no recipe for {kind!r} yet, so it will look like a meadow")
        by_colour.setdefault(key, (kind, bool(passable)))
    if HANDMADE not in ids:
        problems.append(f"{path}: the kind {HANDMADE!r} (magenta, #ff00ff) must exist: it marks hand-made squares")
    return by_colour


def check_maps(content: Path, string_keys: set[str], problems: list[str], warnings: list[str]) -> None:
    maps = content / "maps"
    tiles = check_tile_table(content, problems)
    kinds = check_kind_table(content, string_keys, problems, warnings)

    world_path = maps / "world.png"
    world = read_image(world_path, problems)
    if world is None or not kinds:
        return
    width, height, pixels = world
    if width > BIG_WORLD or height > BIG_WORLD:
        warnings.append(f"{world_path}: {width} x {height} squares is very large; loading may be slow")
    grid: dict[tuple[int, int], str | None] = {}
    unknown = []
    for y, row in enumerate(pixels):
        for x, key in enumerate(row):
            kind = kinds.get(key)
            grid[(x, y)] = kind[0] if kind else None
            if kind is None:
                unknown.append((x, y, key))
    report_unknown(world_path, unknown, "kinds.csv", problems)
    passable = {kind: ok for kind, ok in kinds.values()}

    squares_path = maps / "squares.csv"
    rows = read_csv(squares_path, problems)
    hand_made: dict[tuple[int, int], list[list[int]] | None] = {}
    files: dict[tuple[int, int], str] = {}
    if rows and check_columns(squares_path, rows, ("file", "x", "y", "kind"), problems):
        for line, row in enumerate(rows, start=2):
            where = f"{squares_path}:{line}"
            name = (row.get("file") or "").strip()
            x_text, y_text = (row.get("x") or "").strip(), (row.get("y") or "").strip()
            kind = (row.get("kind") or "").strip()
            if not SQUARE_FILE_RE.fullmatch(name):
                problems.append(f"{where}: file {name!r} must be a .png named with a-z, 0-9, - or _")
                continue
            if not (x_text.isdigit() and y_text.isdigit()):
                problems.append(f"{where}: x and y must be whole numbers of 0 or more")
                continue
            at = (int(x_text), int(y_text))
            if not (at[0] < width and at[1] < height):
                problems.append(f"{where}: {name} at {at} is off the world map ({width} x {height})")
                continue
            if at in hand_made:
                problems.append(f"{where}: two hand-made squares at {at}")
                continue
            if kind == HANDMADE or not passable.get(kind, False):
                problems.append(f"{where}: kind {kind!r} must be a kind from kinds.csv that can be entered")
            if grid.get(at) != HANDMADE:
                warnings.append(f"{where}: paint pixel {at} of world.png magenta (#ff00ff) so {name} stands out")
            hand_made[at] = check_square(maps / "squares" / name, tiles, problems)
            files[at] = name
    for (x, y), kind in sorted(grid.items(), key=lambda item: (item[0][1], item[0][0])):
        if kind == HANDMADE and (x, y) not in hand_made:
            problems.append(f"{world_path}: pixel ({x}, {y}) is magenta but squares.csv has no hand-made square there")
    folder = maps / "squares"
    if folder.is_dir():
        for path in sorted(folder.glob("*.png")):
            if path.name not in files.values():
                warnings.append(f"{path}: not listed in squares.csv, so it is not used")

    def can_enter(at: tuple[int, int]) -> bool:
        if not (0 <= at[0] < width and 0 <= at[1] < height):
            return False
        if at in hand_made:
            return hand_made[at] is not None
        kind = grid.get(at)
        return kind is not None and kind != HANDMADE and passable.get(kind, False)

    walkable = {key: ok for key, (_, ok) in tiles.items()}
    names = {key: tile_id for key, (tile_id, _) in tiles.items()}
    for at, square in sorted(hand_made.items()):
        if square is None:
            continue
        path = maps / "squares" / files[at]
        last = SQUARE_SIZE - 1
        edges = {
            "north": ((0, -1), [(i, 0) for i in range(1, last)]),
            "south": ((0, 1), [(i, last) for i in range(1, last)]),
            "west": ((-1, 0), [(0, i) for i in range(1, last)]),
            "east": ((1, 0), [(last, i) for i in range(1, last)]),
        }
        for direction, ((dx, dy), cells) in edges.items():
            exits = [cell for cell in cells if walkable.get(square[cell[1]][cell[0]], False)]
            beyond = (at[0] + dx, at[1] + dy)
            if exits and not can_enter(beyond):
                what = grid.get(beyond) or "outside the map"
                first = ", ".join(f"({x}, {y})" for x, y in exits[:4])
                more = "…" if len(exits) > 4 else ""
                warnings.append(f"{path}: {len(exits)} exit tile(s) on the {direction} edge ({first}{more}) "
                                f"face square {beyond} ({what}), which the hero can't enter")

    check_markers(content, hand_made, files, walkable, names, problems, warnings)


def check_square(path: Path, tiles: dict[int, tuple[str, bool]], problems: list[str]):
    image = read_image(path, problems)
    if image is None:
        return None
    width, height, pixels = image
    if (width, height) != (SQUARE_SIZE, SQUARE_SIZE):
        problems.append(f"{path}: the image is {width} x {height} pixels, it must be {SQUARE_SIZE} x {SQUARE_SIZE}")
        return None
    unknown = [(x, y, key) for y, row in enumerate(pixels) for x, key in enumerate(row) if key not in tiles]
    report_unknown(path, unknown, "tiles.csv", problems)
    return pixels


def check_markers(content, hand_made, files, walkable, names, problems, warnings) -> None:
    path = content / "data" / "locations.csv"
    rows = read_csv(path, problems)
    if not rows or not check_columns(path, rows, ("id", "square", "x", "y"), problems):
        return
    for line, row in enumerate(rows, start=2):
        place = (row.get("id") or "").strip()
        square = (row.get("square") or "").strip()
        x_text, y_text = (row.get("x") or "").strip(), (row.get("y") or "").strip()
        where = f"{path}:{line}"
        if not square:
            warnings.append(f"{where}: {place!r} has no square, so the hero can never reach it")
            continue
        found = SQUARE_ID_RE.fullmatch(square)
        at = (int(found.group(1)), int(found.group(2))) if found else None
        if at not in hand_made:
            problems.append(f"{where}: {place!r} is in {square!r}, which is not a hand-made square in squares.csv")
            continue
        if not (x_text.isdigit() and y_text.isdigit()) or int(x_text) >= SQUARE_SIZE or int(y_text) >= SQUARE_SIZE:
            problems.append(f"{where}: the marker of {place!r} at ({x_text}, {y_text}) is outside its square (0 to {SQUARE_SIZE - 1})")
            continue
        pixels = hand_made[at]
        if pixels is None:
            continue
        key = pixels[int(y_text)][int(x_text)]
        if not walkable.get(key, False):
            tile = names.get(key, colour_name(key))
            problems.append(f"{where}: the marker of {place!r} at ({x_text}, {y_text}) in {files[at]} is on a blocked tile ({tile})")


def main() -> int:
    parser = argparse.ArgumentParser(description="Check Brasswake content files.")
    parser.add_argument("--check", action="store_true", help="run all content checks")
    parser.add_argument(
        "--content",
        type=Path,
        default=DEFAULT_CONTENT,
        help=f"content root (default: {DEFAULT_CONTENT})",
    )
    parser.add_argument(
        "--langs",
        default="fr,en",
        help="comma-separated languages to require (default: fr,en)",
    )
    args = parser.parse_args()

    if not args.check:
        parser.error("only --check is implemented for now")

    langs = [lang.strip() for lang in args.langs.split(",") if lang.strip()]
    if not langs or any(lang not in {"fr", "en"} for lang in langs):
        parser.error("--langs must be a comma-separated subset of fr,en")

    content = args.content.resolve()
    if not content.is_dir():
        print(f"ERROR: content folder not found: {content}", file=sys.stderr)
        return 1

    problems: list[str] = []
    warnings: list[str] = []
    check_data(content, problems)
    check_keywords(content, langs, problems)
    string_keys = check_strings(content, langs, problems)
    check_lore(content, langs, problems)
    check_maps(content, string_keys, problems, warnings)

    for warning in warnings:
        print(f"WARNING: {warning}", file=sys.stderr)
    if problems:
        for problem in problems:
            print(f"ERROR: {problem}", file=sys.stderr)
        print(f"FAILED: {len(problems)} content problem(s)", file=sys.stderr)
        return 1

    note = f", {len(warnings)} warning(s)" if warnings else ""
    print(f"OK: content looks good ({', '.join(langs)}){note}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
