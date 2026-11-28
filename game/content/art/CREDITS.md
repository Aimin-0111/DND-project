# Art credits

All files currently in `game/content/art/` and `game/content/maps/` are
**project-generated placeholder art** made for the M1 prototype and Beta-0.3.
They are released under **CC0-1.0** and may be replaced by the artist without
changing the game code.

| File | Purpose | Source |
|---|---|---|
| `tiles-placeholder.png` | 15 tiles of 32 × 32 px, 8 per row: grass, path, water, tree (the 4 Beta-0.2 tiles), then rock, floor, wall, bridge, sand, flowers, forest floor, dirt, mud, reeds, mill wheel (Beta-0.3). Index order is in `maps/tiles.csv` | Generated for Brasswake Reach (`tools/make_placeholder_maps.py`) |
| `hero-placeholder.png` | 6 × 4 frame hero sheet | Generated for Brasswake Reach |
| `creature-rust-wolf.png` | Rust wolf placeholder | Generated for Brasswake Reach |
| `npc-oda.png` | Oda placeholder | Generated for Brasswake Reach |
| `item-rusty-sword.png` | Item icon | Generated for Brasswake Reach |
| `item-healing-draught.png` | Item icon | Generated for Brasswake Reach |
| `../maps/world.png` | Placeholder world map, 48 × 48 squares (one pixel per square) | Generated for Brasswake Reach (`tools/make_placeholder_maps.py`) |
| `../maps/squares/mill-road.png` | Placeholder start square, 64 × 64 tiles (one pixel per tile): the Mill Road | Generated for Brasswake Reach (`tools/make_placeholder_maps.py`) |

**Beta-0.5 art** (November 27, 2026), painted from code by `tools/make_art.py` (Pillow, fixed seed), CC0-1.0 like the rest. The game now uses these, so `tiles-placeholder.png` and `hero-placeholder.png` are only kept for reference:

| File | Purpose |
|---|---|
| `tiles.png` | 29 tiles of 32 × 32 px, 8 cells per row, 1–4 variants each (the `variants` column of `maps/tiles.csv`): grass, path, water, trees and pines, rocks, floors, walls, roof, door, stairs, furniture, cliff, bushes, tall grass… |
| `edges.png` | Overlays for soft terrain edges: row 0 the grass fringe, row 1 the shore foam; N, E, S, W, then the NE, SE, SW, NW corners |
| `hero.png` | The hero sheet, same layout as before (4 frames × 6 rows) |
| `creature-rust-wolf.png`, `creature-brass-beetle.png` | 32 × 32 creatures |
| `creature-mill-golem.png` | The boss, 64 × 64 |
| `../maps/rooms/*.png` | The mill's rooms, drawn by `tools/make_rooms.py` |

When the real art arrives,
 add each file's author and license here. Never commit
art with an unclear license.
