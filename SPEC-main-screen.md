# Spec: `main-screen` (layout and the turn loop)

*Module of [SPEC.md](SPEC.md). Depends on: `core`, `content`, `narration`, `dm`, `map`, `world`. Used by: `release`. When: M1 (layout, turn loop, minimal settings), Beta-0.3 (exits send the automatic travel turn; the web-check fixes of November 4, 2026: paste window, cancel, load and resume), M2 (tabs, Rewind, more settings).*

## Objective

Put the pieces on one screen and run the **turn loop** that connects them: the player types an action, the AI answers, the story types out, the world plays the commands. This module owns the order of those steps and what's locked while they run. It holds no rules itself.

## Layout (option A: side by side)

```
┌──────────────────────────────┬────────────────────┐
│ HP 12/12 · 10 gold           │ Story              │
│ Day 1, 08:00 · Mill Road     │ (narration)        │
│                              │                    │
│        WORLD (≈60%)          │   STORY (≈40%)     │
│                              │                    │
│                              ├────────────────────┤
│                              │ status line        │
│                              │ [What do you do? ] │
│                              │ [Act]   ⚙   AI: ✂  │
└──────────────────────────────┴────────────────────┘
```

- **Width ratio** 6:4. Target windows 1280×720 and 1920×1080; minimum 1024×600.
- **HUD** over the world: HP, gold, clock text, current place name (all in the current language). Beta-0.3: between places, and in generated squares, the place label shows the square's kind instead ("Forest" / "Forêt", from `kind.<id>.name`).
- **Action bar** under the story: text box ("What do you do?" / "Que fais-tu ?"), Act button, settings button, AI mode indicator. A status line above it shows messages like "The DM is thinking…".
- **Status line** (Beta-0.3): during a turn it follows `dm`'s status messages ("Waiting for the AI DM", and in own-key mode the connection messages of [SPEC-dm.md](SPEC-dm.md#connections)). It wraps instead of widening the story panel. There is no separate message line in the HUD: own-key messages show on the status line and in the story (steps 5a and 7).
- Portrait / phone layout (option B): M2 or later, depending on the team's answer to Q1.

## Contract: the turn loop

| # | Step | Notes |
|---|---|---|
| 1 | The player presses **Act** or Enter with a non-empty action | Empty action does nothing |
| 2 | **Lock:** action box, Act button and hero movement | The world keeps animating |
| 3 | The action appears in the story as a plain line | `narration.add_plain_line` |
| 4 | `dm.play_turn(state, action, lang)` | Copy-paste mode opens the paste dialog here |
| 5a | `ok: false` → status line shows `status`, the action text stays in the box, **unlock**, stop | Nothing changed. Beta-0.3: the story also gets `status` as a plain line under the action. A cancel (`cancelled: true`, copy-paste Cancel or Esc) is the player's choice, not an error: the story gets "Turn cancelled." (`ui.turn_cancelled`) and the status line goes back to "Ready". With neither `status` nor `cancelled`, both show the generic "Error: …" |
| 5b | `ok: true` → `core.apply_changes` + `core.apply_commands`, `turn` +1 | State changes before anything is shown |
| 6 | HUD refreshes (on the "state changed" signal) | |
| 7 | `narration.tag(narration, lang)` → `narration.add_entry` | Types out. Beta-0.3: if an `ok: true` turn has a `status` (own key: "reply cut off"), the status line shows it while the text types, and it is added as a plain line under the narration |
| 8 | On `finished_typing`: `world.run(commands)` | |
| 9 | If a roll was made, its result appears as a plain line ("Athletics: 14 + 3 = 17 vs 13, success") | The AI narrates the outcome next turn |
| 10 | On `commands_finished`: **unlock**, clear the action box, focus it | |
| 11 | Autosave (`auto` slot) | Beta-0.2 |

- `dm` errors (dropped commands, clamped numbers) go to the debug log, not to the player.
- Only one turn can run at a time.
- Beta-0.3: before step 4 the hero's tile is stored in the state; after step 10 the state takes the tile the hero really ended on (a `move_to` can stop short of an unreachable marker).

## Exits: the automatic travel turn

Beta-0.3, decided by the lead on November 2, 2026. The DM decides travel; the game only asks.

| # | Step | Notes |
|---|---|---|
| 1 | The hero's walk **ends** on an exit of the current square ([SPEC-map.md](SPEC-map.md#squares)), and no turn is running | Detected in `game/main.gd` from the world's `walk_ended(cell)` |
| 2a | The square beyond can't be entered (outside the map, `lake`, `mountain`…) | No turn. The status line says "You can't go that way." and the hero steps back one tile inside the square |
| 2b | Otherwise the game sends the turn at once, as if the player pressed Act, with an **automatic action** in the player's language: "I head north (forest)." / "Je pars vers le nord (forêt).", followed by anything the player had already typed in the action box | The texts come from `strings.csv` (`travel.north`… with `{kind}`); the kind is the neighbour's |
| 3 | The turn runs steps 2–10 above. In copy-paste mode the paste window opens, as for any turn | |
| 4 | If the reply has no `travel`, or the turn is cancelled or fails, the hero **steps back one tile** inside the square ([SPEC-map.md](SPEC-map.md#travel-the-geography-side)); on a cancel the typed text goes back into the action box | The same exit can be tried again by walking onto it |

## Copy-paste dialog

- Says in two lines what to do (in the current language): copy the prompt into a Claude chat; paste Claude's whole reply here, then Continue.
- The prompt in a read-only box (it can also be selected and copied by hand).
- **Copy prompt** button: copying starts from this click, which the browser requires. Opening the window copies nothing by itself (Beta-0.3 web fix: on the web, a copy made by the game also replaced the game's own copy of the clipboard, so the next Ctrl+V pasted the prompt back, bug B1).
- A large paste box. **Ctrl+V** (and Shift+Insert, and the box's right-click Paste) and a **Paste** button read the system clipboard at that moment. On the web the game asks the browser for it (`navigator.clipboard.readText()`; the browser may ask the player once to allow it). If the browser refuses, the game falls back to the last text the browser handed it, but never pastes the game's own prompt that way: a line in the window says the clipboard couldn't be read and to allow it in the browser (`ui.paste_blocked`).
- **Continue** and **Cancel**. Cancel = empty reply (step 5a).
- Esc = Cancel.
- Every label is in the current language and changes with it, even while the window is open.

## Starting the game (M1)

- The first launch asks for the language (default: the browser/system language, else English).
- Then straight into a new game: the world loads at `mill_road` (Beta-0.3: in the start square that holds it), the intro text types out, and the action box gets focus.
- The intro text (for now the demo line) shows only once the language is known, in that language (Beta-0.3 web fix, B5).
- The language can be changed any time in settings.

**Resume (Beta-0.3, decided November 4, 2026, bug B8).** Once the language is known (at once, or after the first-launch choice), if a save exists the game **resumes** from it instead of starting a new game: the newer of the autosave and the manual save, as for Load below. The world shows the saved square and tile, the story gets "Game resumed" (`ui.resumed`) instead of the intro text, and the status line says "Game loaded". With no save, or no save that loads, it is a new game as above. Reloading the web page therefore continues the game, and a turn played right after a reload can't overwrite the autosave with a new game.

## Save and Load (Beta-0.3)

- **Save** writes the `manual` slot; every turn writes the `auto` slot (step 11).
- **Load** (and Resume) loads the **newer** of the two files, by the time the file was last written (`SaveSystem.slots_newest_first`); on a tie (same second) the manual save wins. If the newer file doesn't load, the other one is tried. No new state field, so no migration (bug B7: Load used to prefer the manual save even when the autosave was newer).
- A load never changes the language: the language is a device setting, so the game keeps the one the player picked and writes it into the loaded state.

## Settings (M1)

| Setting | Values | Stored |
|---|---|---|
| Language | English, Français | Settings file on the device |
| AI mode | Copy-paste, Own key | Settings file |
| API key | Masked field, "Clear" button, text: "Stored only on this device (in this browser for the web version)" | Settings file, **never** in a save |

**Switching language** relabels the whole UI at once and switches the keyword list. The story already shown stays as it is; the AI narrates in the new language from the next turn.

**M2 settings:** reduce motion, text speed, animated entries.

## Wiring (provisional: Godot)

- Three autoloads with no rules in them: `Game` (holds the state, emits `state_changed`, calls `core`), `Content` (calls `content.load_all()` at start), `DM` (holds the active connection, calls `dm`).
- "Call down, signal up": `main-screen` calls into `narration`, `world` and the autoloads; they answer with signals.
- Every visible string comes from `content.ui_text(key, lang)`.

## Acceptance criteria

**M1**
- [ ] The layout matches the sketch at 1280×720 and 1920×1080 in Chrome, Edge and Firefox, with nothing cut off.
- [ ] A full turn in each AI mode runs steps 1–10 in order (manual, plus a test with a fake connection that returns a fixture reply).
- [ ] During a turn, clicking the world doesn't move the hero and a second Act does nothing.
- [ ] A failed or cancelled turn changes nothing, keeps the action text and unlocks.
- [ ] A reply with `request_roll` shows the roll line, and the next prompt contains the result.
- [ ] The HUD shows the new HP, gold, time and place right after step 5b.
- [ ] Every UI string switches between English and French; no key names (`btn_act`) show on screen.
- [ ] The API key is never in a save, the debug log or the repo.

**Beta-0.3**
- [ ] A walk ending on an exit whose neighbour can be entered sends a turn at once; its action is the automatic line in the current language followed by the typed text; in copy-paste mode the paste window opens (automated, plus manual).
- [ ] A walk ending on an exit that faces a square that can't be entered sends no turn, shows "You can't go that way." and steps the hero back.
- [ ] A cancelled exit turn, or a reply without `travel`, steps the hero back one tile inside the square and keeps the typed text (automated for the cancel).
- [ ] A reply with `travel` fades to the destination and the hero stands on the arrival tile (manual).
- [ ] The HUD place label shows the place, or the square's kind, in both languages.
- [ ] Loading a save restores the square and the hero's tile.
- [ ] In own-key mode the status line shows "Waiting for the AI DM" while the request runs; a failed turn shows its own message (e.g. "No API key set…") on the status line and in the story, not "Error: …"; a cut-off reply leaves its warning under the narration (automated with a fake connection, plus manual).

**Beta-0.3 web fixes** (bugs B1–B8 of `docs/BETA-0.3-WEB-CHECK.md`)
- [ ] B1: opening the paste window doesn't touch the clipboard; Copy prompt copies the prompt; Ctrl+V and Paste insert what the clipboard holds now, never a stale copy of the prompt (automated with a fake clipboard, plus the web build in Chromium).
- [ ] B2: a pasted prompt is refused (see SPEC-dm): "That's the prompt, not the DM's reply." on the status line and in the story; nothing changes, the typed text comes back, at an exit the hero steps back.
- [ ] B3: the paste window's labels follow the language, also when it changes while the window is open.
- [ ] B4: Cancel shows "Turn cancelled." in the current language and the status "Ready", never "Error".
- [ ] B5: on a first launch the intro line is in the language just picked.
- [ ] B6: Esc in the paste window cancels the turn like Cancel (automated, plus the web build).
- [ ] B7: Load picks the newer of the autosave and the manual save.
- [ ] B8: starting with a save resumes it ("Game resumed", the saved square, tile, clock and gold), in the device's language; starting with no save is a new game with the intro line.

**M2**
- [ ] Sheet, Pack, Quests and Codex tabs in the story panel.
- [x] Autosave after each turn (Beta-0.2); the game resumes where it was after reloading the page (Beta-0.3, see Resume).
- [ ] Rewind (one turn back), save export and import.

## Tests

- Automated: the turn loop with a fake connection, on the fixture replies (state, story lines and command calls in the right order; failure path changes nothing).
- Manual (before each build): layout at both sizes, both AI modes, language switch, lock during a turn.

## Boundaries (module)

- **Always:** change the state only through `core`; show AI text only through `narration.tag()`.
- **Ask first:** changing the turn order (it changes what the player sees and when).
- **Never:** put rules or numbers in UI code; store the API key anywhere but the settings file.

## Open questions

- Q-1 (Q1): phones and portrait screens: when?
- Should Enter send the action, or Ctrl+Enter, so players can write several lines?
- Should the paste dialog check the reply has a `<<STATE>>` line before closing, and warn "this doesn't look like a DM reply"?
