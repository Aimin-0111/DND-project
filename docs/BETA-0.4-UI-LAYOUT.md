# Beta-0.4 T1 `ui-layout`: layout v2, menu, minimap

*November 4, 2026, by Claude. Branch `Beta-0.4-ui-layout`, cut from `Beta-0.4` (`e7203e2`): one commit per step. Spec: [SPEC-main-screen.md § Layout v2](../SPEC-main-screen.md#layout-v2-beta-04).*

## What changed
- **Layout:** story on the left (40%), world on the right (60%), a top bar (Menu · place · clock · weather · Backpack) and a bottom bar (HP bar, gold). The old HUD (`ui/hud.*`) and its gear button are gone.
- **Menu** (gear + "Menu"): the AI mode on top, then Save, Load, Language (English / Français), Codex, AI settings (the M1 dialog), Close. Save and Load work as before (Load and Resume take the newer save). Esc, Close or a click outside closes it.
- **Windows** share `ui/game_window.gd` (title, Close, a `body`). One is open at a time; Esc closes it. The backpack window is empty for T3 and opens with Backpack or B.
- **Keys:** B (backpack) and M (world map) do nothing while a text field has focus or a dialog is open, so "b", "m" and "1" type into the action box.
- **World panel:** the tracked quest (top left), the minimap (top right) and the empty `DiceZone` (120 × 120, centred, ignores the mouse).
- **Minimap:** the 7 × 7 squares around the hero. Visited squares are in their kind's colour (`kinds.csv`), the others and those off the world are fog, and the hero's square has a red frame. It redraws on every state change (travel, load).
- **World map** (click on the minimap, or M): the whole 48 × 48 grid the same way. `maps/world-painted.png` goes under the fog when it exists; there is none yet, so the flat colours show. M, Esc, Close or a click outside closes it. Clicking never travels.
- **Codex window** (Menu → Codex): `Content.codex_text()`, the pages the AI gets, read-only and scrolling, lightly formatted. CRLF files and `[` stay plain text.
- **Tracked quest:** "The Silent Mill: Go to the mill", hidden when no quest is running.
- **New strings** (EN + FR): `ui.menu`, `ui.backpack`, `ui.close`, `ui.ai_settings`, `ui.clock`, `ui.world_map`, `ui.world_map_hint`, `ui.codex`, `ui.tracked_quest`, `weather.clear|rain|fog|storm|snow|ash`.
- **Files:** new in `game/ui/`: `top_bar.*`, `bottom_bar.*`, `stat_bar.*`, `menu.*`, `game_window.gd`, `backpack_window.*`, `map_view.gd`, `minimap.gd`, `world_map_window.*`, `codex_window.*`, `tracked_quest.gd`. Changed: `main.tscn`, `main.gd`, `story_panel.tscn` (padding only), `strings.csv`. `docs/OWN-KEY.md` now says Menu → AI settings instead of the gear.

## Choices Claude made (the lead can overturn them)
- The clock reads "Day 1, 08:00", the same as in the prompt.
- "First unfinished quest" follows the order of `quests.csv`. Saves sort their keys, so the order in `state.quests` would change after a load.
- Choosing a language leaves the menu open, so the player sees it switch. Every other entry closes the menu.
- The backpack window doesn't block clicks around it, so the world keeps running. The world map closes on a click outside it.
- `weather.ash` is "Ash rain" / "Pluie de cendres".
- Windows narrower than 900 px still stack the world above the story. The current stretch setting never makes the window that narrow.

## Tests (Godot 4.7.2 Linux, headless)
- `run_tests.gd`: **PASS: 28 test file(s)**, 0 `SCRIPT ERROR`. Only the expected `Parse JSON failed` and `invalid slot '../evil'` lines appear. `content_check.py --check --langs fr,en`: **OK**. `test_content_check.py`: **OK** (27).
- New `integration/test_layout_v2.gd` checks:
  - the regions and the 40/60 split;
  - each Menu entry's signal path, Esc and a click outside;
  - the backpack window;
  - "bm1" typed into the focused action box;
  - that a real click on the dice zone reaches the world;
  - the minimap colours for a fake state (visited, fog, off the world, frame) and the recentring after a travel and a load;
  - the world map's open and close paths, and that a click on it never travels;
  - the Codex in both languages, also from CRLF files;
  - the tracked quest.
- Updated to the new node paths, with nothing weakened:
  - `test_ui_actions`: the language switch goes through the Menu, and it now also checks story left / world right;
  - `test_scene_layout`: split offset −10% and the HP bar;
  - `test_status_line` and `test_world_squares`;
  - `test_settings_dialog`: Menu → AI settings, and the gear icon on the Menu button.
- Claude also looked at screenshots rendered under Xvfb at the three sizes; they are not in the repo.

## Manual checks for the lead (editor Play, then the web build)
At **1280×720**, **1920×1080** and **1024×600** (take a screenshot at 1024×600):
1. Both bars are one line, the story is about 40% and the world about 60%, and nothing is cut off or overlapping.
2. Menu: try each entry. Esc and a click outside close it, and Language relabels the whole screen.
3. Type "bm1" in the action box: only the text appears. Click the world, then press B, M and Esc.
4. Play a copy-paste turn that travels north: the minimap recentres. Then Load: it recentres on the save.
5. Open the world map by clicking the minimap and with M. A click outside closes it, and clicking a square doesn't travel.
6. Menu → Codex in English and in French. It scrolls.
7. The tracked quest shows, in both languages.
8. A click in the middle of the world (on the dice zone) walks the hero there.
9. A copy-paste turn still works (Esc cancels it), and so does an own-key turn.

## Notes for T3
- Steam (blue) and XP (amber) are new `stat_bar.tscn` instances after `BottomBar/HBox/HP`, set with `fill_color` and `show_value()`. The hotbar goes in `BottomBar/HBox/Middle`.
- Fill `backpack_window.body` and refresh it in `_refresh()`, which runs on open. Keys 1–4 go next to B and M in `main._unhandled_key_input`.
- For the writer: review the new French strings. For the artist: `maps/world-painted.png` is optional, and `ui/icons/gear.svg` is now the Menu button's icon.
