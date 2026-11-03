# Beta-0.3: web build check

*Branch `Beta-0.3-web-check`, cut from `origin/Beta-0.3` at `24a989a` on November 3, 2026. This doc is the only change: no code or content was changed. A cloud session (Linux, headless Chromium) did the checks.*

## Summary

The map squares work in the web build. Walking to an exit, travel, the fade, stepping back, cancel, travel by id, and save, reload and load all behave as `docs/BETA-0.3-MAP-SQUARES.md` describes.

The problems are in the copy-paste window and around it, and none comes from Beta-0.3: they all date from the M1 slice (`85e706b`, Oct 19). The worst one, for the lead's web play test: **the first Ctrl+V in the reply box pastes the game's own prompt back, not the reply copied from the Claude chat.**

| # | Check | Result |
|---|---|---|
| 1 | First-launch language choice | **Pass** (the demo line stays English, B5) |
| 2 | Walk to the top-middle exit: the paste window opens with "I head north (meadow)." | **Pass** |
| 3 | Paste the `travel north` reply: fade, arrival on the matching edge, HUD "Meadow", Oda hidden | **Pass** |
| 4 | A reply without travel: the hero steps back | **Pass** |
| 5 | Cancel: the hero steps back and the typed text comes back | **Pass** (the story line says "Error: Cancelled.", B4) |
| 6 | Travel back by square id | **Pass** |
| 7 | Save, reload the page, load: same square and tile, save in IndexedDB | **Pass** (see B7 and B8) |
| 8 | Switch FR/EN | **Fail** in the paste window, which stays English (B3); the rest passes |
| 9 | Gear settings dialog | **Pass** |
| 10 | One copy-paste turn | **Pass** when the reply is typed in. **Fail** with a real Ctrl+V paste (B1) |
| — | Esc closes the paste window (SPEC-main-screen) | **Fail** (B6) |
| — | Load with no save file | **Pass**: "No save file" |

## What was built and how

- **Godot:** the official `Godot_v4.7.2-stable_linux.x86_64.zip` and `Godot_v4.7.2-stable_export_templates.tpz`, both downloaded from the `godotengine/godot` release `4.7.2-stable` (no download was blocked).
  - Godot went to `/opt/godot/`.
  - The templates went to `~/.local/share/godot/export_templates/4.7.2.stable/`. Only the `web_*` templates and `version.txt` were extracted, to save disk space.
  - None of this is in the repo.
- **Import:** `godot --headless --path game --import` took 14 s. It changed no tracked file.
- **Tests:** `godot --headless --path game --script res://tests/run_tests.gd` gave **`PASS: 24 test file(s)`** in 6 s, with 0 `SCRIPT ERROR` lines.
  - The `ERROR: Parse JSON failed…` lines come from the bad-reply tests (`test_bad_replies.gd`). They are expected.
  - Two `Nodes with non-equal opposite anchors…` warnings come from `test_ui_actions.gd`.
- **Export:** `godot --headless --path game --export-release "Web" /opt/build/web/index.html` (the repo's "Web" preset, `thread_support=false`, so the no-threads release template) took 9 s.
  - Output: `index.wasm` 39.5 MB, `index.pck` 275 KB, `index.js` 280 KB.
  - The pck contains no `sk-ant` string.
- **Serve:** `python3 -m http.server 8000` in `/opt/build/web`.
- **Browser:** headless Chromium (the one pre-installed in the cloud container) driven by Node Playwright.
  - Window 1280 × 720, scale 1. Flags: `--use-angle=swiftshader --enable-unsafe-swiftshader`.
  - WebGL 2 ran on **SwiftShader, a software renderer**. There is no GPU here.
  - Godot printed: `OpenGL ES 3.0 (WebGL 2.0) - Compatibility`, `Emscripten 4.0.20, single-threaded, no GDExtension support`.
  - `navigator.language` was `en-US`.
- **How I played it:** scripted mouse clicks on world tiles. The camera follows the hero, so a tile's screen position comes from the hero's tile.
  - I checked the hero's tile by pressing Save and reading `saves/manual.json` and `saves/auto.json` from IndexedDB (`/userfs` database, `FILE_DATA` store).
  - I read the prompt by selecting the prompt box, pressing Ctrl+C and reading the browser clipboard.
  - I saw the fade by reading one pixel of the world view after every frame.
  - The scripts and screenshots are in the session's scratch folder and are not committed.

## The checks

**1. First-launch language choice: pass.**
- A dark shade over the whole screen shows "Choose your language / Choisis ta langue" with "Français" and "English". Clicks on the world do nothing meanwhile.
- English and French both work. After a reload the choice is remembered, and the picker does not come back.
- The demo line "The fire, the frost and the lightning." stays English after picking Français (B5).

**2. Walk to the top-middle exit: pass.**
- From Mill Road (16, 31), three clicks: (27, 21), (31, 10), then (31, 0).
- On arrival, the turn started by itself. The story showed "> I head north (meadow)." and the paste window opened.
- The prompt's TURN INPUT holds `"action": "I head north (meadow).", "language": "en"`. The MAP part lists the meadow `sq_24_23` to the north.
- Off a place, the HUD shows "Road" (the start square's kind), as designed.
- **Bonus:** the game had already copied the prompt to the browser clipboard when the window opened. Reading the clipboard gave `=== RULES ===…`.

**3. The `travel north` reply: pass.**
- I typed the sample reply in the reply box and pressed Continue. The narration typed out first, then the fade started.
- **Fade**, from the pixel read after every frame (milliseconds after Continue; frames were about 100 ms apart, see "Load and frame time"):

  | ms | Pixel colour |
  |---|---|
  | 0 | grass (58, 107, 53) |
  | 1266 | half dark (33, 61, 30) |
  | 1394 | black (1, 2, 1) |
  | 1570 | black (0, 0, 0) |
  | 1676 | half dark (33, 61, 30) |
  | 1794 | grass again |

  About 0.25 s out and 0.25 s in, as designed.
- **Arrival:** `sq_24_23`, tile (31, 63). That is the bottom edge, the matching edge for a trip north. The screen shows the hero on the bottom row, and the camera stays inside the square (no black beyond the edge).
- **HUD:** "Meadow". The clock went from 08:00 to 08:20 (`time_advance_minutes: 20`).
- **Oda hidden:** I walked to (52, 32) in the meadow. The tile where Oda would stand, (54, 29), shows only grass.
  - **Oda visible:** back in `sq_24_24`, standing at (51, 29), she is drawn just below the mill door. The HUD says "Vieux moulin" (in French).

**4. A reply without travel: pass.**
- In the meadow, I walked onto the south exit (31, 63). The prompt held "I head south (road).".
- I pasted the "Brambles block the gap…" reply. The narration showed, the hero walked back to (31, 62), and the autosave was written.
- In French in the start square, the hero went from (31, 0) back to (31, 1). The autosave says (31, 1).

**5. Cancel: pass.**
- I typed "slowly" in the action box, then walked onto (31, 63). The prompt held "I head south (road). slowly".
- After Cancel, the hero stood on (31, 62) and "slowly" was back in the action box.
- The story shows "> I head south (road). slowly", then "Error: Cancelled.", and the status says "Error" (B4).

**6. Travel back by square id: pass.**
- I typed "I go back to the mill road", pressed Enter and pasted the third sample reply (`move_to` written first, then `travel` to `sq_24_24`).
- The result: `sq_24_24`, tile (16, 31), `location: mill_road`, HUD "Mill Road", the hero on the road.
- The final state is right. At about 9 frames per second I could not see the order of the travel and the walk on screen.

**7. Save, reload, load: pass.**
- In the meadow at (52, 32), I pressed Save, reloaded the page, then pressed Load.
- The square, the tile and the picture were the same as before: `sq_24_23`, (52, 32), with the same rocks, flowers and trees.
- The saves live in IndexedDB as `/userfs/godot/app_userdata/Brasswake Reach/saves/manual.json` and `auto.json`, next to `settings.cfg`.
- A save reaches IndexedDB a moment after "Game saved" shows, because Godot syncs its files in the background. A read 1.5 s after Save once still showed the older file; after 3 s it was always there.
- After the reload, the game first starts a **new game** at Mill Road, 08:00. It does not resume by itself (B8).
- The story panel after Load only shows "Game loaded", not the earlier story.

**8. Switch FR/EN: fail (the paste window).**
- The EN/FR button switches the HUD at once: "PV 12/12", "Or 10", "Route", "IA : copier-coller", "Sauvegarder", "Charger".
  - It also switches the action box ("Que fais-tu ?"), "Agir", the status ("Prêt", "En attente du MJ IA", "Partie sauvegardée") and the place label ("Vieux moulin").
- The automatic action in French: "> Je pars vers le nord (prairie)." It is in the prompt too.
- **The paste window still says "Paste reply", "Cancel" and "Continue" in French** (B3).
- A French cancel prints "Erreur: Cancelled." (B4).
- I did not see "Prairie" in the HUD: I did not stand in a meadow while in French.

**9. Gear settings dialog: pass.**
- The gear opens "Settings" with:
  - "AI mode": "Copy-paste (free)";
  - "Claude API key": a masked, empty field with the placeholder "Paste your key here", and a "Clear" button;
  - "Stored only on this device (in this browser for the web version).";
  - "Cancel" and "Save".
- Esc closes it. **No key was typed.** The HUD still says "AI: copy-paste".

**10. One copy-paste turn: pass when typed, fail with Ctrl+V.**
- At the mill: "I listen to the mill wheel", then Enter. The paste window opened, and the prompt held the action.
- I typed a reply in the reply box. Its narration typed out, with "spark" and "fire" animated. The clock went from 08:20 to 08:25, and the autosave was written.
- In a second session, I copied the reply into the clipboard from another tab and pressed Ctrl+V in the reply box. **The prompt came out instead** (B1).

## Load and frame time

**Load** (local server, a fresh browser profile each time, so no browser cache):

| Moment | Time |
|---|---|
| The engine starts (Godot hides its loading bar) | 2.5 s |
| First frames | 3.0 s |
| The very first start of the session | 5.4 s to the engine start |
| Page reload | 2.8 s to the first frames |

- The `.wasm` (39.5 MB) downloaded in 0.3 s from `localhost`.
- `python -m http.server` does not compress files. Online (itch.io), the 39.5 MB `.wasm` will be the main wait.

**Frame time** = the time between two browser animation frames, measured over 3 s each:

| Situation | Average | Median | 95th percentile |
|---|---|---|---|
| Idle, language picker on screen | 115 ms | 116 ms | 144 ms |
| Idle, start square (64 × 64) | 103 ms | 98 ms | 135 ms |
| Walking, start square | 115 ms | 113 ms | 148 ms |
| Idle, generated meadow | 109 ms | 108 ms | 136 ms |
| Idle, next to the mill | 112 ms | 114 ms | 159 ms |

- That is about 9 frames per second, but **this is software rendering (SwiftShader) on a 4-core cloud machine, not the lead's PC.**
- The frame time is the same with the language picker over the map as on the map. So it measures how fast the CPU can draw a 1280 × 720 page, not the cost of 64 × 64 squares.
- Even at 9 frames per second, the walks reached their tiles at the expected speed.
- The lead should measure the real frame rate on their PC, for example in Chrome's Performance tab.

## Console

Over all the runs, the browser console showed only:
- Godot's three start lines (version, `OpenGL ES 3.0 … Compatibility`, `Emscripten 4.0.20, single-threaded…`);
- once per load: `GL Driver Message (OpenGL, Performance, …): GPU stall due to ReadPixels`. This is a SwiftShader performance note at start-up. It showed more often while my script was reading pixels for the fade;
- in one run where the prompt itself was submitted as the reply (see B2): `ERROR: Parse JSON failed. Error at line 7: Expected '}' or ','` and `WARNING: DM reply: The state block is not valid JSON.`

There were no `SCRIPT ERROR` lines, no uncaught page errors and no failed requests. The game printed no `Turn:` or `Load:` warnings.

## Bugs found

Not fixed here: other sessions are editing `main.gd`, the HUD and the parser. All of these date from the M1 slice (`85e706b`), not from Beta-0.3.

### B1. The first Ctrl+V in the reply box pastes the prompt (high: it breaks the web copy-paste loop)

**Steps:**
1. Start the web build and press Act with any action. The paste window opens.
2. In another tab, copy any text (the Claude reply).
3. Come back, click the reply box and press Ctrl+V.

**Seen:** the whole prompt (`=== RULES ===` … `=== TURN INPUT ===`) is pasted. Clear the box and press Ctrl+V again: now the copied reply comes out, and the turn plays normally.

**Why:**
- When the window opens, `copy_paste_adapter.gd` calls `DisplayServer.clipboard_set(prompt)`, which fills Godot's own copy of the clipboard.
- On the web, `DisplayServer.clipboard_get()` returns that copy at once. It only starts an asynchronous `navigator.clipboard.readText()` to refresh it for next time. So the first paste gets the old text.
- Headless Chromium sent no browser `paste` event here. In desktop Chrome or Edge a real Ctrl+V also fires one, which refreshes Godot's copy, but most likely after the key was already handled. **The lead should confirm this in their own browser.**

**Proposed fix (in `game/ui/paste_dialog.gd`, not in `main.gd`):**
- Refresh Godot's copy before the player pastes: call `DisplayServer.clipboard_get()` (and ignore the result) when the reply box gets focus, and on `NOTIFICATION_APPLICATION_FOCUS_IN` while the window is open (the player coming back from the Claude tab).
- Better still, add a **Paste** button that reads `navigator.clipboard.readText()` through `JavaScriptBridge` and puts the text in the box. A click counts as a user gesture. Chrome asks once for clipboard permission on `localhost`.
- While there, add the spec's **Copy prompt** button and the two instruction lines (SPEC-main-screen, "Copy-paste dialog"). Today the copy happens without a click. It worked in Chromium, but some browsers refuse a clipboard write that doesn't follow a click.

### B2. A pasted prompt is accepted as a reply (medium, made likely by B1)

**Steps:** do B1 and press Continue with the prompt in the reply box.

**Seen:**
- The parser finds the `<<STATE>>` that `dm-rules.md` mentions inside the RULES text. Everything before it becomes the narration: screens of DM rules.
- The JSON after it fails. As SPEC-dm says, the turn is then "narration only".
- The story panel spends a long time typing the rules, with "Waiting for the AI DM". More than 8 s at 9 frames per second; the narration also goes into the story memory.

**Proposed fix:**
- Before parsing (in `dm.gd`, or in the reply checks once the parser session is done), refuse a reply that contains `=== TURN INPUT ===` or starts with `=== RULES ===`.
- Show a translated line, for example `ui.reply_is_prompt`: "That's the prompt, not the DM's reply." / "C'est le prompt, pas la réponse du MJ.".
- Treat it like a failed turn: the hero steps back and the typed text comes back.

### B3. The paste window is never translated (medium)

**Steps:** first launch on an English browser, then pick Français. Or switch EN → FR with the HUD button. Then press Act.

**Seen:** "Paste reply", "Cancel" and "Continue", while the rest of the screen is in French.

**Why:** `paste_dialog.gd` sets its labels only in `_ready()`, before the first-launch choice, and never listens to `Content.language_changed`.

**Proposed fix:** do what `settings_dialog.gd` does: a `_localize()` function, called from `_ready()` and connected to `Content.language_changed`.

### B4. A cancel shows "Error: Cancelled." in English (low)

**Steps:** open the paste window (any turn) and press Cancel, in French.

**Seen:** "Erreur: Cancelled." in the story, and the status "Erreur". In English: "Error: Cancelled.". A cancel is the player's choice, not an error.

**Why:** `dm.gd` returns the hard-coded string `"Cancelled."`, and `main.gd` `_show_errors` prints every failure as an error.

**Proposed fix:**
- Add `ui.turn_cancelled` to `strings.csv` ("Tour annulé." / "Turn cancelled."), for the writer to review.
- Have `DM.play_turn` return `"cancelled": true`. Have `main.gd` show that line without "Error", and set the status back to "Ready".
- This touches `main.gd`, so it should wait for the other sessions.

### B5. The demo line keeps the first language (low)

**Steps:** first launch on an English browser, pick Français.

**Seen:** the story shows "The fire, the frost and the lightning." in English. Switching the language later doesn't change it either.

**Why:** `main.gd` `_ready()` calls `_show_demo_line()` before the language picker.

**Proposed fix:** show the demo line (or the M1 intro text) after the language is known, so in `_on_language_picked` on a first launch.

### B6. Esc does not close the paste window (medium)

**Steps:** open the paste window and press Esc.

**Seen:** nothing happens. SPEC-main-screen says "Esc = Cancel". The settings dialog does close on Esc.

**Proposed fix:** an `_input` in `paste_dialog.gd` like the one in `settings_dialog.gd`: on `ui_cancel` while visible, call `_on_cancel()` and mark the input as handled.

### B7. Load picks the manual save even when the autosave is newer (medium: progress is lost)

**Steps:**
1. Press Save at 08:00.
2. Play one turn that adds 10 minutes. The autosave now says 08:10.
3. Reload the page and press Load.

**Seen:** the clock says 08:00. The newer autosave was ignored (checked in the browser: after Load, `time_minutes` 480, not 490).

**Why:** `main.gd` `_on_load` always tries `manual` first and only uses `auto` when there is no manual save.

**Proposed fix:** load whichever file is newer. `FileAccess.get_modified_time()` on the two save paths would do. It needs no new field in the state, so no migration. Or add a second button ("Load autosave").

### B8. A page reload starts a new game instead of resuming (medium, spec gap)

**Steps:** play a turn (the autosave is written), then reload the page.

**Seen:** a new game at Mill Road, 08:00, until the player presses Load. SPEC-main-screen expects: "the game resumes where it was after reloading the page".
- The risk: a player who plays a turn before pressing Load overwrites the autosave with the new game.
- With B7, a manual save then hides even that.

**Proposed fix:** in `main.gd`, after the language is known, load `auto` if it exists (or the newer save, as in B7) and call `_after_load()`.

## Smaller notes

- `dm-rules.md` only gives the English form of the exit action ("I head north (forest)."). In French the DM gets "Je pars vers le nord (prairie)." with `"language": "fr"`. The writer could add the French form before the S1 and S8 reruns.
- In French the HUD panel is wider ("Sauvegarder", "Charger"), and the paste window covers its right edge while it is open.
- The paste window is see-through, so the world shows behind the prompt and reply boxes. It is readable, but busy.
- As the map-squares doc already notes (open question 2), clicking the hero while it stands on an exit tile sends the exit turn again.

## Not checked

- A real AI model, and the own-key mode (no key here, and none was typed).
- A real GPU, Windows, the lead's PC, Firefox, Edge, and any non-headless browser. So no real `paste` event (B1) and no real frame rate.
- Loading a Beta-0.2 save in the web build.
- Walking across several generated squares east or west. Only north, and back by id, were played.
- How the fade and the walk feel at a normal frame rate.

## Rerun it (Linux)

```bash
godot --headless --path game --export-release "Web" /tmp/brasswake-web/index.html
```

```bash
python3 -m http.server 8000 --directory /tmp/brasswake-web
```

On the lead's PC, use the `"$GODOT"` path from `docs/BETA-0.3-MAP-SQUARES.md` and `builds/web` as in `docs/OWN-KEY.md`. The export templates must be installed first.
