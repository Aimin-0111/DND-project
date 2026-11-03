# Spec: `map` (the grid of squares)

*Module of [SPEC.md](SPEC.md). Depends on: `content` (file formats only). Used by: `core` (travel), `dm` (MAP part of the prompt, travel checks), `world` (drawing the current square), `main-screen` (exits). When: Beta-0.3 (decided by the lead on November 2, 2026; travel moved here from M3).*

## Objective

The world is a **grid of big square maps** ("squares"), side by side like a chessboard. This module owns the geography: which squares exist, what kind of land each one is, which ones the hero can enter, what tiles each square holds, where its exits are and where the hero arrives after travelling.

It is **pure logic**: no nodes, no screen, no AI. It reads the team's map files once (through `content` formats), generates the squares nobody drew, and answers questions. `core` stores what it generates; `world` only draws what the state says.

## The world map

- One PNG, `content/maps/world.png`, drawn by the artist. **One pixel is one square**; the pixel's colour is the square's **kind**. The world is exactly as big as the image (the artist decides; the lead asked for "very big").
- `content/maps/kinds.csv` maps colours to kinds (format in [SPEC-content.md](SPEC-content.md#maps-maps)).
- **Starter kinds:** `meadow`, `forest`, `hills`, `road`, `marsh` can be entered; `lake`, `mountain` can't. The reserved kind `handmade` (magenta, `#ff00ff`) marks the hand-made squares so they stand out on the map.
- **Ids:** every square is `sq_<x>_<y>`, from its pixel coordinates on `world.png` (column, row; never negative, no leading zeros), e.g. `sq_24_24`.
- **Neighbours:** north is `y - 1`, east `x + 1`, south `y + 1`, west `x - 1`.
- **Can the hero enter a square?** Only if it is on the image and either its kind can be entered, or it is a hand-made square whose PNG loaded correctly. Pixels outside the image, impassable kinds, a magenta pixel with no hand-made square listed there, and a hand-made square whose image is broken are **never entered**.

## Squares

- Every square is **64 × 64 tiles**. Tiles are 32 px, so a square is 2048 px across; the camera scrolls inside it.
- A tile has an id, a colour, a `walkable` flag, a layer (`ground` or `obstacle`) and a tileset index, all from `content/maps/tiles.csv`. Adding a tile needs no code. Obstacle tiles always block.
- **Corners are never exits.**
- **Exits:** a walkable tile on a square's border (not a corner) is an exit in that direction: row 0 → north, row 63 → south, column 0 → west, column 63 → east.

### Hand-made squares (the important places)

- Each one is a 64 × 64 PNG in `content/maps/squares/`, one pixel per tile, coloured with the `tiles.csv` colours.
- `content/maps/squares.csv` places each one on the world map by its `x`, `y` pixel (and gives the `kind` it counts as for its name and for its neighbours). The artist paints that pixel magenta on `world.png`.
- A hand-made square always comes from its PNG; it is **never stored in the save**, so the artist can improve it later and existing games pick up the new version.
- Exits are wherever the artist leaves walkable border tiles. Leaving them in the middle of an edge (rows/columns 30–33) lines them up with the generated squares around.

### Generated squares (everything else)

- Generated **the first time the hero enters**, then **stored in the save** so it never changes, even if the generator or the tile table changes later (team answer Q5).
- **Deterministic:** the result depends only on the save's `seed`, the square's coordinates, its kind and its neighbours' kinds. The same inputs give the same tiles; generation never uses the dice, so it doesn't change the dice sequence.
- **Edges:** the whole border is blocked (corners included), except the **middle of each edge that faces a square the hero can enter**: cells 30–33 of that edge are walkable. An edge facing a lake is water, one facing a mountain is rock, one facing the outside of the map is the kind's own border (trees, rocks or reeds).
- **Every open exit can be reached from every other one** (paths are carved from each opening to the centre).
- **Roads:** a `road` square gets a path that joins the openings facing its neighbouring `road` squares or hand-made squares. A road square with no such neighbour gets a short piece of path in the middle.
- The look of each kind (which ground tiles, how many trees, rocks, ponds, flowers…) is a small recipe in `map/square_generator.gd`. A kind the generator doesn't know yet (added by the artist) is generated like a meadow, and the content check warns about it.

## Places

- The named places (`mill_road`, `mill_bridge`, `old_mill`) are **markers inside a square**: `locations.csv` gives each one a `square` and the `x`, `y` of its tile (format in [SPEC-content.md](SPEC-content.md)). The writer's place pages don't change.
- A place's **area** is every tile within 3 tiles of its marker (in both directions, diagonals included). The hero "is at" the closest place whose area holds the hero's tile, otherwise at no place.
- Generated squares have **no named places**.

## Travel (the geography side)

The DM decides travel with the `travel` command ([SPEC-dm.md](SPEC-dm.md)); `core` applies it ([SPEC-core.md](SPEC-core.md)) with these rules:

| Step | Rule |
|---|---|
| Destination | A direction (`north`, `east`, `south`, `west`) means the neighbouring square, which must exist and be enterable. A square id must be a square the hero has visited, other than the current one |
| Leaving | The hero's tile in the square being left is remembered ("where the hero last stood") |
| Tiles | Hand-made: from its PNG. Generated: the stored tiles, or generated now and stored |
| Arrival after a direction | The walkable border tile on the side the hero comes in (corners excluded) closest to where the hero left, mirrored across the edge (leaving north from column 12 → the south edge near column 12). If that edge has no walkable tile: the closest walkable tile anywhere |
| Arrival after a square id | Where the hero last stood in that square; if that tile can't be walked on any more, the closest walkable tile |
| Place | The place whose area holds the arrival tile, or none |

- Creatures stay in their square when the hero leaves. Weather covers the whole world.
- **Stepping back:** when a turn sent from an exit doesn't travel, the hero moves to the walkable tile one step inside the square from the exit (or the closest walkable tile that isn't on the border).

## Interface

Names are provisional (GDScript style); the behaviour is the contract. Code lives in `game/map/`.

| Function | Does |
|---|---|
| `MapLoader.load_world(maps_dir, locations)` | Reads `world.png`, `kinds.csv`, `tiles.csv`, `squares.csv`, the hand-made PNGs and the place rows; returns a `WorldMap`. Problems are collected, never fatal |
| `WorldMap.square_id(x, y)`, `coords(id)` | `sq_x_y` ↔ coordinates; a malformed id gives `(-1, -1)` |
| `WorldMap.kind_of(id)`, `can_enter(id)`, `is_hand_made(id)`, `neighbour(id, direction)` | Questions about the grid |
| `WorldMap.places_in(id)`, `place_square(place)`, `place_cell(place)`, `place_at(id, cell)` | Markers and areas |
| `WorldMap.hand_made_tiles(id)` | The tiles of a hand-made square |
| `SquareGenerator.generate(seed, coords, kind, neighbours, tiles)` | 64 × 64 tiles, deterministic |
| `SquareGrid.exit_direction(cell)`, `arrival_cell(…)`, `step_back_cell(…)`, `reachable(…)` | Geometry on one square's walkable tiles |

`MapLoader` is the only part that reads files. Everything else works on loaded data, so tests can build small worlds in code.

## Acceptance criteria (Beta-0.3)

- [ ] The real map files load with no problems: the world size is the image size, every pixel has a kind, the start square holds `mill_road`, `mill_bridge` and `old_mill`.
- [ ] An unknown colour on `world.png` or in a square PNG is reported with its pixel position, and that square or tile can't be entered or walked on; the game still starts.
- [ ] `sq_<x>_<y>` ids round-trip; malformed ids (`sq_-1_2`, `sq_01_2`, `square_1_2`) are refused.
- [ ] Squares outside the image, `lake` and `mountain` squares and a magenta pixel without a hand-made square can't be entered.
- [ ] **Generator:** the same inputs give the same tiles; every open exit can be reached from every other one; closed edges have no walkable tile; open edges are walkable exactly on cells 30–33; corners are blocked; a road square's path reaches each edge facing a road or hand-made square. Checked over many seeds and every kind.
- [ ] Generation doesn't change the dice sequence.
- [ ] **Arrival:** leaving north from column 12 arrives on the south edge at the closest walkable column to 12; a closed entry edge arrives on the closest walkable tile; arriving by id uses the last tile stood on.
- [ ] Exit direction: border tiles give their direction, corners and inside tiles give none.

## Tests

- Automated (`tests/unit/`): loading the real map files and crafted images; ids; neighbours; generator properties over many seeds; arrival and step-back cases.
- Manual: walk through several generated squares and check they look like their kind.

## Boundaries (module)

- **Always:** stay deterministic; report file problems with the file and the pixel position; keep going with the rest.
- **Ask first:** changing the square size, the id format, the exit rules or a map file format (the artist draws against them).
- **Never:** read the dice, the clock or anything random that isn't derived from the seed and coordinates; touch nodes; write to `content/`.

## Open questions

- Recipes per kind live in code. If the artist wants to add kinds or tune their look, move them into `kinds.csv` columns (an "ask first" format change).
- The tileset file is fixed (`art/tiles-placeholder.png`, 32 px cells). When the artist's tileset arrives: rename it, or add a setting.
- New games use the fixed seed 12345, so every new game generates the same squares. Random seed per new game?
- The visited-squares list in the prompt grows with every square entered. Cap it (for example the hand-made squares plus the last 20) if prompts get long.
