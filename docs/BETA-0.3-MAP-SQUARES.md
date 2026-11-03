# Beta-0.3: map squares

*Branch `Beta-0.3-map-squares`, cut from `Beta-0.2` on November 3, 2026, built from the lead's decisions of November 2. `Beta-0.2` was not changed. Not merged anywhere.*

## What it is

The world is now a **grid of big square maps** ("squares"):
- The artist draws the world map as one PNG, `game/content/maps/world.png`, where **one pixel is one square** and the colour is its kind.
- Important places are **hand-made squares**: 64 × 64 PNGs, one pixel per tile.
- Every other square is **generated** the first time the hero enters it, then **stored in the save**.
- Walking onto the edge of a square asks the AI DM, which decides **travel** with a new checked command, `travel`.

The placeholder world is 48 × 48 squares. The hero starts in a hand-made square in the middle, which holds the Beta-0.2 Mill Road content.

## How the branch was built (one commit per step)

| Commit | Step |
|---|---|
| `c4c93dd` | 1. Spec first: new [SPEC-map.md](../SPEC-map.md) (module `map`); SPEC-world, SPEC-core, SPEC-dm, SPEC-content, SPEC-main-screen and the SPEC.md capability map updated; tasks 27–34 at the end of [tasks/todo.md](../tasks/todo.md) |
| `8741f36` | 2. Content: `kinds.csv`, `tiles.csv`, `squares.csv`, `world.png`, the start square, the extended tileset, the PNG loaders (`game/map/`), map checks in `tools/content_check.py` |
| `cf13f37` | 3. Square generator, with tests |
| `8407d4f` | 4. State v2 and its migration, `travel` in `apply_commands` and the reply checks, the MAP prompt part, `dm-rules.md` |
| `8a984e2` | 5. The world draws squares; the fade; exits send the automatic travel turn; HUD place label; loads |
| this commit | 6. This file, the French map guide [docs/GUIDE-CARTES.md](GUIDE-CARTES.md), more content-check tests, ticks in `tasks/todo.md` |

## Run it (lead's computer, Git Bash)

```bash
GODOT="/c/2026-2027/DND project/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
```

```bash
"$GODOT" --headless --path game --import
```

Run the import once after pulling: it imports the new map PNGs as Image.

```bash
"$GODOT" --headless --path game --script res://tests/run_tests.gd
```

Expect `PASS: 19 test file(s)`, and no `SCRIPT ERROR` line in the output.

```bash
python tools/content_check.py --check --langs fr,en
```

Expect `OK: content looks good (fr, en)`.

```bash
python tools/test_content_check.py
```

The content check's own tests. Expect `OK` (27 tests).

```bash
"$GODOT" --path game
```

This plays the game in a window.

To redraw the placeholder images from the tables, run `python tools/make_placeholder_maps.py --force`. **It overwrites** `world.png`, `mill-road.png` and `tiles-placeholder.png`. Without `--force` it only writes missing files, so it can't erase the artist's work by accident.

### Sample replies for copy-paste mode

Walk to the middle of the top edge of the start square. The paste window opens with "I head north (meadow)." Then paste one of these.

Travel:
```
You push through the hedge into the open meadow.
<<STATE>>
{"commands": [{"type": "travel", "to": "north"}], "state": {"time_advance_minutes": 20}}
```

No travel (the hero steps back one tile):
```
Brambles block the gap; you stay on the mill road.
<<STATE>>
{"commands": [], "state": {}}
```

Back to a visited square by id, then to a place there:
```
You walk back to the mill road.
<<STATE>>
{"commands": [{"type": "move_to", "target": "mill_road"}, {"type": "travel", "to": "sq_24_24"}], "state": {}}
```

## What changed

| Area | Beta-0.2 | Beta-0.3 | Spec |
|---|---|---|---|
| World | One hand-coded 24 × 22 zone | A grid of 64 × 64 squares from `world.png`, hand-made PNGs and generated squares | SPEC-map |
| Map files | — | `content/maps/`: `world.png`, `kinds.csv`, `tiles.csv`, `squares.csv`, `squares/*.png`; `locations.csv` gets `square, x, y` | SPEC-content |
| Tiles | 4 hard-coded tiles | 15 tiles from `tiles.csv` (colour, walkable, layer, tileset index); adding a tile needs no code | SPEC-content |
| Generated squares | — | Made from the seed, coordinates, kind and neighbours; stored in the save (tile ids + 64 rows); never use the dice | SPEC-map, SPEC-core |
| State | v1 | **v2**: `square`, `hero_cell`, `squares`, a `square` on each creature. The v1 → v2 migration plus `WorldState.settle` load Beta-0.2 saves (the hero on its place's marker) | SPEC-core |
| `location` | Always a place | A place, or `""` between places. Set when a walk ends (the place within 3 tiles of a marker) | SPEC-core |
| Commands | 6 | + `travel` (`to`: a direction or a visited square id), at most one, played first; `move_to`/`spawn near` checked against the destination's places; `near` may be `hero` | SPEC-dm |
| Prompt | 7 parts | 8: a **MAP** part between STATE and ALLOWED IDS. ALLOWED IDS lists `travel`. STATE lists only the current square's creatures. Fed through `Game.allowed_ids()`; `dm.gd` is untouched | SPEC-dm |
| DM rules | — | New "Map and travel" section in `dm-rules.md` | SPEC-dm |
| Exits | — | A walk ending on an exit sends the automatic turn ("I head north (forest)." + typed text). No travel or a cancel steps the hero back | SPEC-main-screen |
| Screen | Hero not locked during a turn; a cancelled action was lost | The hero is locked (and stopped) during a turn; a cancel gives the typed text back (both as SPEC-main-screen says) | SPEC-main-screen |
| Square change | — | A 0.25 s fade out, the new square, the hero on the arrival tile, a 0.25 s fade in | SPEC-world |
| Speed | ~2.8 tiles/s | 5 tiles/s, one setting: `WALK_CELLS_PER_SECOND` in `world/movement_click.gd` | SPEC-world |
| Oda | Always drawn | Only in the square that holds `old_mill` | SPEC-world |
| HUD | Place name | The place, or the square's kind ("Forest" / "Forêt") | SPEC-main-screen |
| Creatures | 6 in the world | 6 per square; they stay in their square when the hero leaves | SPEC-core |
| Content check | Tables and writing | + map files: unknown colours with pixel positions, image sizes, markers, hand-made squares off the map, exits facing squares the hero can't enter (warning) | SPEC-content |

### New files

- `game/map/` (module `map`, pure logic): `tile_table.gd`, `world_map.gd`, `map_loader.gd` (the only file reader), `square_grid.gd` (exits, arrival, step back, reachability), `square_generator.gd`.
- `game/core/world_state.gd`: the state side (travel, settle, stored tiles, the MAP view).
- `game/content/maps/`: the map files.
- `tools/pngio.py`: the standard-library PNG reader and writer. Also `tools/make_placeholder_maps.py` and `tools/test_content_check.py`.
- Tests:
  - `game/tests/unit/test_map_content.gd`;
  - `test_square_generator.gd`;
  - `test_world_state.gd`;
  - `test_travel_command.gd`;
  - `game/tests/integration/test_world_squares.gd`.

  They are added at the end of `TEST_PATHS`.

## The nine decisions: where they are built

| # | Decision | Where |
|---|---|---|
| 1 | Grid world, N/E/S/W neighbours | `WorldMap.neighbour`, `SquareGrid` |
| 2 | `world.png`, one pixel per square, `kinds.csv`; lake and mountain closed; outside never entered | `MapLoader.read_grid`, `WorldMap.can_enter` |
| 3 | Hand-made 64 × 64 PNGs, `squares.csv`, `tiles.csv`, magenta on the world map | `MapLoader`, `content/maps/` |
| 4 | Generated once, stored; deterministic; roads join | `SquareGenerator`, `WorldState.square_tiles` |
| 5 | 64 × 64 tiles of 32 px, camera inside, 5 tiles/s | `world.gd`, `movement_click.gd` |
| 6 | Exits; automatic turn; step back on no travel or cancel | `SquareGrid.exit_direction`, `main.gd` (`_on_walk_ended`, `_play_turn`) |
| 7 | `travel` command and its checks; arrival rules; creatures stay; global weather | `DmReplyParser`, `WorldState.travel`, `GameState.apply_commands` |
| 8 | `sq_<x>_<y>` ids; places as markers via `locations.csv` | `WorldMap.square_id`/`coords`, `locations.csv` |
| 9 | Start square with the Mill Road content near the middle | `squares/mill-road.png` at (24, 24) |

## Defaults I chose where the decisions were silent

Each is easy to change: tell me, or change the spec first.

| Question | Default in Beta-0.3 |
|---|---|
| An exit facing a square that can't be entered (only possible in hand-made squares) | No turn (the DM couldn't allow it anyway): "You can't go that way." and the hero steps back |
| How wide a generated opening is | 4 tiles (cells 30–33 of the edge); a road's path is 2 tiles wide (31–32) |
| Where the hero arrives after a direction | Literally on the border tile (decision 7). So clicking the hero while it stands there counts as walking onto that exit |
| `squares.csv` columns | `file, x, y, kind`. The `kind` column is my addition: it gives a hand-made square a name on screen and lets generated roads join it |
| The magenta kind | A reserved row `handmade,#ff00ff,true` in `kinds.csv` |
| Tile layers | `ground` or `obstacle`; obstacles always block, drawn over the most common ground around them |
| A place's area | Tiles within 3 steps of the marker (diagonals included); the closest marker wins |
| Creature limit | 6 per square |
| Travel time | The game adds none; the DM may add `time_advance_minutes` |
| Spawns in a reply that travels | They appear with the new square (fading in with it), not one by one |
| Seed | Still the fixed 12345, so every new game has the same generated squares |

## What was checked (in this cloud session, Linux)

- **Godot 4.7.2** (the official Linux x86_64 build from the `godotengine/godot` release `4.7.2-stable`, in a scratch folder, not committed):
  - `--headless --path game --import`;
  - then the test runner: **`PASS: 19 test file(s)`, 0 `SCRIPT ERROR` lines**. The only warnings and errors in the log are the expected ones from Beta-0.2's bad-input tests.
- **Content check:** `OK: content looks good (fr, en)`. **Its tests:** 27 tests OK.
- **The tests can fail.** I broke the code on purpose and the tests failed each time:
  - wider generated openings;
  - no trails in generated squares (dense forest exits disconnect);
  - travel not moved first;
  - a world-wide creature limit;
  - a marker moved onto water.
- **Generator:** 4 seeds × 5 kinds × 6 neighbour layouts (120 squares). The tests check:
  - the same inputs give the same tiles;
  - every open exit reaches every other;
  - closed edges are closed, and open edges are walkable exactly on 30–33;
  - corners are blocked;
  - road paths join their road and hand-made neighbours;
  - generation never touches the dice or Godot's global random numbers.

  I also looked at one rendered square of each kind.
- **End to end, real main scene** (a scratch script, not committed; `--fixed-fps 60`; headless, and again under Xvfb with Mesa llvmpipe for screenshots):
  - **Walk to the north exit.** About 8 s at 5 tiles/s. It started the turn by itself, and the paste window opened with "I head north (meadow). quietly" in the prompt.
  - **A pasted `travel north` reply** (plus a spawn near the hero):
    - the screen faded to black and back;
    - the hero stood on (31, 63) of `sq_24_23`, with the wolf next to it;
    - the HUD said "Meadow" and Oda was hidden.
  - **Walk onto the south exit** (the turn sent "I head south (road).") and paste a reply without travel: the hero stepped back to (31, 62).
  - **Walk onto the exit again and cancel:** the hero stepped back, and "slowly" came back into the action box.
  - **"Travel back by id"** with the `move_to` written first: the travel played first, then the walk to Mill Road; Oda was visible again.
- **Exported build stand-in:** no export templates were installed, so I exported a Linux **data pack** (`--export-pack`, a temporary preset in a scratch copy) and ran it with `--main-pack`, from a folder with no project.
  - The map PNGs loaded **without their source files**: 48 × 48, no problems, the 64 × 64 start square, the 3 places.
  - This worked with the Image import, and again with the PNG imported as a texture (the editor's default for a new PNG).
- **Saves:**
  - A Beta-0.2 (version 1) save loads: the hero is on its place's marker and the wolf is in the start square (unit test).
  - Save and load in a generated square restores the square, the tile and the stored tiles (unit and integration tests).

## What was NOT checked

- A turn with a **real AI model**.
- **S1 and S8 have not been rerun.** `dm-rules.md` changed, so the prompt cache prefix changed too, and the rules need a retest (AGENTS R12).
- The **Web build**: there are no export templates here, and the data pack above stands in for it.
- **Windows**, the lead's PC and the Godot editor UI (only headless import and runs).
- **Frame rate** with 64 × 64 squares (2 layers of 4096 tiles), in the editor or on a school laptop.
- How the fade and the faster walk **feel** to a person: I only saw screenshots and frame counts.
- macOS. The artist's and the writer's tools.

## The lead must try by hand

1. **Walk across several squares.**
   - From the start, walk to the top middle; paste the travel reply.
   - In the generated meadow, walk east or west, paste more travels, and come back.
   - Check the hero arrives on the matching edge, and the camera stays inside the square.
2. **The fade:** short, black, about half a second in all. The HUD place label switches to the kind.
3. **The paste window at an exit:**
   - **Cancel:** the hero steps back one tile, and the typed text comes back.
   - **A reply without travel:** the hero steps back.
   - **A reply with travel:** the fade, then the arrival.
4. **Save in a generated square and load it:** the same square, the same tile, the same look.
5. **Load a Beta-0.2 save:** copy `auto.json` or `manual.json` from the Beta-0.2 user folder (`%APPDATA%\Godot\app_userdata\Brasswake Reach\saves\`). The hero should stand on its place in the start square.
6. **Switch FR/EN:** the HUD label ("Prairie"/"Meadow") and the automatic action ("Je pars vers le nord (prairie).").
7. **With a real model** (copy-paste into a Claude chat): one exit turn, then the S1 and S8 reruns.
8. Optional: export the Web build once the templates are installed, and walk to an exit there.

## Open questions

1. Is the "can't go that way" default for exits facing a lake or a mountain right? Or should those turns still go to the DM?
2. Should the hero arrive **one tile inside** the square, rather than on the border tile? That would stop a click on the hero from sending the exit turn back.
3. Should travel add game time by itself, for example 30 minutes per square?
4. A random seed per new game, so each game gets new generated squares?
5. The visited-squares list in the prompt grows with every square entered. Cap it, for example to the hand-made squares plus the last 20?
6. The per-kind generation recipes are in code (`square_generator.gd`). Move them to `kinds.csv` columns if the artist wants to tune them? That is an "ask first" format change.
7. Two things are still fixed in code:
   - the tileset file name (`art/tiles-placeholder.png`);
   - where NPCs stand (Oda next to `old_mill`).

   A small table could hold both later.

## Who should hear about which files

**The artist** (via the lead):
- [docs/GUIDE-CARTES.md](GUIDE-CARTES.md): the French guide, covering the world map, a square, the colour tables, where to leave exits and the 64 × 64 size.
- `game/content/maps/world.png` and `squares/mill-road.png`: placeholders to replace.
- `kinds.csv`, `tiles.csv`, `squares.csv`: the colour tables and the list of hand-made squares.
- `game/content/art/tiles-placeholder.png`: now 15 tiles, 8 per row, numbered from 0; `tiles.csv` gives each tile's number.
- `art/CREDITS.md`.

**The writer** (via the lead):
- `game/content/i18n/strings.csv`: 12 new lines at the end, to review in French:
  - the kind names (Prairie, Forêt, Collines, Route, Marais, Lac, Montagne);
  - the automatic travel lines ("Je pars vers le nord ({kind})." and the 3 other directions). Keep `{kind}`;
  - "Impossible d'aller par là.".
- `game/content/data/locations.csv`: new `square, x, y` columns. **The place pages are unchanged.** A new named place needs a hand-made square, a marker in `locations.csv` and a place page.
- `game/content/writing/dm-rules.md`: the new "Map and travel" section. Generated squares are described only by their kind, with no invented named places.

## Notes for merging

- Files other sessions also touch:
  - `game/content/i18n/strings.csv`: lines added at the end only;
  - `game/ui/hud.gd`: the place label only;
  - `game/main.gd`: `_on_act` now calls `_play_turn`, and `_set_busy` locks the world. An own-key session may edit nearby.
- Not touched: `game/autoload/dm.gd`, `game/narration/**`, `SPEC-narration.md`, `game/tests/fixtures/**`, `test_archived_replies.gd`, `test_keyword_tagger.gd`, `docs/m1-ai-tests.md`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/BETA-0.2.md`, and the writer's place pages.
- To update when merging (the lead's files):
  - the test count: 14 → 19, plus `tools/test_content_check.py`;
  - the prompt is now 8 parts;
  - the new module `map` (`SPEC-map.md`, `game/map/`);
  - the new docs.
