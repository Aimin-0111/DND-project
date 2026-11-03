# Beta-0.3

*Branch `Beta-0.3`, November 2, 2026. Built from `Beta-0.2` and four branches made by cloud sessions the same day. Not merged into `main`.*

## What it is

`Beta-0.2` plus:
- **Map squares.** The world is a grid of 64 × 64 squares:
  - `world.png` has one pixel per square;
  - hand-made squares are PNGs;
  - the other squares are generated, then stored in the save.

  Walking onto an exit sends the turn to the DM, which decides with the new `travel` command. Details: [BETA-0.3-MAP-SQUARES.md](BETA-0.3-MAP-SQUARES.md). The artist's guide, in French: [GUIDE-CARTES.md](GUIDE-CARTES.md).
- **Moving effects.** The poison, whisper and holy words now move.
- **Reply tests.** The tests now cover:
  - all 8 archived Haiku replies;
  - 14 crafted bad replies;
  - junk, 1 MB replies and random replies.

  Results: [m1-ai-tests.md](m1-ai-tests.md).
- **Own-key mode (Task 17).** A turn goes straight to the Claude API with the player's key, set in a settings dialog behind a gear button. Copy-paste stays the default. Details: [OWN-KEY.md](OWN-KEY.md).

## How the branch was built

| Commit | What |
|---|---|
| `c17caba` | Merge of `Beta-0.3-map-squares` (`294f9e7`) |
| `737e82c` | Merge of `Beta-0.3-moving-effects` (`6585cc9`) |
| `96c263c` | Merge of `Beta-0.3-reply-tests` (`781de2f`) |
| `1019ed1` | Merge of `Beta-0.3-own-key` (`fb02069`) |
| `9e7a558` | The parser fix found by the merge (below) |
| this commit | These notes, README and AGENTS |

No merge had a conflict. Before merging, each branch passed its own tests on the lead's PC (Windows, Godot 4.7.2).

## Fixed while merging

The merged tests passed, but they printed 5 `SCRIPT ERROR` lines:
- **What met:** the random replies from the reply-tests branch ran against the map-squares parser for the first time.
- **The bug:** a command whose `type` wasn't text (a number, `true`, a list or an object) stopped the travel check. Every command in that reply was dropped, and nothing was noted.
- **The fix:** `DmReplyParser._is_travel()` now compares only text.
- **The test:** `test_travel_command.gd` covers it, and it fails without the fix.

## Run it (lead's computer, Git Bash)

```bash
GODOT="/c/2026-2027/DND project/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path game --import                              # once after switching: imports the new map PNGs
"$GODOT" --headless --path game --script res://tests/run_tests.gd   # expect: PASS: 24 test file(s), no SCRIPT ERROR line
python tools/content_check.py --check --langs fr,en                  # expect: OK: content looks good (fr, en)
python tools/test_content_check.py                                    # expect: OK (27 tests)
"$GODOT" --path game                                                  # play in a window
```

## Check by hand

Nobody has played this branch yet, and no real model has seen the new prompt.

1. **The map.** Follow the 8 steps in [BETA-0.3-MAP-SQUARES.md](BETA-0.3-MAP-SQUARES.md#the-lead-must-try-by-hand):
   - walk across squares;
   - the fade;
   - the paste window at an exit;
   - save and load, including a Beta-0.2 save;
   - FR/EN;
   - a real-model turn;
   - S1 and S8 again, because `dm-rules.md` changed.
2. **Own key.** Do the checks in [OWN-KEY.md](OWN-KEY.md#manual-checks-left-for-the-lead). Type the real key into the game only. Task 17 is done when checks 1–4 pass.
3. **The three new effects on screen.** No word in `keywords.csv` triggers them yet. They show only when the DM tags a word itself, for example `[poison]venom[/poison]`.

## Tell the team

**Artist:**
- [GUIDE-CARTES.md](GUIDE-CARTES.md);
- the placeholder `world.png` and `squares/mill-road.png`, to replace;
- `tiles-placeholder.png`, which now has 15 tiles;
- the colour tables `kinds.csv` and `tiles.csv`, and `squares.csv`;
- the gear icon `game/ui/icons/gear.svg`, which the artist may replace.

**Writer:**
- 32 new lines in `strings.csv` to review in French (12 for the map, 20 for own key);
- new `square, x, y` columns in `locations.csv`;
- the new "Map and travel" section in `dm-rules.md`.

Words for poison, whisper and holy in `keywords.csv` wait for the Q8 vote.

## Still open

- **Parser:** the 4 parser bugs found by the reply tests, listed in [m1-ai-tests.md](m1-ai-tests.md). The parser only got the fix above.
- **Own-key follow-ups:**
  - `main.gd` doesn't show `DM.status_changed` in its status line yet;
  - SPEC-dm doesn't list the network-error message yet.

  The action text now comes back after a failed turn: the map-squares `main.gd` does it.
- **Map:** the 7 open questions at the end of [BETA-0.3-MAP-SQUARES.md](BETA-0.3-MAP-SQUARES.md#open-questions).
