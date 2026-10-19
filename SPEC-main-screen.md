# Spec: `main-screen` (layout and the turn loop)

*Module of [SPEC.md](SPEC.md). Depends on: `core`, `content`, `narration`, `dm`, `world`. Used by: `release`. When: M1 (layout, turn loop, minimal settings), M2 (tabs, autosave, Rewind, more settings).*

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
- **HUD** over the world: HP, gold, clock text, current place name (all in the current language).
- **Action bar** under the story: text box ("What do you do?" / "Que fais-tu ?"), Act button, settings button, AI mode indicator. A status line above it shows messages like "The DM is thinking…".
- Portrait / phone layout (option B): M2 or later, depending on the team's answer to Q1.

## Contract: the turn loop

| # | Step | Notes |
|---|---|---|
| 1 | The player presses **Act** or Enter with a non-empty action | Empty action does nothing |
| 2 | **Lock:** action box, Act button and hero movement | The world keeps animating |
| 3 | The action appears in the story as a plain line | `narration.add_plain_line` |
| 4 | `dm.play_turn(state, action, lang)` | Copy-paste mode opens the paste dialog here |
| 5a | `ok: false` → status line shows `status`, the action text stays in the box, **unlock**, stop | Nothing changed |
| 5b | `ok: true` → `core.apply_changes` + `core.apply_commands`, `turn` +1 | State changes before anything is shown |
| 6 | HUD refreshes (on the "state changed" signal) | |
| 7 | `narration.tag(narration, lang)` → `narration.add_entry` | Types out |
| 8 | On `finished_typing`: `world.run(commands)` | |
| 9 | If a roll was made, its result appears as a plain line ("Athletics: 14 + 3 = 17 vs 13, success") | The AI narrates the outcome next turn |
| 10 | On `commands_finished`: **unlock**, clear the action box, focus it | |
| 11 | Autosave | M2 |

- `dm` errors (dropped commands, clamped numbers) go to the debug log, not to the player.
- Only one turn can run at a time.

## Copy-paste dialog

- Says in two lines what to do (in the current language).
- **Copy prompt** button: copying starts from this click, which the browser requires.
- A large paste box, then **Send** and **Cancel**. Cancel = empty reply (step 5a).
- Esc = Cancel.

## Starting the game (M1)

- The first launch asks for the language (default: the browser/system language, else English).
- Then straight into a new game: the world loads at `mill_road`, the intro text types out, and the action box gets focus.
- The language can be changed any time in settings.

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

**M2**
- [ ] Sheet, Pack, Quests and Codex tabs in the story panel.
- [ ] Autosave after each turn; the game resumes where it was after reloading the page.
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
