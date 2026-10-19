"""Check Brasswake Reach content before the game loads it.

Usage:
    python3 tools/content_check.py --check --langs fr,en

The checker is deliberately dependency-free and strict: it validates CSV
schemas, ids, dice notation, bilingual strings, keyword pairs and matching
lore files. It exits non-zero on the first batch of problems so a typo never
reaches the game.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

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
}

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


def check_strings(content: Path, langs: list[str], problems: list[str]) -> None:
    path = content / "i18n" / "strings.csv"
    rows = read_csv(path, problems)
    if not rows:
        return

    header = set(rows[0].keys())
    if not {"key", *langs} <= header:
        problems.append(f"{path}: must contain key,{','.join(langs)}")
        return

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
    check_data(content, problems)
    check_keywords(content, langs, problems)
    check_strings(content, langs, problems)
    check_lore(content, langs, problems)

    if problems:
        for problem in problems:
            print(f"ERROR: {problem}", file=sys.stderr)
        print(f"FAILED: {len(problems)} content problem(s)", file=sys.stderr)
        return 1

    print(f"OK: content looks good ({', '.join(langs)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
