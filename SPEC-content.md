# Spec: `content` (the team's files)

*Module of [SPEC.md](SPEC.md). Depends on: nothing. Used by: `narration`, `dm`, `map`, `world`, `main-screen` (and later `balance-tools`). When: M1, Beta-0.3 (map files).*

## Objective

Load the artist's and the writer's files **as they make them**, check them, and give the rest of the game simple lookups by id. A teammate adds or changes a file in OneDrive, the lead copies it into `game/content/`, and the game picks it up with no code change.

When a file has a mistake, the game says **which file, which line and what's wrong**, in words a teammate understands, and keeps running with the rest.

## Contract: file formats

All files live under `game/content/`. **This spec owns these formats**; changing them is an "ask first" item because the team relies on them.

### Tables (`data/*.csv`)

- **Encoding:** UTF-8. Excel's default "CSV" save on Windows is not UTF-8 and breaks accents: the checker must detect it and say "save as *CSV UTF-8*".
- **Separator:** `,` or `;` (French Excel uses `;`). The loader detects it from the header line.
- **Lists inside a cell:** separated by `|` (`forest|road`).
- First row = column names. Empty lines are ignored.

| File | Columns | Notes |
|---|---|---|
| `items.csv` | Beta-0.4: `id, type, price, slot, ac_bonus, attack_bonus, damage, heal, steam` (M1 to Beta-0.3 shipped only `id, type, price`, and the names went to `strings.csv`; the planned name, weight and icon columns were never used) | `type` ∈ weapon, armor, potion, tool, quest. `slot` ∈ head, body, weapon, off_hand, feet, trinket, or empty. `ac_bonus` and `attack_bonus` are whole numbers or empty. `damage`, `heal` and `steam` are dice notation (`2d4+2`), a whole number, or empty. An item is **usable** when it has `heal` or `steam`. Names and descriptions are in `strings.csv` (`item.<id>.name`, `item.<id>.desc`, both languages); icons are looked up as today |
| `levels.csv` | `level, xp, hp_max, steam_max` (Beta-0.4) | Levels 1, 2, 3… with no gaps; `xp` starts at 0 and goes up. First guesses: 1 / 0 / 12 / 6, 2 / 300 / 20 / 9, 3 / 900 / 28 / 12, 4 / 2700 / 36 / 15, 5 / 6500 / 44 / 18 |
| `monsters.csv` | `id, name_en, name_fr, level, hp, ac, attack_bonus, damage, xp, habitat, sprite` | `habitat` is a `|` list |
| `quests.csv` | `quest, stage, title_en, title_fr` | One row per stage, stages 0, 1, 2… with no gaps |
| `keywords.csv` | `effect, lang, words` | `effect` ∈ burn, freeze, shock, poison, whisper, holy. `lang` ∈ en, fr. `words` is a `|` list |
| `ui_text.csv` | `key, en, fr` | Every UI string (used by `main-screen`) |
| `locations.csv` | `id, square, x, y` | Beta-0.2 file (`id`); Beta-0.3 adds where each place's marker is: the hand-made square's id (`sq_<x>_<y>`) and the tile inside it (0–63). The writer's place pages don't change |

The example files in `examples/content/data/` move here, with `name`/`description` split into `_en`/`_fr` columns.

**Beta-0.4 checks** (`content_check.py` and the Godot loader):
- **Errors:**
  - a `slot` outside the list;
  - a bad whole number or dice notation;
  - an item with a `slot` whose `type` isn't weapon or armor;
  - a missing `item.<id>.name`;
  - `levels.csv` with a gap, or with an `xp` that doesn't go up.
- **Warnings:** a missing `item.<id>.desc`, or a missing icon (the placeholder shows).

Beta-0.4 adds two items for the first backpack:
- `leather_jerkin`: armor, body slot, `ac_bonus` 1, price 10;
- `brass_tonic`: potion, `steam` `1d4+1`, price 20.

Their names are in `strings.csv`, for the writer to review. Their icons are left to the artist.

### Writing (`writing/`)

| Path | Contents |
|---|---|
| `dm-rules.md` | The DM instructions sent on every turn (one file; `dm` adds the language line) |
| `intro-en.md`, `intro-fr.md` | The opening narration of a new game, also the first "story so far" |
| `places/*.md` | One or more places per file |
| `npcs/*.md` | One NPC per file (template: `examples/content/writing/pnj-modele.md`) |
| `lore/*.md` | World background with no id |

- Each `## Title` line starts a new entry.
- An entry gets an id from a line `- **Identifiant** : <id>` (or `- **Id** : <id>`). Place entries' ids are the **allowed locations**; NPC entries' ids are the allowed `who` for emotes.
- The whole text of every entry goes to the AI as the Codex, in a fixed order (by folder, then file name) so the prompt prefix stays the same between turns (needed for prompt caching).

### Maps (`maps/`)

Beta-0.3, decided by the lead on November 2, 2026. The rules behind these files (squares, exits, generation) are in [SPEC-map.md](SPEC-map.md). The artist works in this one folder; a French guide is in [docs/GUIDE-CARTES.md](docs/GUIDE-CARTES.md).

| File | Contents |
|---|---|
| `world.png` | The world map. **One pixel = one square**; the pixel's colour is the square's kind. Any size: the world is as big as the image |
| `kinds.csv` | `id, colour, passable`: one row per kind. Starter kinds: `meadow`, `forest`, `hills`, `road`, `marsh` (`passable` = `true`), `lake`, `mountain` (`false`). The reserved kind `handmade` (`#ff00ff`, magenta) marks hand-made squares |
| `tiles.csv` | `id, colour, walkable, layer, tileset_index`: one row per tile. `layer` is `ground` or `obstacle` (obstacle tiles always block, so their `walkable` is `false`). `tileset_index` counts 32 × 32 cells in `art/tiles-placeholder.png` from 0, left to right then row by row. Adding a tile needs no code |
| `squares.csv` | `file, x, y, kind`: one row per hand-made square. `file` is the PNG in `squares/`; `x`, `y` is its pixel on `world.png` (so its id is `sq_<x>_<y>`); `kind` is the kind it counts as for its name and its neighbours (not `handmade`) |
| `squares/*.png` | The hand-made squares: **64 × 64 pixels, one pixel = one tile**, coloured with the `tiles.csv` colours. Names: lowercase, digits, `-` or `_` |

- **Colours** are written `#rrggbb` (hexadecimal, as image editors show them). Only red, green and blue count; transparency is ignored. A colour may appear only once in its table.
- `passable` and `walkable` are `true` or `false`.
- **Display names** of kinds are in `i18n/strings.csv` as `kind.<id>.name` (French and English), like the place names.
- **Godot:** the map PNGs are imported as **Image** (`Import As: Image`), so the game can read their pixels in an exported build. A PNG the editor imports as a texture still works (the game reads its image), but the Image import is lighter. The CSVs are imported as "Keep File".

### Art (`art/`)

- File names follow `examples/content/art/GUIDE-ARTISTE.md`: `tiles-*`, `hero-*`, `creature-*`, `npc-*`, `npc-*-portrait`, `item-*`, `fx-*`. PNG with transparency, or `.aseprite`.
- Tables point at art by file name (`items.csv` → `icon`, `monsters.csv` → `sprite`). A missing image is a **warning** and the game shows a placeholder.

## Interface

| Function | Returns |
|---|---|
| `load_all()` | Loads everything once at start. Bad rows are skipped and reported |
| `problems()` | List of `{file, line, severity: error/warning, message}`. Messages in plain words, e.g. `monsters.csv line 4: "2d" is not dice notation (example: 2d6+1)` |
| `item(id)`, `monster(id)`, `quest_stages(id)`, `place(id)`, `npc(id)` | One record, or nothing |
| `display_name(id, lang)` | The `name_en`/`name_fr` (or entry title) of any id |
| `allowed_ids()` | `{locations, creatures, items, quests, npcs}`. `dm` adds `skills` from `core` |
| `codex_text()` | All place, NPC and lore text for the AI, in fixed order |
| `dm_rules()`, `intro(lang)` | The texts above |
| `keywords(lang)` | Keyword rows for one language |
| `ui_text(key, lang)` | One UI string; falls back to English when the French cell is empty (with a warning) |
| `art_path(file_name)` | Path to the image, or the placeholder |

## Checks

| Check | Severity |
|---|---|
| A required file is missing (`dm-rules.md`, `items.csv`, `monsters.csv`, `keywords.csv`, `ui_text.csv`) | error |
| A required column is missing | error |
| Duplicate id in one table, or the same id used for a place and an NPC | error |
| An id isn't lowercase ASCII `snake_case` (`^[a-z][a-z0-9_]*$`) | error (row skipped) |
| A number column holds text; dice notation is invalid; `type`, `effect` or `lang` isn't in its list | error (row skipped) |
| A quest's stages have a gap | error |
| A place/NPC entry has no id line | warning (it becomes lore) |
| A file isn't valid UTF-8 | error, message says how to re-save it |
| A referenced image is missing; a `ui_text` French cell is empty | warning |
| A place id has no marker in any zone (`world` reports its markers) | warning |
| **Maps (Beta-0.3)** | |
| A colour in `world.png` or a square PNG matches no row of `kinds.csv` / `tiles.csv` (reported with the pixel position; at most 20 positions per file, then a count) | error (that square can't be entered, that tile blocks) |
| A hand-made square PNG isn't 64 × 64; `world.png` is empty; the tileset isn't a whole number of 32 px cells | error |
| A `tileset_index` is outside the tileset; an obstacle tile is marked walkable; a colour or id appears twice; `passable`/`walkable` isn't `true`/`false` | error |
| A tile the generator needs is missing from `tiles.csv` (`grass`, `path`, `water`, `tree`, `rock`, `flowers`, `forest_floor`, `dirt`, `mud`, `reeds`) | error |
| A hand-made square is off the world map, two share a pixel, its file is missing, or its `kind` is unknown | error |
| A magenta pixel has no hand-made square in `squares.csv` | error |
| A hand-made square's pixel isn't painted magenta | warning |
| A place in `locations.csv` has a square that isn't hand-made, a tile outside 0–63 or a tile the hero can't walk on | error |
| A place has no square (the hero can never reach it) | warning |
| An exit of a hand-made square faces a square the hero can't enter (outside the map, `lake`, `mountain`…) | warning |
| A passable kind has no generation recipe yet (it will look like a meadow); a kind has no `kind.<id>.name` in `strings.csv` | warning; error for the name |

## Acceptance criteria (M1)

- [ ] The example content, converted to the formats above and completed for M1 (place pages for `mill_road`, `mill_bridge`, `mill_bridge_east`; a `quests.csv` for `the_silent_mill`; `ui_text.csv`; `intro-*.md`), loads with **zero errors**.
- [ ] One crafted bad file per check produces the expected message with the right file and line, and the game still starts.
- [ ] A `;`-separated CSV saved by French Excel loads the same as a `,` one.
- [ ] Accented French words (`brûlant`, `éclair`) survive loading unchanged.
- [ ] `allowed_ids()` for that content lists exactly 5 places, 5 creatures, 6 items, 1 quest (`the_silent_mill`) and 1 NPC (`oda_miller`).
- [ ] `codex_text()` is identical across two loads (stable order).
- [ ] Loading all content takes under 1 second in the web build.
- [ ] Nothing in `content` writes to `game/content/`.

## Acceptance criteria (Beta-0.3)

- [ ] `tools/content_check.py --check` reads `world.png`, the square PNGs, `kinds.csv`, `tiles.csv`, `squares.csv` and the new `locations.csv` columns with the Python standard library only, and passes on the real files.
- [ ] Crafted bad files give each map check above, with the file and the pixel position.
- [ ] The game reads the map PNGs in an exported build (imported as Image).

## Tests

- Automated: the content check runs on the real `game/content/` files (must pass before each commit and build), and on a `tests/fixtures/content-bad/` folder of broken files with expected messages.
- Manual: the artist and writer get a short French guide per format (update `GUIDE-ARTISTE.md`, add a guide for tables).

## Boundaries (module)

- **Always:** report problems in plain words with file and line; keep going after a bad row.
- **Ask first:** renaming a column, a folder or a file name rule.
- **Never:** edit or rewrite a teammate's file; run anything found in a content file.

## Open questions

- Q-3: Codex pages in both languages or French only? (Affects the Codex tab in M2, not the AI.)
- Q-1 (Q15): does the writer prefer Word? If so, who converts `.docx` to Markdown: the writer (save as text) or a lead's tool?
- Godot note (if Godot is kept): data CSVs must be imported as "Keep File", while `ui_text.csv` can use Godot's built-in translation import. Both need `*.csv, *.md` in the export filters (see `release`).
