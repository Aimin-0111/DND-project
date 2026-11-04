# Beta-0.4 plan: layout v2, backpack, minimap, bars

*Written on November 4, 2026 by Claude for the lead. The lead asked for:*
- *the bars at the bottom;*
- *a Backpack button on top;*
- *the story on the left and the scene on the right;*
- *a clickable map;*
- *a settings menu at the top left holding save, load, language, Codex and AI.*

*The lead then said "just do what you think is logical", so the other choices below are Claude's, and the lead can overturn any of them. The M1 plan in `tasks/plan.md` and `tasks/todo.md` is unchanged.*

## Decisions taken for the lead

| Question | Decision | Written in |
|---|---|---|
| Layout | Story on the left (≈40%), world on the right (≈60%), top bar, bottom bar | [SPEC-main-screen.md](../SPEC-main-screen.md#layout-v2-beta-04) |
| Menu (top left) | Save, Load, Language, Codex, AI settings, Close. Sound and text speed in M2 | same |
| Second bar | **Steam** (magic), blue, under the light steampunk theme; plus an XP bar with the level | [SPEC-core.md](../SPEC-core.md#state-version-3-beta-04) |
| Items | Used from the backpack or the hotbar, at once, by game rules (no DM turn). The DM learns about it from `events` in the next prompt. In fights (M3) a use will cost the hero's turn | same |
| Equipment | 6 slots: head, body, weapon, off-hand, feet, trinket. Equipped items leave the pack | same |
| Hotbar | Keys 1–4, usable items only | [SPEC-main-screen.md](../SPEC-main-screen.md#bottom-bar) |
| Minimap | 7 × 7 squares, flat colours, fog; click or M opens the whole world map | [SPEC-main-screen.md](../SPEC-main-screen.md#minimap-and-world-map) |
| Extras kept | Suggested actions (chips), tracked quest, change pop-ups, Codex window | SPEC-main-screen, [SPEC-dm.md](../SPEC-dm.md#contract-the-reply-format) |
| Extras left for later | Journal (M2), speaker portrait (with the Journal), status effects (M3), dice animation (Beta-0.5, the zone is reserved now) | SPEC-main-screen |
| `<<STATE>>` questions | Spaces or tabs around the marker are allowed; with several marker lines the **last** one is used | [SPEC-dm.md](../SPEC-dm.md#contract-the-reply-format) |
| View | Top-down 3/4 like Stardew Valley, not isometric; the tile size stays 32 px | [SPEC.md](../SPEC.md#art-direction-beta-04) |
| Building | Written down as the later module `build` (after M3) | [SPEC.md](../SPEC.md#later-building-and-crafting) |
| Numbers | `levels.csv`: 300 XP to level 2, HP 12 → 20, Steam 6 → 9. Two new items: Leather Jerkin (armor +1), Brass Tonic (Steam +1d4+1). At most 300 XP per DM turn | SPEC-core, [SPEC-content.md](../SPEC-content.md) |

## How the work runs

- **Cloud sessions, one at a time**, each cut from `origin/Beta-0.4` and pushing its own branch `Beta-0.4-<task>`. Running them one at a time avoids merge conflicts: T1, T3 and T4 all change `main.gd` and the main scene.
- **Between tasks, the lead's local session:**
  1. fetches the branch;
  2. runs the import, the tests and the content check on Windows;
  3. merges it into `Beta-0.4` and pushes `Beta-0.4`;
  4. asks the lead for the credit left;
  5. starts the next task.
- `main` changes only when the lead says so.
- **First, `Beta-0.3-web-bugs`** (the B1–B8 fixes, already running when this plan was written) is merged into `Beta-0.4` before T1 starts, because it changes the same files.

## Budget

The lead had **$31 of cloud credit** when this plan was written. The costs per task below are guesses; they get corrected once the web-bugs session's real cost is known.

| Order | Task | Guess | Must or optional |
|---|---|---|---|
| 0 | `web-bugs` (running) | ~$6 | Must (B1 breaks copy-paste on the web) |
| 1 | T1 `ui-layout` | ~$7 | Must |
| 2 | T2 `pack-rules` | ~$6 | Must |
| 3 | T3 `pack-ui` | ~$6 | Must |
| 4 | T4 `dm-extras` | ~$5 | Optional |
| | **Total** | **~$30** | |

**Stop rule:**
- Start a task only if the credit left is at least its guess plus $2.
- Otherwise, the lead's local session does that task on the Pro plan, smaller if needed: T4 first loses the pop-ups, then the chips.

## What every brief repeats (to save credit)

- **Setup:**
  ```bash
  git fetch origin Beta-0.4 && git switch -c Beta-0.4-<task> origin/Beta-0.4
  ```
- **Godot:** install only the Linux editor; no export templates and no browser.
  ```bash
  cd /tmp && curl -fsSLO https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip && unzip -q Godot_v4.7.2-stable_linux.x86_64.zip -d /opt/godot
  GODOT=/opt/godot/Godot_v4.7.2-stable_linux.x86_64
  ```
- **Checks:**
  ```bash
  "$GODOT" --headless --path game --import
  "$GODOT" --headless --path game --script res://tests/run_tests.gd
  python3 tools/content_check.py --check --langs fr,en
  python3 tools/test_content_check.py
  ```
  The tests must print PASS with **0 `SCRIPT ERROR` lines**. The `Parse JSON failed` and `invalid slot '../evil'` lines are expected.
- **What to read:** the spec sections named in the task first, then only the files listed. No tour of the whole repo.
- **Saving the work:** the steps are in order of value. After each step that passes, commit and `git push -u origin Beta-0.4-<task>`, so nothing is lost if the credit runs out.
- **Rules:**
  - a test is written before the code, and each new test file is added to `game/tests/run_tests.gd`;
  - every UI string goes in `game/content/i18n/strings.csv` in English and simple, correct French;
  - a state shape change needs a migration;
  - copy-paste mode keeps working;
  - never commit a key (the repo is public).
- **The report:** `docs/BETA-0.4-<task>.md`, at most 60 lines: what changed, the test result, what the lead must check by hand. Don't edit `README.md`, `AGENTS.md` or `tasks/`. Don't merge and don't open a PR.

## T1 `ui-layout`: layout v2, menu, minimap

**What:** the screen of [SPEC-main-screen.md § Layout v2](../SPEC-main-screen.md#layout-v2-beta-04), without the backpack contents, the Steam and XP bars and the hotbar (T3) or the chips and pop-ups (T4).

**Steps, in order:**
1. **Layout v2:**
   - story on the left, world on the right;
   - the top bar with the Menu button (Save, Load, Language, AI settings, Close; the AI mode shown on top), the place · clock · weather, and a Backpack button that opens an empty `backpack_window` with only its title and close button (B key too);
   - the bottom bar with the HP bar and gold;
   - the reserved `DiceZone`;
   - the gear button next to the action box removed.
2. **The minimap** (7 × 7, kind colours, fog, red frame) and the **world map window** (click or M; `maps/world-painted.png` under the fog if the file exists).
3. **The Codex window** in the menu, and the **tracked quest** label.

**Acceptance:** the Beta-0.4 criteria of SPEC-main-screen about the layout, the menu, the minimap, the world map, the keys B and M while the action box has focus, the tracked quest and the dice zone. Plus everything that passed before: the turn loop, the exits, the paste dialog and own key.

**Files likely touched:**
- `game/main.tscn` and `game/main.gd`;
- `game/ui/hud.*` (split into a top bar and a bottom bar);
- new `game/ui/menu.*`, `codex_window.*`, `minimap.*`, `world_map_window.*`, `backpack_window.*`;
- `strings.csv`;
- `game/tests/integration/` (a new `test_layout_v2.gd`, and fixes to `test_ui_actions.gd` and `test_status_line.gd` if node paths move).

## T2 `pack-rules`: state v3, items, XP (headless)

**What:** [SPEC-core.md § State version 3](../SPEC-core.md#state-version-3-beta-04), with the content and DM parts that go with it. No UI.

**Steps, in order:**
1. `items.csv` gets the new columns and the two new items. Add `levels.csv`. Add names and descriptions to `strings.csv`. Add the checks in `tools/content_check.py`, with Python tests, and in the Godot loader.
2. State v3 in `new_game`, the v2 → v3 migration, and the fixture `tests/fixtures/saves/v2.json`.
3. In `apply_changes`: `xp_gain`, `steam_delta` and level-up.
4. `use_item`, `equip`, `unequip`, `set_hotbar`, `armor_class`, `attack_bonus`, and `events` (cleared by `apply_commands`).
5. **DM side:**
   - the prompt state view and part 7 events;
   - the parser keeps `xp_gain` and `steam_delta` with their ranges;
   - the three new rule lines in `dm-rules.md` (note them for the writer).

**Acceptance:** the Beta-0.4 criteria of SPEC-core, the `xp_gain`, `steam_delta` and prompt criteria of SPEC-dm, and the SPEC-content checks. The archived Haiku replies give the same results.

**Files likely touched:**
- `game/core/game_state.gd` and `save_system.gd`;
- `game/content/content_loader.gd`, `data/items.csv`, new `data/levels.csv`;
- `game/ai/` (the prompt builder and `dm_reply_parser.gd`);
- `game/content/writing/dm-rules.md`;
- `tools/content_check.py` and `tools/test_content_check.py`;
- `game/tests/unit/`.

## T3 `pack-ui`: backpack window, bars, hotbar

**What:** [SPEC-main-screen.md § Bottom bar, § Backpack window, § Keys](../SPEC-main-screen.md#backpack-window), on top of T1 and T2.

**Steps, in order:**
1. The Steam and XP bars and the level in the bottom bar.
2. **The backpack window:**
   - the 6 equipment slots, the pack grid and the item details;
   - Use, Equip and Unequip through `core`, refused during a turn;
   - the stats line, the story line on use, and an autosave.
3. **The hotbar:** 4 slots, keys 1–4 (not while a text field has focus), and the Hotbar 1–4 buttons in the details.

**Acceptance:** the Beta-0.4 criteria of SPEC-main-screen about the backpack, the hotbar, the bars and the keys.

**Files likely touched:** `game/ui/backpack_window.*`, the bottom bar, `game/ui/hotbar.*`, `game/main.gd`, `strings.csv`, and a new `game/tests/integration/test_backpack.gd`.

## T4 `dm-extras` (optional): marker rules, suggestions, pop-ups

**Steps, in order:**
1. **The marker rules** in `dm_reply_parser.gd`:
   - spaces or tabs are allowed around the marker;
   - the last marker line wins, and the earlier ones are taken out of the narration;
   - update the fixtures' expected results and the "Questions for the lead" in `docs/m1-ai-tests.md`.
2. **Suggestions:**
   - the `suggestions` key in the parser and `TurnResult`;
   - one rule line in `dm-rules.md`;
   - the chips above the status line (cleared at step 2, shown at step 10, a click fills the action box).
3. **The change pop-ups** above the bottom bar.

**Acceptance:** the Beta-0.4 criteria of SPEC-dm about suggestions and the marker, and those of SPEC-main-screen about the chips and the pop-ups.

## After the last task (the lead's local session)

- Merge, then run every check on Windows.
- Write `docs/BETA-0.4.md` and update the README and AGENTS.
- List the manual checks for the lead: the layout at 3 window sizes, a real copy-paste turn, the backpack, the minimap.
- List what to tell the writer (new strings and `dm-rules.md` lines) and the artist (icons for the two new items, an optional `world-painted.png`).
- Then ask the lead before merging `Beta-0.4` into `main`.
