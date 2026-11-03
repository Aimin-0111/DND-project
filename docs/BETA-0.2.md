# Beta-0.2

*Branch `Beta-0.2`, October 19, 2026. Built from `main` (the approved spec and M1 plan) and Alban's `Beta-0.1`. Not merged into `main`.*

## What it is

A version you can play on your own computer. It is Alban's M1 slice plus fixes:
- one zone;
- a hero you move by clicking;
- an animated story in French and English;
- a copy-paste AI turn;
- JSON saves.

The fixes bring it closer to the approved spec and apply the team answers we have. About half of the questionnaire is still open, so the beta uses a default for each open question (see the table below). Change these defaults when the answers arrive.

## How the branch was built

| Commit | What |
|---|---|
| `bf4ddf4` | `main` (`db91a88`) merged with `Beta-0.1` (`85e706b`). Where both sides changed a file, `main` was kept: `SPEC.md`, `tasks/plan.md`, `tasks/todo.md`, `README.md`, `AGENTS.md`. Alban's own spec and plan are still in the history (`git show 85e706b:SPEC.md`) |
| `58c2fc9` | Fixes from the Beta-0.1 review + team answers |
| `17d5082` | Effects that aren't built yet show in their still colour |
| this commit | These notes, README and AGENTS |

## Run it (lead's computer, Git Bash)

```bash
GODOT="/c/2026-2027/DND project/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path game --script res://tests/run_tests.gd   # expect: PASS: 14 test file(s)
python tools/content_check.py --check --langs fr,en                  # expect: OK: content looks good (fr, en)
"$GODOT" --path game                                                  # play in a window
```

There is now a Web export preset, but it needs Godot's web export templates first. Install them in Editor → Manage Export Templates (a lead step, Task 2). Then:

```bash
"$GODOT" --headless --path game --export-release "Web" ../builds/web/index.html
python -m http.server 8000 --directory builds/web
```

## What changed since Beta-0.1

| Area | Beta-0.1 | Beta-0.2 | Spec |
|---|---|---|---|
| Dice the AI asks for | Only showed "roll requested" | The game rolls d20 + skill at once and shows `Stealth: d20 17 +5 = 22 (DC 13) - Success`. The result goes to the AI under `LAST ROLL` in the next prompt | SPEC-core `apply_commands` |
| One bad part in a reply | The whole turn was refused | Only the bad command or change is dropped (noted in the debug log); the rest applies | SPEC-dm |
| `"add_items": null` | Script error; all of that reply's changes were lost | Noted; the rest applies | SPEC-dm |
| Reply limits | 5 items accepted; `dc` 13.5 accepted; emote by "dragon" accepted; unknown keys silent; despawn of any id | At most 3 items; whole-number `dc`; `who` must be `hero` or a known NPC (`oda`); unknown keys noted; despawn needs a known creature | SPEC-dm |
| State | No weather, creatures or last roll, so the wolf vanished after a load | State v1 has `weather`, `creatures` (max 6) and `last_roll`. Loading rebuilds the wolves and the weather. Beta-0.1 saves still load | SPEC-core |
| Quests | A stage could go back | Never goes back; a finished quest stays finished | SPEC-core |
| Effect tags | No limits; nested or unclosed tags were applied | At most 4 AI tags of up to 30 characters; nested or unclosed tags show as text; at most 6 animated words per entry; poison, whisper and holy use their still colour | SPEC-narration |
| Story so far | Always empty | The last 3 narrations (600 characters each), kept in the save | SPEC-dm (M1) |
| Skills the AI may roll | Only the hero's 3 | All 8 (untrained ones use the ability modifier) | SPEC-core |
| Language | The system language, otherwise French | Asked at first launch, remembered on the device; the FR/EN button still switches | Team answer Q2 |
| Walking | 4 directions | 8 directions. Missing diagonals fall back to the left/right walk, and left can mirror right | Team answer Q12, SPEC-world |
| Export | macOS, Windows | Same, plus Web (no threads, so plain `python -m http.server` works) | SPEC-release |
| DM rules (`dm-rules.md`) | — | New lines: the `LAST ROLL` rule, effect tags, limits | Rerun S1/S8 (Checkpoint 2) |

## Team answers: the answered half

| # | Answer | In Beta-0.2 |
|---|---|---|
| 2 | C: both languages, chosen at the start | First-launch picker + FR/EN button |
| 3 | Magic + a light steampunk touch | Writing tone only; the current lore (brass, mills) fits |
| 4 | The lead decides | Click to move (kept from Beta-0.1) |
| 5 | Important places by hand; details generated and stored | The 3 places are hand-built. Generated places come in M3 |
| 6 | A: turn-based with dice, + animation | Fights come in M3. The dice are ready: the game rolls them |
| 7 | B: the AI narrates, the game owns the rules and dice | The game rolls, checks every reply and clamps every number |
| 9, 11 | Pixel art, top-down | 32 × 32 top-down placeholders |
| 12 | B: 8 directions | Done, with fallbacks for 4-direction art |
| 14 | A: free placeholder art first | Alban's generated CC0 placeholders (`game/content/art/CREDITS.md`) |
| 18 | Alban is on GitHub | This branch combines his work with `main` |

## Still open: what the beta uses meanwhile

| # | Question | Default in Beta-0.2 |
|---|---|---|
| 1 | Platform | Web build (the M1 plan); the desktop presets are kept |
| 8 | Which words animate | burn, freeze, shock move; poison, whisper, holy use a still colour |
| 10 | Tile size | 32 px (`TILE` in `world.gd` and `movement_click.gd`) |
| 13 | Artist's software | No effect yet |
| 15–17 | Writer's format, priorities, key scenes | Markdown in `game/content/writing/fr|en/`; the AI improvises from the lore |
| 19–23 | Time, meetings, tools, deadline, release | Nothing in code |
| Q-4, Q-5 | Fixed hero? What happens at 0 HP? | Kael is fixed; HP stops at 0 with no game over |
| Q-7 | How Alban's work reaches `main` | This branch is a proposal: the lead and Alban decide |

## Not yet aligned with the spec

These are the next steps if the team keeps this branch as its base:
- **Folders:** the code is in `game/ai/`, `game/core/`… but the spec says `game/src/<module>/`.
- **Content formats** (an "ask first" item, because teammates use these files):
  - `i18n/strings.csv` (`key,fr,en`) where the spec has `ui_text.csv` (`key,en,fr`);
  - display names in `strings.csv` instead of `name_en`/`name_fr` columns;
  - `writing/fr|en/` instead of `places/`, `npcs/` and `lore/`;
  - no `intro-*.md`.
- **Test runner:** `tests/run_tests.gd` with a fixed list, where the spec command uses `run_all.gd`. Also, a script error inside a test can still end with `PASS`, so check the output for `SCRIPT ERROR`.
- **Missing for the M1 gate:**
  - own-key mode (Task 17);
  - the web spike measurements (Task 2);
  - the diagnostics scene, version label and pre-build checks (Task 24);
  - S1/S8 rerun 3 times each with the new DM rules;
  - all 8 Haiku replies as fixtures (only S1, S6, S8 are there).
- **Alban's reports** `docs/m1-ac.md` and `docs/m1-ai-tests.md` use Beta-0.1's own criteria AC1–AC13, not the 9 criteria in `SPEC.md`.

## Where the beta stands on the 26 M1 tasks

Legend: ✅ there, 🟡 partly there, ⬜ not started.

| Status | Tasks |
|---|---|
| ✅ | 3 state and dice · 9 tagging · 14 main screen · 15 story panel · 18 EN/FR · 19 walk grid · 21 hero (8 directions) · 22 world in the main screen · 23 scene director |
| 🟡 | 1 skeleton (other runner name) · 2 web spike (preset only) · 4 rules and commands (no French clock text) · 5–8 content (other formats; DM-rule fixes are in) · 10 reply checks (3 of 8 fixtures) · 11 prompt · 12 copy-paste (no fake connection) · 13 turn loop (lives in `main.gd`) · 16 effects (no stress test) · 20 zone (generated placeholders, not Kenney) |
| ⬜ | 17 own key · 24 release pipeline · 25 playtest · 26 engine decision |

## Checked on October 19 (lead's PC, Godot 4.7.2)

- 14 test files pass. The new tests fail on the Beta-0.1 code (checked by swapping the files back).
- The content check passes. A 300-frame headless boot shows no errors.
- One copy-paste turn was simulated in the real main scene:
  - the picker appeared and locked the Act button;
  - the hero walked to the bridge, the wolf appeared and the fog set in;
  - Stealth rolled 17 + 5 = 22 against DC 13 (success) and the line showed in the story;
  - the bad emote and `null` items were noted and the rest applied;
  - save then load brought the wolf back;
  - the next prompt carried the roll.
- **Not checked:** a turn with a real AI model, the web build (no templates), the macOS export, and Alban's computer.
