# Beta-0.3: web bugs B1–B8 fixed

*Branch `Beta-0.3-web-bugs`, cut from `origin/main` (`71ee473`) on November 4, 2026, with `Beta-0.3-parser-fixes`, `Beta-0.3-status-line` and `Beta-0.3-web-check` merged in first (they merged cleanly). It fixes the eight bugs of [BETA-0.3-WEB-CHECK.md](BETA-0.3-WEB-CHECK.md). A cloud session (Linux, headless Chromium) did the work. Not merged into `main`, no PR.*

## Summary

- **All eight bugs are fixed**, and each one has an automated test that failed before the fix.
- **The worst one, B1, is gone in the web build:** the first Ctrl+V in the reply box now pastes the reply copied in another tab. I checked this in headless Chromium.
- **The spec changed first:** `SPEC-main-screen.md` (paste window, cancel, Save and Load, Resume, acceptance criteria), `SPEC-dm.md` (a pasted prompt, `cancelled`), `SPEC-core.md` (`slots_newest_first`).
- **No change to the state's shape, so no migration.** Old saves load as before.
- **Two behaviour changes the lead should know about:**
  1. Opening the paste window no longer copies the prompt by itself: the player clicks **Copy prompt**.
  2. Starting the game (or reloading the page) resumes the newer save instead of starting a new game.

| Check | Result |
|---|---|
| `godot --headless --path game --script res://tests/run_tests.gd` | **`PASS: 27 test file(s)`**, 0 `SCRIPT ERROR` lines (was 25 files) |
| `python tools/content_check.py --check --langs fr,en` | **`OK: content looks good (fr, en)`** |
| Before the fixes, the same runner with the new tests | `FAIL: 35 error(s)`: every bug failed at least one check |
| Web export (`"Web"` preset), headless Chromium | B1 and B6 pass, along with B2, B3, B5, B7 and B8 (below) |
| `index.pck` | No `sk-ant` string. No key was typed anywhere |

## What changed, bug by bug

### B1. The first Ctrl+V pasted the prompt (high)

**Cause** (from the Godot 4.7.2 web source, `display_server_web.cpp`): `clipboard_set()` stores the text in Godot's own copy of the clipboard. Then `clipboard_get()` returns that copy at once and only *starts* a browser read, which refreshes the copy for the next paste.

**Fix:**
- `copy_paste_adapter.gd` no longer copies the prompt when the window opens. It also no longer sends its hard-coded English "Prompt copied…" status.
- The paste window (`ui/paste_dialog.gd` and `.tscn`) has:
  - the two help lines;
  - a **Copy prompt** button (the copy starts from the click, as the spec and browsers want);
  - a **Paste** button;
  - a notice line under the reply box.
- The new `ui/reply_box.gd` (the reply box's script) overrides `TextEdit._paste()`. Every paste goes to the window: Ctrl+V, Shift+Insert and the right-click Paste.
- The window reads the clipboard at that moment.
  - On the web it asks the browser directly (`navigator.clipboard.readText()` through `JavaScriptBridge`) and puts the answer at the caret when it arrives.
  - On desktop it calls `DisplayServer.clipboard_get()`, which is synchronous there.
- **If the browser refuses**, the window falls back to Godot's copy. It never pastes the game's own prompt that way: instead it shows "The game can't read the clipboard. Allow access in your browser, then try again."
- If the pasted text *is* the prompt, the window warns at once (see B2).

**Tests:** `test_web_bugs.gd` uses a fake clipboard. It checks that:
- opening the window copies nothing, and Copy prompt copies the prompt once;
- a real Ctrl+V key event (pushed through the viewport), the box's own paste and the Paste button all insert the copied reply;
- a refused read never pastes the prompt and shows the notice, but uses Godot's copy when that copy isn't the prompt;
- the pasted reply plays the turn.

### B2. A pasted prompt was accepted as a reply (medium)

**Fix:**
- New `PromptBuilder.is_prompt_text(text)`: true when the text holds `=== TURN INPUT ===` or starts with `=== RULES ===`. The two headers are now constants that `to_single_text` also uses.
- `DM.play_turn` checks this before parsing. A match returns `ok: false` with `status` "That's the prompt, not the DM's reply." (`ui.reply_is_prompt`).
- `main.gd` already shows `status` on the status line and in the story. The typed text comes back, and at an exit the hero steps back.
- Nothing reaches the parser or the story memory.

**Tests:** `is_prompt_text` on both headers and on a real reply. A full turn with the prompt pasted back checks the message, the unlock, the typed text and an unchanged state.

### B3. The paste window was never translated (medium)

**Fix:** `paste_dialog.gd` has a `_localize()` called from `_ready()` and on `Content.language_changed`, like `settings_dialog.gd`. It also re-translates the notice line.

**Tests:** in both languages, all seven labels (title, two help lines, four buttons) match `strings.csv`.

### B4. Cancel showed "Error: Cancelled." (low)

**Fix:**
- `DM.play_turn` returns `cancelled: true` on a copy-paste cancel. `errors` still holds `"Cancelled."` for the debug log.
- `main.gd` `_show_cancelled()` puts "Turn cancelled." / "Tour annulé." in the story and sets the status back to "Ready".

**Tests:** a cancel in both languages: no "Error", nothing English in French, the typed text comes back. `test_status_line.gd` expected the old "Error: Cancelled.", so I updated it to the new behaviour.

### B5. The demo line kept the first language (low)

**Fix:**
- The demo line moved from `main.gd` into `strings.csv` (`story.demo_line`). It was hard-coded text before.
- It shows only once the language is known: at start if one is saved, otherwise after the first-launch choice (`_start()`).

**Tests:** first launch: no demo line before the choice, then the line in the language picked and not the other one.

`test_scene_layout.gd` used the real settings file and expected the demo line. It now uses its own settings file with a language saved.

### B6. Esc did not close the paste window (medium)

**Fix:** `paste_dialog.gd` `_input()`: on `ui_cancel` while the window is open, mark the input as handled and cancel.

**Tests:** an Esc key event pushed through the viewport closes the window and cancels the turn like Cancel.

### B7. Load preferred the manual save (medium)

**Fix:**
- New `SaveSystem.slots_newest_first(slots)`: the slots that have a file, newest first by `FileAccess.get_modified_time()`. File times are in whole seconds; on a tie the slot listed first (manual) wins.
- `main.gd` `_load_newest()` loads the first one that loads, so a broken newer file falls back to the other.
- No new state field, so no migration.

**Tests:**
- `test_save_slots.gd` (new): missing files, newest first, invalid names, ties.
- `test_web_bugs.gd`: Load after a newer autosave, then after a newer manual save.
- Both wait 1.1 s between writes, which adds about 3 s to the run.

### B8. A reload started a new game (medium, spec gap)

**Spec first:** a new "Resume" paragraph and a "Save and Load" section in `SPEC-main-screen.md` (lead's request of November 4, 2026, in this task):
- once the language is known, if a save exists, the game resumes the newer save;
- the story says "Game resumed" (`ui.resumed`) instead of the intro line;
- a load never changes the language: it is a device setting.

The M2 criterion "the game resumes where it was after reloading the page" is ticked as done in Beta-0.3.

**Fix:**
- `main.gd` `_start()` runs after the language is known and calls `_load_newest()`, then `_after_load("Game resumed")`.
- A Load or Resume keeps the player's current language and writes it into the loaded state. Before, Load switched the UI to the save's language.

**Tests:**
- A save in French with the device in English resumes: gold, clock, the hero's tile, English kept, "Game resumed", no demo line.
- The same on a first launch, where the resume waits for the language choice.
- With no save it is still a new game.

### Test isolation (needed for B7 and B8)

- `SaveSystem.save_dir` is now a static variable. The default is still `user://saves/`.
- `run_tests.gd` points it at `user://__test_saves/` and empties that folder before every test file.
- So the tests never touch the player's real saves. Before, `test_ui_actions.gd` deleted the real `manual` save on every run.
- A leftover autosave can't make a test scene resume by itself.

## New strings (EN + FR, for the writer to review)

`ui.paste_help_1`, `ui.paste_help_2`, `ui.paste`, `ui.prompt_copied`, `ui.paste_blocked`, `ui.reply_is_prompt`, `ui.turn_cancelled`, `ui.resumed` and `story.demo_line` (moved out of `main.gd`). `ui.copy_prompt` already existed and is now used.

## Web check (headless Chromium)

**Same setup as the web check:**
- the official Godot 4.7.2 Linux build and web templates;
- an export with the repo's "Web" preset (5 s);
- `python3 -m http.server`;
- Node Playwright, Chromium with SwiftShader, 1280 × 720;
- the clipboard permissions granted to `localhost`, except in the refusal run.

| # | Check | Result |
|---|---|---|
| B5 | First launch: picker on screen, no demo line yet; English picked → "The fire, the frost and the lightning." | **Pass** |
| B1 | Act → the window opens; the browser clipboard is still empty (nothing copied by itself) | **Pass** |
| B1 | Copy prompt → the clipboard holds `=== RULES ===…`, the TURN INPUT part and the action | **Pass** |
| B1 | Reply copied in another tab, then the reply box clicked and **one Ctrl+V** → the reply shows in the box. Continue → the turn plays: autosave 08:15, gold 13, turn 1 (the reply asked for +15 min, +3 gold) | **Pass** |
| B6 | Act, then **Esc** → the window closes, the story says "Turn cancelled.", the status says "Ready", the typed text is back | **Pass** |
| B2 | Copy prompt, then Ctrl+V → the prompt shows with "That's the prompt, not the DM's reply." under it. Continue → the same line in the story and the status, nothing changed | **Pass** |
| B3 | HUD switched to FR, then Act → "Coller la réponse", both help lines, "Copier le prompt", "Coller", "Annuler", "Continuer" | **Pass** |
| B1 | The **Paste** button with a reply copied in another tab → the reply shows in the box | **Pass** |
| B7, B8 | Save at 08:15, then a turn to 08:25, then a page reload (same profile) → "Game resumed", HUD 08:25 and gold 13. Load → still 08:25 | **Pass** |
| B1 | Clipboard read refused (new profile, no read permission): Copy prompt, then Ctrl+V → nothing pasted; the window says "The game can't read the clipboard. Allow access in your browser, then try again." The console gets one `Paste:` warning with the browser's `NotAllowedError` | **Pass** |

- As in the web check, headless Chromium sent **no** browser `paste` event: a listener counted 0. The fix doesn't need one.
- The console showed only Godot's start lines, the SwiftShader `GPU stall` note and the expected warning in the refusal run. No `SCRIPT ERROR`, no page errors.

## Left for a manual check (lead's PC)

1. **B1 in real browsers:** Chrome or Edge, and Firefox, on Windows, with a real Claude tab.
   - Chrome asks once for clipboard access on `localhost` at the first Ctrl+V or Paste. **Allow** is needed. If it's blocked, the window shows the "can't read the clipboard" line; allow it via the lock icon next to the address.
   - Firefox shows a small "Paste" menu at the caret for `readText()` instead of a permission prompt. Click it once.
   - Then check that the reply pastes in one piece and the turn plays.
2. **Copy prompt** into a real Claude chat, in Chrome, Edge and Firefox: the prompt arrives in one piece.
3. **Resume after a reload** with a real save from Beta-0.2 or Beta-0.3. Also check that a French player stays in French after a reload, even if the last save was made in English.
4. **Desktop** (the Windows editor or an export): Ctrl+V and Paste in the reply box. This goes through `DisplayServer.clipboard_get()`; it is covered by the tests but not run on Windows here.
5. **Writer review** of the new French and English strings above.
6. **Open, not fixed here** (smaller notes from the web check):
   - the paste window is see-through and covers the right edge of the HUD (worse in French);
   - `dm-rules.md` gives only the English form of the exit action;
   - clicking the hero on an exit tile sends the exit turn again.

## Files

- **Spec:** `SPEC-main-screen.md`, `SPEC-dm.md`, `SPEC-core.md`.
- **Code:**
  - `game/main.gd`, `game/autoload/dm.gd`;
  - `game/ai/copy_paste_adapter.gd`, `game/ai/prompt_builder.gd`;
  - `game/core/save_system.gd`;
  - `game/ui/paste_dialog.gd`, `game/ui/paste_dialog.tscn`, `game/ui/reply_box.gd` (new).
- **Content:** `game/content/i18n/strings.csv`.
- **Tests:**
  - new: `game/tests/integration/test_web_bugs.gd`, `game/tests/unit/test_save_slots.gd`;
  - updated: `test_status_line.gd` (B4), `test_scene_layout.gd` (B5), `test_world_squares.gd` (the `_after_load` argument);
  - `run_tests.gd`: the two new files and the test save folder.

## Rerun it (Linux)

```bash
godot --headless --path game --script res://tests/run_tests.gd
```

```bash
python3 tools/content_check.py --check --langs fr,en
```

```bash
godot --headless --path game --export-release "Web" /tmp/brasswake-web/index.html
```

```bash
python3 -m http.server 8000 --directory /tmp/brasswake-web
```
