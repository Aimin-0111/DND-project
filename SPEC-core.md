# Spec: `core` (state, rules, dice)

*Module of [SPEC.md](SPEC.md). Depends on: nothing. Used by: `dm`, `main-screen` (and later `combat`, `balance-tools`). When: M1 (state, dice, changes), M2 (saves, Rewind).*

## Objective

Hold **the one game state** and every rule that changes it. Everything else displays the state (`main-screen`, `world`) or proposes changes to it (`dm`). Because the state is one plain JSON-shaped object, saves, Rewind and the AI prompt all read the same thing and can't disagree.

`core` has no screen and no nodes, so all of it can be tested headless.

## Contract: the state (version 1)

The real game starts at **version 1**. The v1→v3 migrations in `examples/godot/core/save_system.gd` were demos.

```json
{
  "version": 1,
  "seed": 12345,
  "rng_state": 0,
  "turn": 0,
  "time_minutes": 480,
  "location": "mill_road",
  "weather": "clear",
  "hero": {
    "name": "Kael", "class": "ranger", "level": 1, "xp": 0,
    "hp": 12, "hp_max": 12, "ac": 14,
    "abilities": {"str": 12, "dex": 16, "con": 13, "int": 10, "wis": 14, "cha": 8},
    "skills": {"Stealth": 5, "Survival": 4, "Perception": 4}
  },
  "gold": 10,
  "pack": [{"id": "rusty_sword", "qty": 1}, {"id": "healing_draught", "qty": 2}],
  "quests": {"the_silent_mill": {"stage": 0, "done": false}},
  "creatures": [{"id": "rust_wolf", "near": "mill_bridge"}],
  "last_roll": null,
  "story_summary": "",
  "log": []
}
```

| Field | Meaning | Rules |
|---|---|---|
| `version` | State format version | Bumped, with a migration, whenever the shape changes (from M2, when saves exist) |
| `seed`, `rng_state` | Dice seed and current position in the dice sequence | `rng_state` saved after every roll |
| `turn` | Completed AI turns | +1 per completed turn |
| `time_minutes` | Minutes since day 1, 00:00 | Never goes back |
| `location` | Place id where the hero is | Must be a known place id |
| `weather` | `clear`, `rain`, `fog`, `storm`, `snow`, `ash` | — |
| `hero` | Character sheet | `0 <= hp <= hp_max` |
| `gold` | Coins | `>= 0` |
| `pack` | Items carried, stacked by id | `1 <= qty <= 99` |
| `quests` | quest id → stage and done flag | Stage never goes down; `done` never goes back to `false` |
| `creatures` | Creatures present in the world (same id can appear twice) | At most 6 at once |
| `last_roll` | Result of the last roll the AI asked for, until it is sent in the next prompt | `null` when none |
| `story_summary` | Rolling "story so far" text for the AI | Filled by `dm` |
| `log` | Every turn: action, AI reply text, roll results (for Rewind and replays) | M2 |

**Ids** in the state (`location`, item, quest, creature ids) come from `content`. `core` doesn't check them against content: `dm` already did. `core` re-checks only the numbers (defence in depth).

## Interface

Names are provisional (GDScript style); the behaviour is the contract.

| Function | Does | When |
|---|---|---|
| `new_game(seed) -> state` | Starting state above (fixed hero until Q-4 is answered) | M1 |
| `apply_changes(state, changes)` | Applies `hp_delta`, `gold_delta`, `time_advance_minutes`, `add_items`, `quest_updates`, clamped to the rules in the table | M1 |
| `apply_commands(state, commands, dice)` | State side of the checked commands. First clears `last_roll` (it was sent in this turn's prompt). Then `move_to` sets `location`, `spawn`/`despawn` edit `creatures`, `weather` sets `weather`, `request_roll` rolls at once and fills `last_roll`. `emote` changes nothing. (M2 may replace the instant roll with a Roll button) | M1 |
| `skill_check(state, skill, dc, dice) -> result` | d20 + skill modifier against DC. Modifier = hero's skill value if listed, else the ability modifier `floor((score - 10) / 2)` of the skill's ability | M1 |
| `skills() -> list` | The skill list and each skill's ability (Athletics→str, Acrobatics→dex, Stealth→dex, Perception→wis, Investigation→int, Persuasion→cha, Insight→wis, Survival→wis) | M1 |
| `clock_text(time_minutes, lang) -> text` | "Day 1, 08:00" / "Jour 1, 08:00" | M1 |
| Dice: `roll(sides, count, bonus)`, `roll_notation("2d6+3")`, `check(modifier, dc, advantage)` | Seeded; `check` always rolls two d20s so the sequence doesn't depend on advantage | M1 |
| `snapshot(state) -> copy` | Deep copy taken before each turn | M2 |
| `save(state, slot)`, `load(slot)`, `export_text(state)`, `import_text(text)` | JSON saves with migrations | M2 |

## Acceptance criteria

**M1**
- [ ] `new_game` with the same seed gives identical states; the state round-trips through JSON text unchanged (after int conversion).
- [ ] Dice: the same seed gives the same sequence; `roll_notation` accepts `d20`, `2d6+3`, `1d8-1` and rejects `2d`, `abc`, `d0` with an error result, never a crash.
- [ ] `check` with advantage keeps the higher d20, with disadvantage the lower, and in all three cases consumes exactly two d20s.
- [ ] `apply_changes` clamps: HP 12 + 30 → 12; HP 5 − 30 → 0; gold 10 − 200 → 0; `time_advance_minutes` 2000 → 1440; negative time → 0.
- [ ] Numbers given as floats (`3.0`, as JSON gives them) work the same as integers.
- [ ] `add_items` stacks an existing id (`qty` +1) or adds a new entry; `qty` never exceeds 99.
- [ ] `quest_updates` can start a quest and move it forward, but never lowers a stage or un-finishes a quest.
- [ ] `apply_commands`: `move_to` sets `location`; `spawn` adds a creature (a 7th is refused with an error); `despawn` removes the most recently added creature with that id, and does nothing (with an error) if none is present; `weather` sets `weather`; `request_roll` fills `last_roll` with skill, DC, d20, modifier, total and success.
- [ ] Unknown keys in `changes` are ignored and reported, not applied.
- [ ] No `core` function needs a scene, a node or the network.

**M2**
- [ ] Save then load gives an identical state, including `rng_state` (the next roll is the same as without saving).
- [ ] `import_text` refuses non-JSON, a missing `version`, and a version newer than the game; it never loads engine resource files.
- [ ] Each migration has a test that loads a saved file of the old version.
- [ ] Rewind restores the snapshot taken before the turn, dice position included.

## Tests

- Automated logic tests for every row above (bad-input cases included).
- Fixture: one saved state per version from M2 on (`tests/fixtures/saves/v1.json`, …), kept forever.

## Boundaries (module)

- **Always:** clamp numbers here even though `dm` checked them; convert JSON numbers with `int()`.
- **Ask first:** any change to the state shape (it touches saves, the prompt and every module).
- **Never:** let `core` call the AI, read files from `content/` directly, or touch nodes.

## Open questions

- Q-4 (fixed hero or character creation) and Q-5 (what happens at 0 HP), see [SPEC.md](SPEC.md#open-questions).
- XP and level-up rules: M2 or M3?
- Using items (drinking a healing draught): a player button (M2) or only through the AI's `state` changes?
