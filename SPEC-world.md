# Spec: `world` (the animated scene)

*Module of [SPEC.md](SPEC.md). Depends on: `content` (art, place ids), `map` (the current square's tiles, places, exits), `dm` (the command list only). Used by: `main-screen`. When: M1 (one zone, walking, `move_to`, `spawn`, `despawn`), Beta-0.3 (squares, travel, the fade; lead's decisions of November 2, 2026, travel moved here from M3), M3 (NPCs that walk, weather particles, day/night, emotes).*

## Objective

The 60% of the screen where the story is *seen*: the **current square** of the world, top-down, where the hero walks, creatures appear when the DM brings them in, and the place names the AI uses exist as real spots on the map.

The world **shows** the state; it never decides it. It doesn't read AI text, and it doesn't change the state itself: it reports what happened through signals. Which squares exist, their tiles, exits and arrival tiles come from the `map` module ([SPEC-map.md](SPEC-map.md)).

## The current square (Beta-0.3)

- The world draws **one square at a time**: 64 × 64 tiles of 32 px (2048 px across), from the tiles the state points at (`state.square`): a hand-made square's PNG, or a generated square's stored tiles.
- Ground tiles go on the ground layer; obstacle tiles on the obstacle layer, over the most common ground tile around them.
- **Start:** one hand-made placeholder square near the middle of the world map holds the Mill Road content of Beta-0.2: the road, the Sombrecuivre river with its bridge, the old mill and Oda, and the markers `mill_road`, `mill_bridge` and `old_mill`. The hero starts at `mill_road`.
- Pixel art, top-down view (team answers Q9, Q11). Placeholder tiles until the artist's tiles arrive (Q14). Tile size 32 px (Q10 still open): it is one setting.
- **Named places** are markers from `locations.csv` (square + tile); the world creates the markers of the current square only. Each has an area of 3 tiles around it ([SPEC-map.md](SPEC-map.md#places)).
- **Oda** appears only in the square that holds `old_mill`, next to its marker.
- **Walkable tiles** come from `tiles.csv`: a ground tile walks if its `walkable` flag says so; anything on the obstacle layer blocks; a tile with an unknown colour blocks.

## Behaviour

| Feature | Rule |
|---|---|
| Click to move | Clicking a tile walks the hero there along a path around obstacles, inside the current square. Diagonal steps never cut a blocked corner |
| Unreachable target | The hero walks to the closest reachable tile |
| Speed | About **5 tiles per second**: one setting (`WALK_CELLS_PER_SECOND` in `world/movement_click.gd`) |
| Animation | `walk_*` in **8 directions** and `idle_down` at least (names from `GUIDE-ARTISTE.md`); the sprite faces the way it moves. Left-facing walks may be mirrors of the right-facing ones. A missing animation falls back: a diagonal to the left/right walk, any idle to `idle_down` (placeholder art usually has 4 directions) |
| Camera | Follows the hero and stays inside the square's edges (0 to 2048 px) |
| Lock | While the AI answers and while commands play, clicks don't move the hero (`main-screen` sets the lock) |
| Walk ends | When the hero stops after a walk, the world emits `walk_ended(cell)`. `main-screen` stores the tile (and so the place, [SPEC-map.md](SPEC-map.md#places)) through `core`, and checks for an exit. No AI turn is sent unless the tile is an exit |
| Exits | A walk that **ends** on a walkable border tile (not a corner) has reached an exit. Walking across one without stopping does nothing. `main-screen` decides what happens ([SPEC-main-screen.md](SPEC-main-screen.md#exits-the-automatic-travel-turn)) |
| Square change | A short fade: about 0.25 s to black, the new square is drawn and the hero placed on its arrival tile, about 0.25 s back |
| Missing art | A placeholder sprite and a warning; never a crash |

## Contract: playing commands

`run(commands)` plays the **checked** commands in order, waiting for each one to finish. It runs after the narration has finished typing and after `core` applied the turn.

| Command | On screen | When |
|---|---|---|
| `travel` | Plays first. Fade out, draw the destination square (`square` and arrival `cell` were filled in by `core`), place the hero, show that square's creatures from the state, fade in. Spawns and despawns of the same reply are already in the state, so they aren't played again after a travel | Beta-0.3 |
| `move_to` | The hero walks to the place's marker in the current square. (M1 spec: after 15 s it is placed there directly; not built yet) | M1 |
| `spawn` | The creature fades in (about 0.6 s) near the place's marker, or near the hero when `near` is `hero` | M1 (`hero`: Beta-0.3) |
| `despawn` | The most recently spawned creature with that id in the current square fades out | M1 |
| `weather` | Tint now (particles in M3): rain, fog, storm, snow, ash; `clear` stops them. Weather covers the whole world | M1 tint, M3 particles |
| `emote` | A note line now; a small bubble (`!`, `?`, `zzz`…) above `who` in M3 | M3 |
| `request_roll` | Nothing in the world (the roll line is shown by `main-screen`) | — |

- A command the world can't play yet is skipped with a log line. **The state still changes**: `core` already applied it, so the world can catch up later.
- `show_state(state)` draws `state.square`, places the hero on `state.hero_cell`, rebuilds the creatures of that square and the weather, with no animation. It is used at game start and for loads (later Rewind).
- Signals: `walk_ended(cell)`, plus the scene director's notes, `moved_to(place)` and `roll_requested(skill, dc)`.

## Acceptance criteria

**M1**
- [ ] Path logic (testable without a screen, on a small test grid): straight path; path around a wall; no corner cutting; unreachable goal → closest reachable cell; start or goal outside the map → no path, no crash.
- [ ] The zone has a marker for each of the 5 place ids; the content check warns when a place id has none.
- [ ] Clicking walks the hero with the right animation in all 8 directions (diagonals use the left/right fallback while the art has none); the camera follows and stops at the edges (manual).
- [ ] Choosing the animation from a move direction, including the fallbacks, has automated tests.
- [ ] Clicks on the story panel or the action box never move the hero (manual).
- [ ] `run([{move_to old_mill}, {spawn rust_wolf near mill_bridge}])` walks the hero, then fades a wolf in near the bridge, in that order; `commands_finished` fires once.
- [ ] Stopping inside the `old_mill` area sets the place to `old_mill` once. (Beta-0.3: `place_reached(place_id)` became `walk_ended(cell)`; the place comes from the map's place areas.)
- [ ] A creature with no art appears as a placeholder.
- [ ] With the hero walking, 6 creatures present and text effects running, the game holds 55+ fps on the lead's PC and 30+ fps in the web build on a school laptop.

**Beta-0.3**
- [ ] The start square is drawn 64 × 64 from its PNG; the camera limits are 0 to 2048 px; a path exists from `mill_road` to `mill_bridge` and to `old_mill`.
- [ ] Drawing a generated square uses its stored tiles; walkable and blocked tiles on screen match `tiles.csv`.
- [ ] Oda is visible only in the square that holds `old_mill`.
- [ ] `show_state` after a load puts the hero back in the saved square, on the saved tile, with that square's creatures only.
- [ ] Walking across several squares, the fade, and the hero arriving on the right edge (manual).
- [ ] The hero walks at about 5 tiles per second (manual).

**M3**
- [ ] NPCs that walk; day/night tint from `time_minutes`; weather particles; emotes.

## Tests

- Automated: the path-logic cases above, the direction → animation choice, drawing a square in the real scene (size, markers, Oda, camera limits), `show_state` after a load.
- Manual (before each build): walking, the camera, the fade between squares, command playback, placeholders.

## Boundaries (module)

- **Always:** take place ids from `content`, squares and tiles from `map`, and art from `content`.
- **Ask first:** changing how places are marked on the map (the writer's place pages and the AI both rely on the ids).
- **Never:** read AI narration, change the state directly, or play a command that didn't come through `dm`'s checks.

## Open questions

- Q-1 (Q10): tile size, 16 or 32 px. Answered on October 19: top-down pixel art, 8 directions; the movement style was left to the lead, so click-to-move stays.
- Should the player be able to fast-forward command playback (click to skip)?
- NPC placement is still in code (Oda next to `old_mill`). A table of NPCs and their places would let the writer move them.
