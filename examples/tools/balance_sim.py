"""Brasswake balance tools (Python).

Two jobs, both on the same CSV files the game loads:

  python balance_sim.py --check
      Checks the data files for mistakes before the game runs
      (missing columns, duplicate ids, bad dice like "1d" or "2x6").

  python balance_sim.py
      Simulates thousands of fights between the hero and each monster, with
      the same d20 rules as the game, and prints how dangerous each one is.

Only the standard library is used, so it runs with a plain Python install.
"""

import argparse
import csv
import random
import re
import statistics
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "content" / "data"
DICE = re.compile(r"^(\d*)d(\d+)([+-]\d+)?$")

# A level 1 hero, like GameState.new_game(). Edit to test other builds.
HERO = {"name": "Kael (ranger 1)", "hp": 12, "ac": 14, "attack_bonus": 5, "damage": "1d8+3"}

REQUIRED = {
    "monsters.csv": ["id", "name", "level", "hp", "ac", "attack_bonus", "damage", "xp"],
    "items.csv": ["id", "name", "type", "price"],
    "keywords.csv": ["effect", "lang", "words"],
}
EFFECTS = {"burn", "freeze", "shock", "poison", "whisper", "holy"}


def read_csv(name: str) -> list[dict]:
    with open(DATA / name, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def roll(notation: str, rng: random.Random) -> int:
    m = DICE.match(notation.strip().lower())
    if not m:
        raise ValueError(f"bad dice: {notation!r}")
    count = int(m.group(1) or 1)
    total = sum(rng.randint(1, int(m.group(2))) for _ in range(count))
    return total + int(m.group(3) or 0)


# ---------------------------------------------------------------- check

def check() -> int:
    problems = []
    for name, columns in REQUIRED.items():
        rows = read_csv(name)
        missing = [c for c in columns if c not in rows[0]]
        if missing:
            problems.append(f"{name}: missing columns {missing}")
            continue
        if "id" in columns:
            ids = [r["id"] for r in rows]
            for dup in {i for i in ids if ids.count(i) > 1}:
                problems.append(f"{name}: duplicate id {dup!r}")
            for i in ids:
                if not re.fullmatch(r"[a-z0-9_]+", i):
                    problems.append(f"{name}: id {i!r} must be lowercase letters, digits, _")
        for line, row in enumerate(rows, start=2):  # line 1 is the header
            for col in ("damage", "heal"):
                value = (row.get(col) or "").strip()
                if value and not DICE.match(value):
                    problems.append(f"{name} line {line}: {col} {value!r} is not dice notation")
            for col in ("level", "hp", "ac", "attack_bonus", "xp", "price"):
                value = (row.get(col) or "").strip()
                if col in row and value and not value.lstrip("-").isdigit():
                    problems.append(f"{name} line {line}: {col} {value!r} is not a whole number")
            if name == "keywords.csv" and row["effect"] not in EFFECTS:
                problems.append(f"keywords.csv line {line}: unknown effect {row['effect']!r}")
    for p in problems:
        print("PROBLEM:", p)
    print("OK: data files look good" if not problems else f"\n{len(problems)} problem(s) found")
    return 1 if problems else 0


# ---------------------------------------------------------------- simulate

def fight(monster: dict, rng: random.Random) -> tuple[bool, int, int]:
    """One fight to the death. Returns (hero_won, rounds, hero_hp_left)."""
    hero_hp, monster_hp = HERO["hp"], int(monster["hp"])
    rounds = 0
    while hero_hp > 0 and monster_hp > 0:
        rounds += 1
        # Hero attacks: d20 + bonus against the monster's armour (AC).
        d20 = rng.randint(1, 20)
        if d20 == 20 or (d20 != 1 and d20 + HERO["attack_bonus"] >= int(monster["ac"])):
            monster_hp -= roll(HERO["damage"], rng) * (2 if d20 == 20 else 1)
        if monster_hp <= 0:
            break
        d20 = rng.randint(1, 20)
        if d20 == 20 or (d20 != 1 and d20 + int(monster["attack_bonus"]) >= HERO["ac"]):
            hero_hp -= roll(monster["damage"], rng) * (2 if d20 == 20 else 1)
    return hero_hp > 0, rounds, max(hero_hp, 0)


def simulate(fights: int, seed: int) -> None:
    rng = random.Random(seed)   # seeded: the same numbers every run
    print(f"Hero: {HERO['name']}  HP {HERO['hp']}  AC {HERO['ac']}  "
          f"attack +{HERO['attack_bonus']}  damage {HERO['damage']}")
    print(f"{fights} fights per monster, seed {seed}\n")
    print(f"{'monster':<16}{'lvl':>4}{'win %':>8}{'rounds':>8}{'HP left':>9}  verdict")
    for m in read_csv("monsters.csv"):
        results = [fight(m, rng) for _ in range(fights)]
        win = 100 * sum(r[0] for r in results) / fights
        rounds = statistics.mean(r[1] for r in results)
        hp_left = statistics.mean(r[2] for r in results if r[0]) if win else 0
        verdict = ("too easy" if win > 95 else "fair" if win > 70
                   else "hard" if win > 40 else "deadly")
        print(f"{m['name']:<16}{m['level']:>4}{win:>7.0f}%{rounds:>8.1f}{hp_left:>9.1f}  {verdict}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="only check the data files")
    parser.add_argument("--fights", type=int, default=5000)
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()
    if args.check:
        sys.exit(check())
    simulate(args.fights, args.seed)
