# M1 task list

*From [plan.md](plan.md) and the approved [SPEC.md](../SPEC.md). Each task: acceptance criteria, how to verify, dependencies, files. Paths are inside `game/` unless they start with `docs/`, `tools/` or `tasks/`.*

Commands used below (Git Bash, see SPEC.md):

```bash
GODOT="/c/2026-2027/DND project/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
```

- **Tests:** `"$GODOT" --headless --path game --script res://tests/run_all.gd`
- **Web export:** `"$GODOT" --headless --path game --export-release "Web" ../builds/web/index.html`
- **Play the web build:** `python -m http.server 8000 --directory builds/web`, then open `http://localhost:8000` (no itch.io upload during M1)

---

## Phase 0: Setup and web spike

### - [ ] Task 1: Godot project skeleton and test runner

**Description:** Create the Godot 4.7 project in `game/` with the SPEC.md folder layout (empty module folders), a 1280×720 base window that stretches, and a small zero-dependency test runner. The runner finds `tests/**/test_*.gd`, runs every `test_*` function, prints a summary, and exits with code 1 on any failure. Assertion helpers live in a shared base script.

**Acceptance criteria:**
- [ ] The editor opens the project with no errors or warnings.
- [ ] A sample passing test → `1 passed, 0 failed`, exit code 0; a sample failing test → exit code 1 and the failing assertion's message.
- [ ] `.godot/` and `builds/` stay git-ignored.

**Verification:** run the tests command, then `echo $?`; `git status` shows no `.godot/` files.

**Dependencies:** none

**Files:** `project.godot`, `tests/run_all.gd`, `tests/test_case.gd`, `tests/test_runner_selfcheck.gd`, `icon.svg`

**Scope:** S

### - [ ] Task 2: Web spike, played locally

**Description:** A small scene that tests everything the engine decision depends on in the browser. It stays after M1 as the diagnostics scene (Task 24 adds the hidden way in):
- a story line with one `[burn]` word (the burn effect moved from `examples/`);
- an on-screen fps counter;
- a **Copy** button that copies text from the click;
- a paste box that shows the pasted length;
- a **Test API** button that calls the Claude API with a key typed into a field at runtime and shows the HTTP status.

Then set up a single-threaded web export preset, export, and play it from `localhost`.

**Acceptance criteria:**
- [ ] In the local web build in Chrome, Edge and Firefox: copied text pastes into another tab; pasting into the box works; the burn word animates.
- [ ] **Test API** shows 401 with a made-up key and 200 with the lead's real key (typed at runtime, never saved).
- [ ] Download size, time to first screen (Chrome "Fast 4G" throttling) and fps are written as build 0 in `docs/BUILDS.md`. Any blocker is reported to the lead before other work continues.

**Verification:** manual on the local web build; the `docs/BUILDS.md` line.

**Dependencies:** Task 1. **Lead:** install the web export templates; type the key.

**Files:** `src/diagnostics/web_check.tscn`, `src/diagnostics/web_check.gd`, `src/narration/effects/burn_effect.gd`, `export_presets.cfg`, `docs/BUILDS.md`

**Scope:** M

### Checkpoint 0
- [ ] The test runner works.
- [ ] The spike runs as a local web build in the three browsers, or a blocker has been discussed with the lead (it may trigger the Phaser switch early).

---

## Phase 1: Foundations

### - [ ] Task 3: Core state v1, dice, applying changes

**Description:** Move `dice.gd` and `game_state.gd` from `examples/godot/core/` into `src/core/` and bring them to the SPEC-core contract:
- state version 1, with `weather`, `creatures` and `last_roll`;
- `new_game(seed)`;
- `apply_changes` with all the clamps: quests never go back; `qty` at most 99; unknown keys are reported.

**Acceptance criteria:**
- [ ] Every SPEC-core M1 criterion about dice, `new_game` and `apply_changes` has a passing test, including bad input (`2d`, `abc`, `d0`, floats from JSON).
- [ ] The same seed gives the same state and the same dice sequence; `check` always consumes two d20s.
- [ ] No node, scene or file access in `src/core/`.

**Verification:** tests command.

**Dependencies:** Task 1

**Files:** `src/core/dice.gd`, `src/core/game_state.gd`, `tests/core/test_dice.gd`, `tests/core/test_game_state.gd`

**Scope:** M

### - [ ] Task 4: Core rules, clock and applying commands

**Description:**
- **`rules.gd`:** the skill list with each skill's ability, `skill_modifier`, `skill_check` and `clock_text(minutes, lang)`.
- **`apply_commands`:** first clears `last_roll`, then handles `move_to`, `spawn` (at most 6 creatures), `despawn` (the most recent of that id), `weather` and `request_roll` (rolls at once).

**Acceptance criteria:**
- [ ] Skill modifier: a listed skill uses its value; an unlisted skill uses `floor((score − 10) / 2)` of its ability.
- [ ] `clock_text(480, "en")` → `Day 1, 08:00`; `clock_text(1530, "fr")` → `Jour 2, 01:30`.
- [ ] Every SPEC-core `apply_commands` criterion has a passing test (7th spawn refused, despawn of an absent creature reported, `last_roll` cleared then refilled).

**Verification:** tests command.

**Dependencies:** Task 3

**Files:** `src/core/rules.gd`, `src/core/game_state.gd`, `tests/core/test_rules.gd`, `tests/core/test_commands.gd`

**Scope:** M

### - [ ] Task 5: CSV reader and table checks

**Description:** Read team CSV files and check them as SPEC-content describes:
- accept a `,` or `;` separator;
- report a file that isn't valid UTF-8 and say how to re-save it;
- convert values to the right types;
- split `|` lists;
- run each table check and report `{file, line, severity, message}` in plain words.

A bad row is skipped and the others are kept. Set the test CSVs to import as "Keep File".

**Acceptance criteria:**
- [ ] The same table saved with `,` and with `;` gives identical rows.
- [ ] One bad fixture file per table check gives the expected message with file and line; the good rows still load.
- [ ] A Windows-1252 file (accents) gives the "save as CSV UTF-8" error.

**Verification:** tests command.

**Dependencies:** Task 1

**Files:** `src/content/csv_reader.gd`, `src/content/table_checks.gd`, `tests/content/test_tables.gd`, `tests/fixtures/content-bad/` (one small file per check)

**Scope:** M

### - [ ] Task 6: M1 data files

**Description:** Create the M1 tables in `content/data/`, converted from `examples/content/data/` to the SPEC-content formats:
- `_en`/`_fr` columns, with French names as placeholders for the writer to review;
- `quests.csv` for `the_silent_mill`, stages 0–2;
- `ui_text.csv` with the first M1 UI keys.

All are set to import as "Keep File", except `ui_text.csv`.

**Acceptance criteria:**
- [ ] The content check reports 0 errors on these files.
- [ ] Accented words (`brûlant`, `éclair`) load unchanged.
- [ ] Every row from the example files is still there.

**Verification:** tests command (the content check runs on the real files).

**Dependencies:** Task 5

**Files:** `content/data/items.csv`, `content/data/monsters.csv`, `content/data/quests.csv`, `content/data/keywords.csv`, `content/data/ui_text.csv`

**Scope:** S

### - [ ] Task 7: Markdown reader, content database, art lookup

**Description:**
- **Markdown reader:** a new entry at each `## `; the id comes from a `- **Identifiant** :` or `- **Id** :` line; an entry without an id becomes lore, with a warning.
- **Content database:** loads everything once and gives `item`, `monster`, `quest_stages`, `place`, `npc`, `display_name`, `allowed_ids`, `codex_text` (fixed order), `dm_rules`, `intro`, `keywords(lang)`, `ui_text` (English fallback with a warning), `art_path` (placeholder plus a warning when the image is missing) and `problems()`.

**Acceptance criteria:**
- [ ] Fixture Markdown files give the expected entries, ids, warnings, and an error when one id is used for both a place and an NPC.
- [ ] `codex_text()` is identical across two loads; `ui_text` falls back to English when the French cell is empty.
- [ ] `art_path` of a missing file returns the placeholder and adds a warning.

**Verification:** tests command.

**Dependencies:** Task 5

**Files:** `src/content/markdown_reader.gd`, `src/content/content_db.gd`, `tests/content/test_writing.gd`, `tests/content/test_content_db.gd`, `content/art/placeholder/missing.png`

**Scope:** M

### - [ ] Task 8: M1 writing files

**Description:** Create the M1 writing in `content/writing/`:
- `dm-rules.md`, from the example, plus:
  - the two fixes from `examples/ai-tests/RESULTS.md` (unknown names don't exist in this world; a move in the story needs a `move_to`);
  - the setting line following the team's tone answer (Q3: magic first, a light steampunk touch);
- `intro-en.md` and `intro-fr.md`;
- one place file with the 5 M1 places, built from `lieu-modele.md`;
- `npcs/oda.md`, from `pnj-modele.md`.

**Acceptance criteria:**
- [ ] The content check reports 0 errors on all real content.
- [ ] `allowed_ids()` lists exactly 5 places, 5 creatures, 6 items, 1 quest (`the_silent_mill`), 1 NPC (`oda_miller`).
- [ ] `dm-rules.md` contains the two fix lines and the new setting line; the intros read well in both languages (the lead checks; the writer reviews later).

**Verification:** tests command; read `dm-rules.md` and the intros.

**Dependencies:** Tasks 6, 7

**Files:** `content/writing/dm-rules.md`, `content/writing/intro-en.md`, `content/writing/intro-fr.md`, `content/writing/places/route-du-moulin.md`, `content/writing/npcs/oda.md`

**Scope:** S

### Checkpoint 1
- [ ] All tests pass; the content check finds 0 errors in the real files.
- [ ] The writer has the data and writing files to review the French.
- [ ] Review with the lead before Phase 2.

---

## Phase 2: First playable text turn

### - [ ] Task 9: Keyword tagging

**Description:** Move `keyword_tagger.gd` into `src/narration/` and add the SPEC-narration safety rules:
- an effect tag only counts as a well-formed, non-nested pair;
- unclosed tags show as text;
- at most 4 AI tags per entry;
- at most 30 characters inside one AI tag;
- at most 6 animated words in total.

It uses `keywords(lang)` from content.

**Acceptance criteria:**
- [ ] Every `tag()` fixture listed in SPEC-narration passes (English and French).
- [ ] Every word in `keywords.csv` gets tagged when it appears in a sample sentence.
- [ ] No markup except the six effect tags survives `tag()`.

**Verification:** tests command.

**Dependencies:** Task 7

**Files:** `src/narration/keyword_tagger.gd`, `tests/narration/test_tagger.gd`

**Scope:** M

### - [ ] Task 10: DM reply checks and fixtures

**Description:** Move `dm_reply_parser.gd` to `src/dm/reply_checker.gd` and add the SPEC-dm checks it lacks:
- `emote` `who` must be the hero or an allowed NPC;
- `dc` must be a whole number;
- at most 3 `add_items`;
- unknown state keys are reported.

Copy the 8 Haiku replies into the fixtures and write one crafted bad reply per SPEC-dm case.

**Acceptance criteria:**
- [ ] The 8 Haiku replies pass with nothing dropped, and the kept commands match RESULTS.md (S3, S4, S5, S8 as listed in SPEC-dm; S1, S2, S6, S7 empty).
- [ ] Every crafted bad reply gives its expected result (dropped, clamped or narration only).
- [ ] The checker never fails on any input (empty text, binary junk, 1 MB of text).

**Verification:** tests command.

**Dependencies:** Tasks 4, 7

**Files:** `src/dm/reply_checker.gd`, `tests/dm/test_reply_checker.gd`, `tests/fixtures/replies/haiku/S1–S8.txt`, `tests/fixtures/replies/bad/*.txt`

**Scope:** M

### - [ ] Task 11: Prompt builder

**Description:** Move `prompt_builder.gd` into `src/dm/` and match the SPEC-dm prompt:
- the 7 parts in order;
- the language line;
- a state view without `seed`, `rng_state` or `log`;
- the last roll result;
- the M1 story so far: intro + last 3 narrations, each cut to 600 characters;
- the single-text version for copy-paste.

**Acceptance criteria:**
- [ ] The parts come in the SPEC order; parts 1–2 are byte-identical for two different states.
- [ ] `seed`, `rng_state`, `log` and any key never appear in the prompt.
- [ ] The language line follows the setting; ids and JSON keys stay English.

**Verification:** tests command.

**Dependencies:** Tasks 4, 7

**Files:** `src/dm/prompt_builder.gd`, `tests/dm/test_prompt_builder.gd`

**Scope:** S

### - [ ] Task 12: DM turn, copy-paste and fake connections

**Description:**
- **Connection interface:** `generate_turn(prompt) -> text`, plus status messages.
- **Copy-paste connection:** moved from `examples/`.
- **Fake connection:** returns a fixture reply, for tests.
- **`play_turn(state, action, lang) -> TurnResult`:** builds the prompt, calls the connection, checks the reply, and keeps the last 3 narrations in memory.

**Acceptance criteria:**
- [ ] With the fake connection, each Haiku fixture gives the expected `TurnResult`.
- [ ] An empty reply → `ok: false` with a status; a reply with no `<<STATE>>` → narration only, no changes.
- [ ] After 4 turns, the story so far holds the intro and only the last 3 narrations.

**Verification:** tests command.

**Dependencies:** Tasks 10, 11

**Files:** `src/dm/dm_turn.gd`, `src/dm/connections/connection.gd`, `src/dm/connections/copy_paste.gd`, `src/dm/connections/fake.gd`, `tests/dm/test_dm_turn.gd`

**Scope:** M

### - [ ] Task 13: Autoloads and the turn loop

**Description:**
- **Autoloads** with wiring only: `Game` (holds the state, emits `state_changed`, calls `core`), `Content`, `DM`.
- **`turn_loop.gd`:** runs SPEC-main-screen steps 1–10. It talks to the story and the world through small interfaces, so tests can use stand-ins.

**Acceptance criteria:**
- [ ] With the fake connection and stand-ins, a turn runs steps 1–10 in order: state changed before the story shows; roll line after `request_roll`; unlock after `commands_finished`.
- [ ] A failed or cancelled turn changes nothing and keeps the action text; a second Act during a turn does nothing.
- [ ] The next prompt after a roll contains the roll result.

**Verification:** tests command.

**Dependencies:** Tasks 9, 12

**Files:** `src/autoload/game.gd`, `src/autoload/content.gd`, `src/autoload/dm.gd`, `src/main_screen/turn_loop.gd`, `tests/main_screen/test_turn_loop.gd`

**Scope:** M

### - [ ] Task 14: Main screen v0 (text only)

**Description:** A first real screen with:
- the action box, Act button and status line;
- a plain story text area (effects come in Task 15);
- the HUD as text (HP, gold, clock, place);
- the copy-paste dialog (Copy prompt from the click, paste box, Send/Cancel, Esc).

The world area is an empty panel for now.

**Acceptance criteria:**
- [ ] In the editor and in the web build: type an action, press Act, copy the prompt, paste a real Claude reply, and the narration shows; the HUD updates.
- [ ] Cancel changes nothing; Enter sends; Esc cancels.
- [ ] Every visible string comes from `ui_text.csv`.

**Verification:** manual in the editor, then web export + local run (build 1).

**Dependencies:** Task 13

**Files:** `src/main_screen/main.tscn`, `src/main_screen/main.gd`, `src/main_screen/paste_dialog.tscn`, `src/main_screen/paste_dialog.gd`, `content/data/ui_text.csv`

**Scope:** M

### Checkpoint 2
- [ ] A full text-only turn in copy-paste mode works in the local web build (build 1, logged in `docs/BUILDS.md`).
- [ ] S1 and S8 rerun 3 times each through the real game (copy-paste mode) with the fixed DM rules; results added to `examples/ai-tests/RESULTS.md`.
- [ ] All tests pass.
- [ ] Review with the lead before Phase 3.

---

## Phase 3: Story feel, own key, two languages

### - [ ] Task 15: Story panel

**Description:** Replace the plain story area with the story panel from `narration_panel.gd`:
- typewriter at about 45 characters per second;
- skip on click or key;
- `finished_typing` once per entry;
- plain lines for the player and dice;
- only the newest 4 entries animate;
- a reduce-motion flag;
- the view follows new text unless the player scrolled up.

**Acceptance criteria:**
- [ ] A new entry types out, and older text never re-types or flickers.
- [ ] Skipping and natural finish both emit `finished_typing` exactly once (test with simulated frames).
- [ ] The 5th newest entry and older use still colours; with reduce motion nothing moves.

**Verification:** tests command + manual in the editor.

**Dependencies:** Task 14

**Files:** `src/narration/story_panel.tscn`, `src/narration/story_panel.gd`, `src/main_screen/main.tscn`, `tests/narration/test_story_panel.gd`

**Scope:** M

### - [ ] Task 16: Burn, freeze and shock effects + stress test

**Description:** Add the freeze and shock effects next to burn, with the SPEC-narration still colours (effects not built yet show their still colour). Add a stress scene with 100 entries, 4 of them animating, and an fps counter.

**Acceptance criteria:**
- [ ] Each effect looks as the SPEC-narration table describes (manual).
- [ ] `poison`, `whisper` and `holy` words show in their still colours.
- [ ] Stress scene: 55+ fps on the lead's PC; the web build's fps is written in `docs/BUILDS.md`.

**Verification:** manual + fps readings.

**Dependencies:** Tasks 2, 15

**Files:** `src/narration/effects/burn_effect.gd`, `src/narration/effects/freeze_effect.gd`, `src/narration/effects/shock_effect.gd`, `tests/perf/story_stress.tscn`, `tests/perf/story_stress.gd`

**Scope:** M

### - [ ] Task 17: Own-key connection and settings

**Description:**
- **Own-key connection:** moved from `examples/`. Prints token usage (input, cache read, output) to the debug log, and shows the SPEC-dm status messages.
- **Settings store:** a settings file holding language, AI mode and API key.
- **Settings dialog:** a gear button; a masked key field with Clear and the "stored only on this device" note; AI mode choice.

**Acceptance criteria:**
- [ ] With the lead's key (typed at runtime): a real turn in the editor and in the web build.
- [ ] A wrong key shows "key refused" and changes nothing; no network shows an error and the game doesn't freeze.
- [ ] The key appears only in the settings file: not in the debug log, a save, or any file in the repo.

**Verification:** manual (the lead types the key); `git grep` finds no key.

**Dependencies:** Task 14. **Lead:** type the key.

**Files:** `src/dm/connections/own_key.gd`, `src/main_screen/settings_store.gd`, `src/main_screen/settings_dialog.tscn`, `src/main_screen/settings_dialog.gd`, `src/main_screen/main.gd`

**Scope:** M

### - [ ] Task 18: English and French

**Description:**
- **First launch:** a language picker that defaults to the system language, else English.
- **Language switch** in settings: relabels the whole UI at once, switches the keyword list, and changes the prompt's language line from the next turn.

**Acceptance criteria:**
- [ ] An automated test: every `ui_text` key used in the code exists in `ui_text.csv` with both columns filled.
- [ ] Switching language relabels every visible string with no restart; no raw key shows on screen.
- [ ] After switching, the next prompt says "Narrate in French." (or English), and French keywords animate.

**Verification:** tests command + manual.

**Dependencies:** Tasks 9, 17

**Files:** `src/main_screen/language_picker.tscn`, `src/main_screen/language_picker.gd`, `src/main_screen/settings_dialog.gd`, `content/data/ui_text.csv`, `tests/main_screen/test_ui_text_keys.gd`

**Scope:** M

### Checkpoint 3
- [ ] Animated story in both languages, both AI modes, in the local web build (build 2, logged).
- [ ] All tests pass.
- [ ] Review with the lead.

---

## Phase 4: World

### - [ ] Task 19: Walk grid

**Description:** Move `walk_grid.gd` into `src/world/` and test its path logic on a small grid built in the test (walkable flag, obstacles).

**Acceptance criteria:**
- [ ] The SPEC-world path cases pass: straight path; around a wall; no corner cutting.
- [ ] An unreachable goal gives the closest reachable cell.
- [ ] A start or goal outside the map gives no path and no crash.

**Verification:** tests command.

**Dependencies:** Task 1

**Files:** `src/world/walk_grid.gd`, `tests/world/test_walk_grid.gd`

**Scope:** S

### - [ ] Task 20: Placeholder art and the Mill Road zone

**Description:**
- **Placeholder art:** a free CC0 pack (Kenney) for tiles, the hero and a wolf, in `content/art/placeholder/` with its licence note.
- **Tileset:** a `walkable` flag on its tiles.
- **Zone:** the Mill Road (about 40×30 cells) with a road, the river, a bridge, the mill and a forest edge, on ground and obstacle layers.
- **Places:** 5 markers with ~3-cell areas, named by place id.

**Acceptance criteria:**
- [ ] The zone has the 5 markers and areas; the content check gives no "place without a marker" warning.
- [ ] Walkable and blocked cells match what the eye sees (manual: water and trees block, the bridge doesn't).
- [ ] The licence note is in the art folder.

**Verification:** manual in the editor; tests command.

**Dependencies:** Tasks 7, 19. **Lead:** approve the art pack download.

**Files:** `content/art/placeholder/` (images + `LICENSE.txt`), `src/world/zones/tileset.tres`, `src/world/zones/mill_road.tscn`

**Scope:** M

### - [ ] Task 21: Hero click-to-move

**Description:** Hero scene from `movement_click.gd`:
- click to walk along a path;
- walk animations in 8 directions, with the SPEC-world fallbacks (diagonal → left/right walk, left → mirrored right, idle → `idle_down`);
- the camera follows and stays inside the zone;
- a `locked` flag;
- `place_reached(place_id)` when the hero stops inside a place's area.

**Acceptance criteria:**
- [ ] Clicking walks the hero around obstacles facing the right way in all 8 directions (manual); the direction → animation choice, fallbacks included, has automated tests.
- [ ] The camera never shows outside the zone; while locked, clicks do nothing.
- [ ] Stopping in the `old_mill` area emits `place_reached("old_mill")` once.

**Verification:** tests command + manual in the editor.

**Dependencies:** Task 20

**Files:** `src/world/hero/hero.tscn`, `src/world/hero/hero.gd`, `src/world/world.tscn`, `src/world/world.gd`, `tests/world/test_hero_facing.gd`

**Scope:** M

### - [ ] Task 22: World in the main screen

**Description:** Put the world in the main screen at a 6:4 ratio next to the story. `place_reached` updates `state.location` through `Game` and the HUD place name. The world is locked during a turn.

**Acceptance criteria:**
- [ ] The layout matches SPEC-main-screen at 1280×720 and 1920×1080 with nothing cut off.
- [ ] Clicks on the story or the action box never move the hero.
- [ ] Walking to the mill changes the HUD place name; no AI turn is sent.

**Verification:** manual in the editor and the web build.

**Dependencies:** Tasks 18, 21

**Files:** `src/main_screen/main.tscn`, `src/main_screen/main.gd`, `src/autoload/game.gd`

**Scope:** M

### - [ ] Task 23: Scene director

**Description:** `run(commands)` from `scene_director.gd`:
- `move_to` (placed directly after 15 s);
- `spawn` (fade in on a walkable cell within 2 cells of the marker);
- `despawn` (most recent of that id);
- `weather` and `emote` skipped with a log line;
- `commands_finished`.

Also `sync_from_state` at game start, a generic creature scene that takes its sprite from content, and the hook into turn-loop step 8.

**Acceptance criteria:**
- [ ] `run([move_to old_mill, spawn rust_wolf near mill_bridge])` walks, then spawns, in order; `commands_finished` fires once.
- [ ] Spawn cells are always walkable and within 2 cells (automated, many seeds); a creature with no art shows the placeholder.
- [ ] A real AI turn that spawns a wolf works end to end in the editor.

**Verification:** tests command + manual.

**Dependencies:** Task 22

**Files:** `src/world/scene_director.gd`, `src/world/creatures/creature.tscn`, `src/world/creatures/creature.gd`, `src/main_screen/turn_loop.gd`, `tests/world/test_scene_director.gd`

**Scope:** M

### Checkpoint 4
- [ ] The whole M1 loop works in the local web build (build 3, logged): walk, act, animated story, the AI walks the hero and spawns a wolf.
- [ ] All tests pass.
- [ ] First team playtest, on the lead's computer; notes go to `docs/BUILDS.md`.

---

## Phase 5: Release and the gate

### - [ ] Task 24: Release pipeline

**Description:**
- **Pre-build script:** runs the tests and the content check, writes the build number and git hash into a build-info file, exports the web build, and scans `builds/web/` for secrets (`sk-ant`, `api_key` values).
- **Export preset:** includes `*.csv, *.md` and `src/diagnostics/`; excludes `tests/`.
- **Settings screen:** shows the version label; 5 clicks on it open the diagnostics scene.

**Acceptance criteria:**
- [ ] One command runs SPEC-release checklist steps 1–3 and fails on a planted fake key in the build folder.
- [ ] The exported build loads all content and contains no `tests/` files.
- [ ] The settings screen shows `M1 build <n> (<hash>)`, the hash exists on GitHub, and 5 clicks on the label open the diagnostics scene.

**Verification:** run the script (once clean, once with a planted fake key); inspect `builds/web/`.

**Dependencies:** Tasks 2, 23

**Files:** `tools/prebuild_check.py`, `export_presets.cfg`, `src/main_screen/build_info.gd`, `src/main_screen/settings_dialog.gd`, `docs/BUILDS.md`

**Scope:** M

### - [ ] Task 25: M1 playtest and measurements

**Description:** Run the full SPEC-release checklist on the final M1 build (played locally, no upload) and check all 9 SPEC.md M1 success criteria:
- on the lead's PC, and on a school laptop if the local build can run there (otherwise Chrome's 4× CPU slowdown stands in);
- in Chrome, Edge and Firefox;
- in both AI modes and both languages.

**Acceptance criteria:**
- [ ] Each of the 9 criteria is ticked or has a written reason in `docs/BUILDS.md`.
- [ ] Measured: fps (target 55 / 30), download size (target ≤ 25 MB), time to first screen with "Fast 4G" throttling (target ≤ 10 s).
- [ ] What still needs a hosted page (itch.io frame clipboard, school Wi-Fi start time, school network) is listed in `docs/BUILDS.md` for the first upload.

**Verification:** the `docs/BUILDS.md` entry.

**Dependencies:** Task 24. **Lead:** school laptop (or the stand-in).

**Files:** `docs/BUILDS.md`

**Scope:** S

### - [ ] Task 26: Engine and test-tool decision

**Description:** With the evidence in `docs/BUILDS.md` and the three conditions in SPEC.md, the lead decides: keep Godot or switch to Phaser. Record the decision, choose the test tool (Q-2: keep the runner or adopt an add-on, ask first), lock or update the SPEC.md tech stack, and record the result in `CLAUDE.md`.

**Acceptance criteria:**
- [ ] The decision and its reasons are in `docs/PLAN.md`.
- [ ] SPEC.md's tech stack table and "provisional" markers are updated.
- [ ] `CLAUDE.md` states the engine and test tool and no longer calls them proposed.

**Verification:** read the three files.

**Dependencies:** Task 25. **Lead:** the decision.

**Files:** `docs/PLAN.md`, `SPEC.md`, `CLAUDE.md`

**Scope:** S

### Checkpoint: M1 gate
- [ ] All M1 success criteria in SPEC.md are met or explained.
- [ ] The engine decision is recorded.
- [ ] Next: write the M2 module specs (`proxy`, plus the M2 parts of `core` and `main-screen`).
