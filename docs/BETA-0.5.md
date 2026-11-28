# Beta-0.5: boxes, WASD, fights, new art

*November 27, 2026, by Claude, in the lead's local session. Branch `Beta-0.5`, cut from `Beta-0.4` (`cb4b184`, with T1 ui-layout). Not committed yet. The lead asked for four things: indoor and outdoor "boxes" of different sizes, WASD with a controls setting, normal and boss fights, and better textures (the reference was a lush top-down pixel-art map).*

## What changed
- **Art** (`tools/make_art.py`, painted from code, CC0):
  - a new 32 px tileset, `art/tiles.png`, with 29 tiles and up to 4 variants each, so fields don't repeat;
  - shaded round trees and pines, rocks, water with ripples, wood floors, stone walls, a roof, a door, stairs and furniture;
  - soft edges (`art/edges.png`): grass spills over paths and foam lines the shores;
  - a new hero sheet, a rust wolf, a brass beetle and the 64 px mill golem boss;
  - the creatures bob as if breathing.
- **Boxes** ([SPEC-map.md](../SPEC-map.md#rooms-and-doors-beta-05)):
  - rooms of any size, indoor or outdoor (`maps/rooms.csv` + PNGs);
  - doors between any two boxes (`maps/doors.csv`), walked through at once with a fade;
  - creatures placed in a box (`maps/creatures.csv`);
  - small rooms are centred, and the minimap shows the square outside.
  - The state shape is unchanged, so old saves load.
- **The mill** now has a roof and a front door (54, 27). Behind it: the hall (18 × 12, beetle), the yard (24 × 16, outdoor, wolf) and the cellar (14 × 10, the boss). They were drawn by `tools/make_rooms.py`.
- **Controls** ([SPEC-main-screen.md](../SPEC-main-screen.md#controls-beta-05)):
  - Menu → Controls: W A S D, Z Q S D (AZERTY) or arrows only, and click to move on or off;
  - the setting is saved on the device;
  - the arrow keys always work, and a click on the world leaves the text box.
- **Fights** ([SPEC-fight.md](../SPEC-fight.md)):
  - touching a creature opens the fight window;
  - actions: Attack, Guard, Potion, Flee (keys 1–4), with a dice readout and hit shakes;
  - a boss can't be fled from; it warns before its steam blast, and rages at half HP;
  - winning gives gold; losing wakes the hero on the Mill Road with half HP;
  - the DM hears the result through the story so far.
- **Data:**
  - `monsters.csv`: `gold`, `boss`, `special`, `special_damage`, `special_every`, plus the beetle and the golem;
  - `items.csv`: `damage`, `heal`;
  - `tiles.csv`: `variants` and 14 new tiles;
  - 48 new strings, in English and French.
- **DM rules:** two new lines, about rooms and about fights being the game's job. The writer should read them.
- **Tests:**
  - the runner now awaits tests;
  - new: `test_fight`, `test_rooms`, `test_controls`, and `test_beta05_screen` (the real main scene: art, Controls, keys, the mill door, a whole fight).

## Results (Windows, Godot 4.7.2)
- `run_tests.gd`: **PASS: 32 test file(s)**, 0 `SCRIPT ERROR`.
- `content_check.py`: OK. `test_content_check.py`: OK (27).
- Screenshots taken from a scripted run: Mill Road, the hall, the yard, the cellar and a boss fight.
- Balance, simulated over 500 seeded fights with a level 1 hero:
  - beetle: about 100%;
  - wolf: about 68% (the lead's M1 numbers, unchanged);
  - golem: about 57%.

## Choices Claude made (the lead can overturn them)
- Doors are a game rule (no DM turn). Rooms are never travel targets.
- A fight is one creature at a time, in a window. Losing isn't a game over.
- The golem's numbers were tuned down so a level 1 hero can win.
- There is no XP from fights yet: that waits for T2's levels.

## Check by hand
1. Walk with W A S D and with the arrows. Then choose Z Q S D in Menu → Controls, and turn click to move off and on again.
2. Type in the action box: the letters don't move the hero. Click the world, and the keys move him again.
3. Go through the mill door: inside, then the yard, then the cellar, and back out.
4. Fight the beetle, the wolf (try Flee) and the golem (Guard when it warns). Lose once on purpose.
5. Save inside a room, reload the page, and check that the game resumes there.
6. Check the web build. It hasn't been tested in a browser.

## Still open
- T2–T4 of `tasks/beta-0.4.md` were planned on `Beta-0.4`. They overlap with this branch: `items.csv`, `monsters.csv`, `main.gd` and the bottom bar.
- The Godot editor's own changes to `project.godot` and to the `.import` line endings are mixed into this branch.
