# Spec: `core` (state, rules, dice)

*Module of [SPEC.md](SPEC.md). Depends on: `map` (only to apply travel: the world grid is passed in as data). Used by: `dm`, `main-screen` (and later `combat`, `balance-tools`). When: M1 (state, dice, changes), Beta-0.3 (state v2: squares and travel), Beta-0.4 (state v3: Steam, XP and levels, equipment, items you use), M2 (saves, Rewind).*

## Objective

Hold **the one game state** and every rule that changes it. Everything else displays the state (`main-screen`, `world`) or proposes changes to it (`dm`). Because the state is one plain JSON-shaped object, saves, Rewind and the AI prompt all read the same thing and can't disagree.

`core` has no screen and no nodes, so all of it can be tested headless.

## Contract: the state (version 2)

The real game started at **version 1** (M1, Beta-0.2). **Version 2** (Beta-0.3, November 2, 2026) adds the grid of squares: `square`, `hero_cell`, `squares`, and a `square` on each creature. Version 1 saves still load (migration below). The v1→v3 migrations in `examples/godot/core/save_system.gd` were demos.

```json
{
  "version": 2,
  "seed": 12345,
  "rng_state": 0,
  "turn": 0,
  "time_minutes": 480,
  "location": "mill_road",
  "square": "sq_24_24",
  "hero_cell": [16, 31],
  "squares": {
    "sq_24_24": {"cell": [16, 31]},
    "sq_25_24": {"cell": [0, 31], "tiles": {"legend": ["grass", "tree", "path"], "rows": ["1111…", "…"]}}
  },
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
  "creatures": [{"id": "rust_wolf", "near": "mill_bridge", "square": "sq_24_24"}],
  "last_roll": null,
  "story_summary": "",
  "log": []
}
```

| Field | Meaning | Rules |
|---|---|---|
| `version` | State format version | Bumped, with a migration, whenever the shape changes (from M2, when saves exist) |
| `seed`, `rng_state` | Dice seed and current position in the dice sequence. The seed also drives square generation (which never touches the dice) | `rng_state` saved after every roll |
| `turn` | Completed AI turns | +1 per completed turn |
| `time_minutes` | Minutes since day 1, 00:00 | Never goes back |
| `location` | Place id where the hero is, or `""` between places (v2) | A known place id of the current square, or `""` |
| `square` | Id of the square the hero is in (`sq_<x>_<y>`, [SPEC-map.md](SPEC-map.md)) | A square that exists; v2 |
| `hero_cell` | The hero's tile in that square, `[x, y]` | 0–63, walkable; v2 |
| `squares` | Every square the hero has visited → `cell`: where the hero last stood there; `tiles`: the stored tiles of a **generated** square (hand-made squares are never stored) | Generated tiles never change once stored; v2 |
| `weather` | `clear`, `rain`, `fog`, `storm`, `snow`, `ash` | — |
| `hero` | Character sheet | `0 <= hp <= hp_max` |
| `gold` | Coins | `>= 0` |
| `pack` | Items carried, stacked by id | `1 <= qty <= 99` |
| `quests` | quest id → stage and done flag | Stage never goes down; `done` never goes back to `false` |
| `creatures` | Creatures present in the world (same id can appear twice). Each has `id`, `near` (a place id or `hero`) and `square`; one spawned near the hero also keeps its `cell` | At most 6 in one square. They stay in their square when the hero leaves |
| `last_roll` | Result of the last roll the AI asked for, until it is sent in the next prompt | `null` when none |
| `story_summary` | Rolling "story so far" text for the AI | Filled by `dm` |
| `log` | Every turn: action, AI reply text, roll results (for Rewind and replays) | M2 |

**Ids** in the state (`location`, item, quest, creature ids) come from `content`. `core` doesn't check them against content: `dm` already did. `core` re-checks only the numbers (defence in depth).

**Tiles in the save.** A generated square's `tiles` are a `legend` (tile ids, from `tiles.csv`) and 64 `rows` of 64 characters, one character per tile: `0`–`9`, `a`–`z`, `A`–`Z` index the legend. Storing ids, not tile numbers, keeps old saves right when the artist reorders `tiles.csv`. A stored id that no longer exists loads as the first walkable ground tile. Broken or missing stored tiles are generated again (generation is deterministic, so they come out the same).

**Never in the prompt:** `squares` (stored tiles) and `hero_cell` stay out of the AI's state view; the AI gets the MAP part instead ([SPEC-dm.md](SPEC-dm.md#the-prompt)).

## State version 3 (Beta-0.4)

Decided on November 4, 2026, for the backpack and the bars of [SPEC-main-screen.md](SPEC-main-screen.md#layout-v2-beta-04). The details were chosen by Claude on the lead's behalf, and the lead can change any number. Version 3 adds Steam, equipment, the hotbar and events, and gives `level` and `xp` their rules. Version 2 and version 1 saves still load (migrations below).

```json
{
  "version": 3,
  "hero": {
    "name": "Kael", "class": "ranger", "level": 1, "xp": 0,
    "hp": 12, "hp_max": 12, "steam": 6, "steam_max": 6, "ac": 14,
    "abilities": {"str": 12, "dex": 16, "con": 13, "int": 10, "wis": 14, "cha": 8},
    "skills": {"Stealth": 5, "Survival": 4, "Perception": 4}
  },
  "equipment": {"head": "", "body": "", "weapon": "rusty_sword", "off_hand": "", "feet": "", "trinket": ""},
  "hotbar": ["healing_draught", "", "", ""],
  "pack": [{"id": "healing_draught", "qty": 2}, {"id": "brass_tonic", "qty": 1}, {"id": "leather_jerkin", "qty": 1}],
  "events": []
}
```

(Only the fields that are new or changed are shown. The rest is as in version 2.)

| Field | Meaning | Rules |
|---|---|---|
| `hero.steam`, `hero.steam_max` | Steam: the hero's magic power (light steampunk magic) | `0 <= steam <= steam_max`. `steam_max` comes from `levels.csv` |
| `hero.level`, `hero.xp` | Level and experience (in the state since v1, with rules from v3) | `level` is the highest row of `levels.csv` whose `xp` is at or below the hero's `xp`. It never goes down |
| `hero.ac` | **Base** armour class, without equipment (meaning from v3) | The shown armour class is `ac` plus the `ac_bonus` of each equipped item |
| `equipment` | Slot → item id, or `""` | Slots: `head`, `body`, `weapon`, `off_hand`, `feet`, `trinket`. An item goes only in the slot named by its `slot` column. Equipped items are **not** in `pack` |
| `hotbar` | 4 item ids or `""` (keys 1–4) | Only usable items (they heal or give Steam). A binding whose item is no longer in `pack` is cleared |
| `events` | Short English lines about what the player did between two replies ("used healing_draught: +6 HP") | At most 10; the oldest is dropped. Sent in prompt part 7, then cleared by `apply_commands`, like `last_roll` |

`core` never reads content files: the item table (`items.csv`) and the level table (`levels.csv`) are passed in as data, like the world grid.

**New game (v3):**
- the rusty sword is equipped;
- the pack holds Healing Draught ×2, Brass Tonic ×1 and Leather Jerkin ×1, so the first player can try Use and Equip;
- the Healing Draught is on hotbar slot 1;
- Steam starts at 6/6.

**Version 2 → 3 migration:**
- adds `steam` and `steam_max` from `levels.csv` for the hero's level (6/6 at level 1 if the table can't be read);
- adds every `equipment` slot as `""`, `hotbar` as `["", "", "", ""]`, and `events` as `[]`;
- leaves `ac` unchanged.

Nothing is equipped by the migration: the player equips from the backpack.

## Interface

Names are provisional (GDScript style); the behaviour is the contract.

| Function | Does | When |
|---|---|---|
| `new_game(seed) -> state` | Starting state above (fixed hero until Q-4 is answered) | M1 |
| `apply_changes(state, changes)` | Applies `hp_delta`, `gold_delta`, `time_advance_minutes`, `add_items`, `quest_updates`, clamped to the rules in the table | M1 |
| `apply_commands(state, commands, dice, map)` | State side of the checked commands. First clears `last_roll` (it was sent in this turn's prompt). Then `travel` moves the hero to another square (below; at most one per turn, always first), `move_to` sets `location` and puts `hero_cell` on the place's marker, `spawn`/`despawn` edit `creatures` **of the current square**, `weather` sets `weather`, `request_roll` rolls at once and fills `last_roll`. `emote` changes nothing. (M2 may replace the instant roll with a Roll button) | M1, Beta-0.3 |
| travel (inside `apply_commands`) | Resolves the destination ([SPEC-map.md](SPEC-map.md#travel-the-geography-side)), remembers the tile the hero leaves, generates and stores the destination's tiles on a first visit, sets `square`, `hero_cell` (the arrival tile) and `location` (the place at the arrival tile, or `""`), and adds the square to `squares`. It writes the destination `square` and arrival `cell` into the travel command so `world` plays the same arrival. A travel that can't be resolved changes nothing and is noted | Beta-0.3 |
| `set_hero_cell(state, map, cell)` | The hero stopped walking: stores `hero_cell` and sets `location` to the place whose area holds that tile, or `""` | Beta-0.3 |
| `settle(state, map)` | After a new game or a load: fills and checks `square` and `hero_cell` (from `location` for a v1 save, otherwise the start place `mill_road`), puts the current square in `squares`, gives each creature without a square the square of its place, and moves a hero standing on a blocked tile to the closest walkable one | Beta-0.3 |
| `square_tiles(state, map, square)` | The tiles of a square: a hand-made square's PNG, or a generated square's stored tiles (generated and stored if missing) | Beta-0.3 |
| `skill_check(state, skill, dc, dice) -> result` | d20 + skill modifier against DC. Modifier = hero's skill value if listed, else the ability modifier `floor((score - 10) / 2)` of the skill's ability | M1 |
| `skills() -> list` | The skill list and each skill's ability (Athletics→str, Acrobatics→dex, Stealth→dex, Perception→wis, Investigation→int, Persuasion→cha, Insight→wis, Survival→wis) | M1 |
| `clock_text(time_minutes, lang) -> text` | "Day 1, 08:00" / "Jour 1, 08:00" | M1 |
| Dice: `roll(sides, count, bonus)`, `roll_notation("2d6+3")`, `check(modifier, dc, advantage)` | Seeded; `check` always rolls two d20s so the sequence doesn't depend on advantage | M1 |
| `apply_changes`, Beta-0.4 keys | `xp_gain` (0–300, clamped), then the level-up check below; `steam_delta` (−30 … +30 like `hp_delta`, then `steam` is clamped to 0 … `steam_max`) | Beta-0.4 |
| Level-up (inside `apply_changes` and after any `xp` change) | While `xp` reaches the next row of `levels.csv`: `level` +1, `hp_max` and `steam_max` take that row's values, and `hp` and `steam` rise by the same amounts as their maximums. Several levels at once work; the last row is the highest level. The result says how many levels were gained (for the "Level 2!" pop-up) | Beta-0.4 |
| `use_item(state, item_id, items, dice) -> result` | Refused (nothing changes, an error comes back) if the item isn't in `pack`, isn't usable (no `heal` and no `steam`), or would restore nothing (HP and Steam already full for what it gives). Otherwise: `heal` is rolled with the dice (a number or dice notation; the dice sequence moves on) and added to `hp` up to `hp_max`; `steam` the same way for `steam`; `qty` −1 (the entry is removed at 0, and its hotbar binding cleared); an event is added. The result holds what was gained | Beta-0.4 |
| `equip(state, item_id, items)` | The item must be in `pack` and have a `slot`. One is moved from `pack` to `equipment[slot]`; the item that was there goes back to `pack` | Beta-0.4 |
| `unequip(state, slot)` | Moves the slot's item back to `pack` (stacked, at most 99) | Beta-0.4 |
| `set_hotbar(state, index, item_id)` | `index` 0–3. A usable item in `pack`, or `""` to clear. An item already bound to another slot moves to this one | Beta-0.4 |
| `armor_class(state, items)` | `hero.ac` + each equipped item's `ac_bonus` | Beta-0.4 |
| `attack_bonus(state, items)` | Proficiency (2 + floor((level − 1) / 4)) + the higher of the str and dex modifiers + the equipped weapon's `attack_bonus`. Provisional until `combat` (M3) | Beta-0.4 |
| `snapshot(state) -> copy` | Deep copy taken before each turn | M2 |
| `save(state, slot)`, `load(slot)`, `export_text(state)`, `import_text(text)` | JSON saves with migrations. Slots: `manual` (Save button) and `auto` (every turn). `slots_newest_first(slots)` lists the slots that have a file, the last written first (file time; on a tie the earlier slot in the list), for Load and Resume (Beta-0.3). The save folder can be pointed elsewhere for tests. **v1 → v2:** adds `square: ""`, `hero_cell: []`, `squares: {}` and `square: ""` on each creature; `settle` then fills them from the v1 `location` and the creatures' places. **v2 → v3:** see [State version 3](#state-version-3-beta-04) | M2 (v1 → v2: Beta-0.3; v2 → v3: Beta-0.4) |

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

**Beta-0.3**
- [ ] `new_game` gives version 2; after `settle`, the hero is in the square that holds `mill_road`, on its marker tile, and that square is in `squares`.
- [ ] A Beta-0.2 (version 1) save loads: version 2, the square of its `location`, the hero on that place's marker, each creature in the square of its place.
- [ ] `travel` north from the start square: the hero is in the north neighbour, on its south edge, `location` is `""`, the old square remembers the tile left, the new square's tiles are stored; travelling back by id puts the hero on the tile it left. The dice sequence is unchanged.
- [ ] A second `travel` in one turn is ignored and noted; a travel `core` can't resolve changes nothing and is noted.
- [ ] After a travel, `spawn` and `move_to` in the same turn act in the destination square; `spawn near hero` keeps the hero's tile.
- [ ] Creatures stay in their square: leaving and coming back finds them; a 7th creature in one square is refused, a creature in another square doesn't count.
- [ ] A stored generated square survives save and load unchanged; tile ids reordered in `tiles.csv` don't change it; broken stored tiles are generated again.
- [ ] `set_hero_cell` on a tile inside a place's area sets that place; elsewhere it sets `""`.

**Beta-0.4**
- [ ] `new_game` gives version 3:
  - Steam 6/6;
  - the rusty sword equipped;
  - Healing Draught ×2, Brass Tonic ×1 and Leather Jerkin ×1 in the pack;
  - the Healing Draught on hotbar slot 1.
- [ ] A version 2 save (new fixture `tests/fixtures/saves/v2.json`) loads as version 3 with the fields of the migration. A version 1 save still loads (v1 → v2 → v3).
- [ ] **XP:**
  - `xp_gain` 350 is clamped to 300 and noted;
  - crossing 300 XP gives level 2: `hp_max` 20, `hp` +8, `steam_max` 9, `steam` +3;
  - crossing two levels at once works;
  - at the last level nothing breaks;
  - the level never goes down.
- [ ] **Steam:** `steam_delta` is clamped to −30 … +30, and `steam` to 0 … `steam_max`.
- [ ] **`use_item("healing_draught")`:**
  - HP rises by the 2d4+2 roll (the same seed gives the same roll), never above `hp_max`;
  - `qty` drops by 1;
  - the last one removes the entry and clears its hotbar slot;
  - an event is added.
- [ ] **Refused uses:** an item not in the pack, an item that isn't usable, or a use at full HP and Steam changes nothing and returns an error.
- [ ] **Equipment:**
  - `equip` and `unequip` move items between the pack and the slots, and the old item goes back to the pack;
  - an item with no slot is refused;
  - `armor_class` and `attack_bonus` follow: base 14 + Leather Jerkin 1 = 15.
- [ ] **Hotbar:** `set_hotbar` refuses an item that isn't usable or isn't in the pack, and moves an item already bound elsewhere.
- [ ] **Events:** at most 10 are kept, and `apply_commands` clears them.

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
- **Never:** let `core` call the AI, read files from `content/` directly, or touch nodes. (The map files are read by `map`; `core` gets the loaded world as data.)

## Open questions

- Q-4 (fixed hero or character creation) and Q-5 (what happens at 0 HP), see [SPEC.md](SPEC.md#open-questions).
- ~~XP and level-up rules: M2 or M3?~~ Beta-0.4: `levels.csv` and `xp_gain` (above).
- ~~Using items: a player button or only through the AI?~~ Beta-0.4: the player uses items from the backpack or the hotbar. The DM learns about it from `events`.
- For the lead: the numbers in `levels.csv` and `items.csv`, and the XP the DM may give per turn (300 now), are first guesses to tune.
