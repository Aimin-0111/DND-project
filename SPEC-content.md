# Spec: `content` (the team's files)

*Module of [SPEC.md](SPEC.md). Depends on: nothing. Used by: `narration`, `dm`, `world`, `main-screen` (and later `balance-tools`). When: M1.*

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
| `items.csv` | `id, name_en, name_fr, type, price, damage, ac_bonus, heal, weight, icon, description_en, description_fr` | `type` ∈ weapon, armor, potion, tool, quest. `damage`/`heal` are dice notation or empty |
| `monsters.csv` | `id, name_en, name_fr, level, hp, ac, attack_bonus, damage, xp, habitat, sprite` | `habitat` is a `|` list |
| `quests.csv` | `quest, stage, title_en, title_fr` | One row per stage, stages 0, 1, 2… with no gaps |
| `keywords.csv` | `effect, lang, words` | `effect` ∈ burn, freeze, shock, poison, whisper, holy. `lang` ∈ en, fr. `words` is a `|` list |
| `ui_text.csv` | `key, en, fr` | Every UI string (used by `main-screen`) |

The example files in `examples/content/data/` move here, with `name`/`description` split into `_en`/`_fr` columns.

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

## Acceptance criteria (M1)

- [ ] The example content, converted to the formats above and completed for M1 (place pages for `mill_road`, `mill_bridge`, `mill_bridge_east`; a `quests.csv` for `the_silent_mill`; `ui_text.csv`; `intro-*.md`), loads with **zero errors**.
- [ ] One crafted bad file per check produces the expected message with the right file and line, and the game still starts.
- [ ] A `;`-separated CSV saved by French Excel loads the same as a `,` one.
- [ ] Accented French words (`brûlant`, `éclair`) survive loading unchanged.
- [ ] `allowed_ids()` for that content lists exactly 5 places, 5 creatures, 6 items, 1 quest (`the_silent_mill`) and 1 NPC (`oda_miller`).
- [ ] `codex_text()` is identical across two loads (stable order).
- [ ] Loading all content takes under 1 second in the web build.
- [ ] Nothing in `content` writes to `game/content/`.

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
