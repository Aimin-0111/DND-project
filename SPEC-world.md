# Spec: `world` (the animated scene)

*Module of [SPEC.md](SPEC.md). Depends on: `content` (art, place ids), `dm` (the command list only). Used by: `main-screen`. When: M1 (one zone, walking, `move_to`, `spawn`, `despawn`), M3 (travel, NPCs, weather, day/night, emotes).*

## Objective

The 60% of the screen where the story is *seen*: a small top-down map where the hero walks, creatures appear when the DM brings them in, and the place names the AI uses exist as real spots on the map.

The world **shows** the state; it never decides it. It doesn't read AI text, and it doesn't change the state itself: it reports what happened through signals.

## M1 zone: the Mill Road

- About 40 × 30 cells: a road, the Sombrecuivre river with a bridge, the old mill, a forest edge.
- Pixel art, top-down view (team answers Q9, Q11). Free placeholder art (Kenney, CC0) until the artist's tiles arrive (Q14). Tile size (16 or 32 px) is still open (Q10): it is one setting.
- **Named places** match the place ids in `content`: `mill_road`, `old_mill`, `mill_bridge`, `mill_bridge_east`, `copper_river`. Each has:
  - a **marker**: the point the hero walks to and creatures appear near;
  - an **area** of about 3 cells around it, used to know where the hero is.
- **Walkable cells** come from the tiles: the artist's tileset marks walkable tiles; anything on the obstacle layer (trees, walls, water) blocks.

## Behaviour

| Feature | Rule |
|---|---|
| Click to move | Clicking a cell walks the hero there along a path around obstacles. Diagonal steps never cut a blocked corner |
| Unreachable target | The hero walks to the closest reachable cell |
| Speed | About 3 cells per second (adjustable) |
| Animation | `walk_*` in **8 directions** and `idle_down` at least (names from `GUIDE-ARTISTE.md`); the sprite faces the way it moves. Left-facing walks may be mirrors of the right-facing ones. A missing animation falls back: a diagonal to the left/right walk, any idle to `idle_down` (placeholder art usually has 4 directions) |
| Camera | Follows the hero and stays inside the zone edges |
| Lock | While the AI answers and while commands play, clicks don't move the hero (`main-screen` sets the lock) |
| Where the hero is | When the hero stops inside a place's area, the world emits `place_reached(place_id)`. `main-screen` updates `state.location` through `core`. No AI turn is sent |
| Missing art | A placeholder sprite and a warning; never a crash |

## Contract: playing commands

`run(commands)` plays the **checked** commands in order, waiting for each one to finish. It runs after the narration has finished typing.

| Command | On screen | When |
|---|---|---|
| `move_to` | The hero walks to the place's marker. After 15 s it is placed there directly | M1 |
| `spawn` | The creature fades in (about 0.6 s) on a walkable cell within 2 cells of the place's marker | M1 |
| `despawn` | The most recently spawned creature with that id fades out | M1 |
| `weather` | Particles and tint (rain, fog, storm, snow, ash; `clear` stops them) | M3 |
| `emote` | A small bubble (`!`, `?`, `zzz`…) above `who` | M3 |
| `request_roll` | Nothing in the world | — |

- A command the world can't play yet (M1: `weather`, `emote`) is skipped with a log line. **The state still changes**: `core` already applied it, so the world can catch up later.
- `sync_from_state(state)` places the hero at `state.location` and rebuilds `state.creatures` with no animation. It is used at game start and later for loads and Rewind.
- Signals: `place_reached(place_id)`, `commands_finished`.

## Acceptance criteria

**M1**
- [ ] Path logic (testable without a screen, on a small test grid): straight path; path around a wall; no corner cutting; unreachable goal → closest reachable cell; start or goal outside the map → no path, no crash.
- [ ] The zone has a marker for each of the 5 place ids; the content check warns when a place id has none.
- [ ] Clicking walks the hero with the right animation in all 8 directions (diagonals use the left/right fallback while the art has none); the camera follows and stops at the edges (manual).
- [ ] Choosing the animation from a move direction, including the fallbacks, has automated tests.
- [ ] Clicks on the story panel or the action box never move the hero (manual).
- [ ] `run([{move_to old_mill}, {spawn rust_wolf near mill_bridge}])` walks the hero, then fades a wolf in near the bridge, in that order; `commands_finished` fires once.
- [ ] Stopping inside the `old_mill` area emits `place_reached("old_mill")` once.
- [ ] A creature with no art appears as a placeholder.
- [ ] With the hero walking, 6 creatures present and text effects running, the game holds 55+ fps on the lead's PC and 30+ fps in the web build on a school laptop.

**M3**
- [ ] Several zones and travel between them; NPCs that walk; day/night tint from `time_minutes`; weather; emotes.
- [ ] Important places are made by hand; other areas and details are generated once and stored in the save, so they look the same after a reload (team answer Q5; details specified in M3).

## Tests

- Automated: the path-logic cases above, and the direction → animation choice.
- Manual (before each build): walking, the camera, command playback, placeholders.

## Boundaries (module)

- **Always:** take place ids from `content` and art from `content.art_path()`.
- **Ask first:** changing how places are marked on the map (the writer's place pages and the AI both rely on the ids).
- **Never:** read AI narration, change the state directly, or play a command that didn't come through `dm`'s checks.

## Open questions

- Q-1 (Q10): tile size, 16 or 32 px. Answered on October 19: top-down pixel art, 8 directions; the movement style was left to the lead, so click-to-move stays.
- Should the player be able to fast-forward command playback (click to skip)?
- Can the player walk freely in another zone before M3's travel exists, or is M1 one zone only? (Assumed: one zone.)
