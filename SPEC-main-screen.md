# Spec: `main-screen` (layout and the turn loop)

*Module of [SPEC.md](SPEC.md). Depends on: `core`, `content`, `narration`, `dm`, `map`, `world`. Used by: `release`. When: M1 (layout, turn loop, minimal settings), Beta-0.3 (exits send the automatic travel turn; the web-check fixes of November 4, 2026: paste window, cancel, load and resume), Beta-0.4 (layout v2: menu, backpack, minimap, bars, hotbar), M2 (journal, Rewind, more settings).*

## Objective

Put the pieces on one screen and run the **turn loop** that connects them: the player types an action, the AI answers, the story types out, the world plays the commands. This module owns the order of those steps and what's locked while they run. It holds no rules itself.

## Layout v2 (Beta-0.4)

Decided on November 4, 2026. The layout, the menu, the backpack button, the minimap and the bars at the bottom are the lead's requests. The other details were filled in by Claude on the lead's behalf, and the lead can overturn any of them. Layout v2 replaces option A (world on the left, story on the right), which was used from M1 to Beta-0.3.

```
┌[⚙ Menu]────── Mill Road · Day 3, 18:40 · Rain ──────────────── [Backpack] ┐
│ STORY (≈40%)                 │ WORLD (≈60%)                     ┌───────┐ │
│ narration…                   │ The Silent Mill: Go to the mill  │minimap│ │
│                              │                                  └───────┘ │
│                              │              ( dice zone )                 │
│ [chip] [chip] [chip]         │                                            │
│ status line                  │                                            │
│ [What do you do?     ] [Act] │                                            │
├──────────────────────────────┴────────────────────────────────────────────┤
│ HP ▰▰▰▱ 14/20  Steam ▰▰▱ 4/9  XP ▰▱▱ Lv 2      [1][2][3][4]      23 gold  │
└───────────────────────────────────────────────────────────────────────────┘
```

| Region | Holds | Notes |
|---|---|---|
| **Top bar** (one line) | **Menu** button at the top left; place · clock · weather in the middle; **Backpack** button on the right | The Journal button joins it in M2 |
| **Story** (left, ≈40%) | Narration, suggestion chips, status line, action box and Act | The settings button and the AI mode indicator move into the Menu |
| **World** (right, ≈60%) | The current square; the tracked quest (top left), the minimap (top right), the dice zone (centre, reserved) | The camera keeps the hero inside this panel |
| **Bottom bar** (one line) | HP, Steam and XP bars with the level; hotbar 1–4; gold | Status effects join it with combat (M3) |

- **Width ratio** 4:6 (story : world). Target windows 1280×720 and 1920×1080; minimum 1024×600.
- **Place label** (top bar): as before, the place name or, between places and in generated squares, the square's kind ("Forest" / "Forêt", from `kind.<id>.name`). The weather name comes from `strings.csv` (`weather.<kind>`).
- **Status line**: during a turn it follows `dm`'s status messages ("Waiting for the AI DM", and in own-key mode the connection messages of [SPEC-dm.md](SPEC-dm.md#connections)). It wraps instead of widening the story panel. Own-key messages show on the status line and in the story (steps 5a and 7).
- **Art direction** (top-down 3/4 like Stardew Valley, not isometric): see [SPEC.md](SPEC.md#art-direction-beta-04).
- Portrait / phone layout (option B): M2 or later, depending on the team's answer to Q1.

### Menu (top left)

- The Menu button (gear icon + "Menu") opens a short list:
  - Save;
  - Load;
  - Language (English / Français);
  - Codex;
  - AI settings, which opens the settings dialog of [Settings](#settings-m1): AI mode and API key;
  - Close.
- The top of the list shows the AI mode ("AI: copy-paste" / "AI: own key").
- Esc or a click outside closes the menu.
- **Codex:** a read-only, scrolling window with the place, NPC and lore pages of the current language, the same pages the AI gets as its Codex. It closes with Esc or its close button.
- Sound and text speed join the menu in M2.

### Bottom bar

- **Bars:**
  - HP is red, Steam (magic) is blue and XP is amber. Each bar shows its numbers ("14/20").
  - The XP bar shows the progress from the current level to the next, plus "Lv 2". At the highest level it stays full.
  - The values come from `core` ([SPEC-core.md](SPEC-core.md#state-version-3-beta-04)).
- **Hotbar:**
  - Four slots, numbered 1–4. Each shows its item's icon and quantity.
  - Clicking a slot, or pressing its key, uses the item, as **Use** does in the backpack.
  - When the item is no longer in the pack, its slot empties.
- **Gold:** a coin icon and the amount.

### Backpack window

- **Opening and closing:** B or the Backpack button opens it; B, Esc or its close button closes it.
- **The world keeps running.** During a turn the window can still be opened to look, but Use, Equip, Unequip and the hotbar buttons are refused with "Wait for the DM to finish."
- **Equipment:** 6 slots (head, body, weapon, off-hand, feet, trinket). Each shows the item's icon or an empty frame with the slot name.
- **Pack:** a grid with one cell per stack (icon and quantity). It scrolls when full.
- **Details of the selected item:**
  - its name and description;
  - its numbers ("Armor +1", "Attack +1", "Damage 1d6", "Heals 2d4+2", "Steam +1d4+1");
  - buttons: **Use** for an item that heals or gives Steam, **Equip** for an item with a slot, **Unequip** for an equipped one, and **Hotbar 1–4** to put a usable item on the hotbar.
- **Stats line:** "Armor class 15 · Attack +5", computed by `core`.
- **Every change goes through `core`:** `use_item`, `equip`, `unequip` and `set_hotbar`. Then the state-changed signal refreshes the bars, the hotbar and the window, and the game autosaves as it does after a turn.
- **Using an item** adds a plain story line ("You use Healing Draught: +6 HP.", from `strings.csv`).
- **Refusals:** a use that would restore nothing (HP and Steam already full) is refused with a status message, and nothing is used up.
- **Fights:** in a fight (M3), using an item will cost the hero's turn. There are no fights yet.

### Minimap and world map

- **Minimap:**
  - It sits at the top right of the world panel and shows 7 × 7 squares centred on the hero's square.
  - A visited square (a key of `state.squares`) is filled with its kind's colour from `kinds.csv`.
  - Unvisited squares, and squares beyond the edge of the world, are dark fog.
  - The hero's square has a red frame.
  - It redraws after each travel and each load.
- **World map:**
  - A click on the minimap, or the M key, opens the world map window.
  - It shows the whole world grid with the same colours and fog, and a marker on the hero's square.
  - If the artist adds a painted map, `maps/world-painted.png` (any size, with the proportions of `world.png`), it is drawn under the fog instead of the flat colours.
  - It closes with M, Esc, its close button or a click outside.
- **Both are read-only.** Clicking a square doesn't travel there: travel stays the DM's decision.

### Tracked quest

- The top left of the world panel shows the first unfinished quest in `state.quests`: its title, then the text of its current stage (`quest.<id>.title`: `quest.<id>.stage<n>`), in the current language.
- It is hidden when no quest is running.
- It does nothing when clicked until the Journal exists (M2).

### Suggested actions

- When the reply has `suggestions` ([SPEC-dm.md](SPEC-dm.md#contract-the-reply-format)), up to 3 chips show above the status line, once the turn unlocks (step 10).
- Clicking a chip puts its text into the action box (replacing what was there) and focuses the box. The player still presses Act.
- Chips are cleared when a turn starts (step 2). A reply without suggestions leaves no chips.
- Chip text is untrusted AI text: it is shown as plain text, never as BBCode.

### Change pop-ups

- After step 5b and after each item use, the game compares the state before and after.
- It shows short floating texts above the bottom bar:
  - "−3 HP" in red;
  - "+2 Steam" in blue;
  - "+5 gold" in amber;
  - "+50 XP";
  - "Level 2!";
  - "+1 Healing Draught" for each item added.
- Each text rises about 20 px and fades out over 1.5 s.
- At most 4 show at once, stacked. The texts come from `strings.csv`.

### Dice zone (reserved)

- An empty area of about 120 × 120 px, centred in the world panel, named `DiceZone`. It doesn't catch clicks.
- Nothing is drawn there in Beta-0.4. Later (the lead's request), each DM turn shows a die rolling in it.

### Keys

| Key | Does | When |
|---|---|---|
| Enter | Act | The action box has focus |
| Esc | Closes the open window or menu (in the paste dialog: Cancel) | Always |
| B | Opens or closes the backpack | No text field has focus |
| M | Opens or closes the world map | No text field has focus |
| 1–4 | Uses the hotbar slot | No text field has focus and no turn is running |

Typing "b", "m" or "1" in the action box only types the character.

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
- **Beta-0.4 additions:**
  - step 2: the suggestion chips are cleared, and backpack actions and hotbar keys are refused until step 10;
  - step 5b: the numbers before the change are kept for the change pop-ups;
  - step 6: the refresh also covers the bars, the hotbar, the minimap and the tracked quest, then the pop-ups play;
  - step 10: the suggestion chips show.

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

Beta-0.4: the settings dialog opens from Menu → AI settings, and the language from Menu → Language. The gear button next to the action box is gone.

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

**Beta-0.4** (the task each criterion belongs to is in [tasks/beta-0.4.md](tasks/beta-0.4.md))
- [ ] At 1280×720 and 1920×1080 the screen matches the layout v2 sketch: top bar, story on the left (≈40%), world on the right (≈60%), bottom bar, nothing cut off. At 1024×600 nothing overlaps (manual, with a screenshot).
- [ ] The Menu button at the top left holds Save, Load, Language, Codex and AI settings. Each entry works as before, the Codex window shows the current language's pages, and Esc closes the menu (automated through each entry's signal path).
- [ ] The minimap shows the 7 × 7 squares around the hero: visited squares in their kind's colour, the others as fog, and the hero's square framed. After a travel it recentres (automated on the drawn colours, plus manual).
- [ ] A click on the minimap, or M, opens the world map with fog over the unvisited squares; M or Esc closes it.
- [ ] B opens the backpack. With the action box focused, typing "b", "m" or "1" only types the character (automated).
- [ ] In the backpack, Use, Equip, Unequip and the hotbar buttons change the state only through `core`, refresh the bars and the stats line, and autosave. During a turn they are refused (automated).
- [ ] Pressing 1 with a Healing Draught on slot 1 heals the hero, lowers the quantity, adds the story line and plays a pop-up (automated).
- [ ] The HP, Steam and XP bars and the level match the state after every turn and every item use.
- [ ] The tracked quest shows the first unfinished quest's title and stage in the current language, and hides when there is none.
- [ ] Suggestion chips appear after a reply with suggestions, fill the action box when clicked, and disappear when the next turn starts (automated with a fake connection).
- [ ] Change pop-ups show for HP, Steam, gold, XP, a level-up and each added item.
- [ ] The dice zone exists, is empty and doesn't block clicks on the world.
- [ ] Every new string is in `strings.csv` in English and French.

**M2**
- [ ] Journal: quests, story log and roll history. (The Pack and Codex of the old plan are the Beta-0.4 backpack and Codex window.)
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
- **Beta-0.4, for the lead:**
  - Should the Journal (M2) also hold the story log, so the story panel can drop old entries?
  - Should a speaker portrait (the NPC's face next to their lines) come with the Journal? It needs a `speaker` field in the reply.
