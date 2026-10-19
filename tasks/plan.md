# Implementation Plan: Brasswake Reach, milestone M1

*Written October 19, 2026 from the approved [SPEC.md](../SPEC.md); approved the same day with the lead's answers below. Task details: [todo.md](todo.md).*

## Overview

M1 builds the seven M1 modules (`core`, `content`, `narration`, `dm`, `world`, `main-screen`, `release`) into a small prototype, exported for the web and played on the lead's computer (no itch.io upload during M1):
- one zone where the hero walks;
- animated story text in English and French;
- one AI turn, in copy-paste and own-key modes, that can walk the hero and spawn a creature.

M1 ends with the **engine decision**: keep Godot or switch to Phaser.

The 26 tasks come in 6 phases with a checkpoint after each. The riskiest things for the engine decision (the web build, the clipboard, calling the API from a browser, text-effect speed) are tested **first**, in a small web spike.

## Architecture decisions (for this plan)

| Decision | Why |
|---|---|
| **Web spike first** (Task 2) | The M1 gate fails on web blockers. Finding one in week 1 costs a day; finding it in week 3 costs the milestone |
| **No itch.io upload in M1** (lead, Oct 19) | Builds run from `localhost` (`python -m http.server`). The checks that only a hosted page can answer (copy-paste inside the itch.io frame, school Wi-Fi start time) wait for the first upload |
| **The spike stays as a diagnostics scene** (lead, Oct 19) | It checks a new computer or browser in a minute. Task 24 hides it behind 5 clicks on the version label |
| **Interim test runner, no add-on** (Task 1; lead OK Oct 19) | The test tool is undecided (Q-2). A small home-made runner runs plain `test_*` functions, so moving to GUT or gdUnit4 later is mechanical |
| **DM-rule fixes in Task 8** (lead, Oct 19) | The two lines from the Haiku test (S1 invented place, S8 missing `move_to`) go into `dm-rules.md`; S1 and S8 are rerun at Checkpoint 2 |
| **8-direction walking with fallbacks** (team answer Q12) | Diagonals fall back to the left/right walk and left falls back to a mirrored right, so 4-direction placeholder art works until the artist's sheets arrive |
| **Text-only turn before the world** (Checkpoint 2) | First vertical slice: action → AI → checked reply → story, end to end in copy-paste mode. The world joins it in Phase 4 |
| **World built alongside** (Tasks 19–21) | It needs only `content` and the path logic, so it can run in parallel with Phases 2–3 and join at Task 22 |
| **Examples are moved, not rewritten** | Each example script moves into `game/src/<module>/` and is brought up to the spec (state v1, extra checks) in the same task |
| **Turn loop in a plain script** (`turn_loop.gd`) | It talks to the story and the world through small interfaces, so it can be tested headless with stand-ins |
| **M1 "story so far" kept in memory** | The intro + last 3 narrations live in the DM autoload (M1 has no saves). M2 replaces this with the log and the rolling summary |
| **Placeholder art in `game/content/art/placeholder/`** | Free CC0 art with its licence note; the artist's files replace it one by one |
| **Build info written before export** | The web build can't run `git`, so the pre-upload script writes the build number and git hash into a file the game reads |

## Things only the lead can do

These are account, install or key actions. The agent prepares everything else and asks before each one.

| When | Action |
|---|---|
| Task 2 | Install Godot's **web export templates** (Editor → Manage Export Templates) |
| Tasks 2, 17 | Type your own API key into the game at runtime (never into a file) |
| Task 20 | Approve the download of a free CC0 placeholder art pack (Kenney) |
| Tasks 16, 25 | Measure on a school laptop (or use Chrome's 4× CPU slowdown as a stand-in) |
| Before Alban pushes | Add Alban as a collaborator on the GitHub repo, and agree on how Alban works (Q-7) |
| Every task | Approve the commit (and push) |

## Dependency graph

```
Task 1 project + test runner
 ├─ Task 2 web spike ─────────────────────────────────────────────┐
 ├─ core:    3 state/dice → 4 rules/commands ─┐                   │
 ├─ content: 5 CSV → 6 data files             │                   │
 │           5 CSV → 7 Markdown/db/art → 8 writing files          │
 │                                            ▼                   │
 │   narration 9 tagging ◄── 7     dm 10 reply checks ◄── 4, 7    │
 │                                    11 prompt ◄── 4, 7          │
 │                                    12 turn + copy-paste ◄── 10, 11
 │                     13 autoloads + turn loop ◄── 9, 12          │
 │                     14 main screen v0 (text-only) ◄── 13        │
 │        15 story panel ◄── 14 → 16 effects ◄── 2 (burn), 15      │
 │        17 own key + settings ◄── 14 → 18 EN/FR ◄── 9, 17        │
 └─ world: 19 walk grid → 20 zone ◄── 7 → 21 hero                  │
                     22 world in main screen ◄── 18, 21            │
                     23 scene director ◄── 22                      │
                     24 release pipeline ◄── 23 ◄──────────────────┘
                     25 M1 playtest ◄── 24 → 26 engine decision
```

## Task list

### Phase 0: Setup and web spike
- [ ] Task 1: Godot project skeleton and test runner
- [ ] Task 2: Web spike, played locally (clipboard, API call, one animated word, size and fps)

**Checkpoint 0:** the runner works; the spike runs as a local web build in Chrome, Edge and Firefox, or a blocker is reported to the lead **before anything else is built**.

### Phase 1: Foundations (`core`, `content`)
- [ ] Task 3: Core state v1, dice, applying changes
- [ ] Task 4: Core rules, clock and applying commands
- [ ] Task 5: CSV reader and table checks
- [ ] Task 6: M1 data files
- [ ] Task 7: Markdown reader, content database, art lookup
- [ ] Task 8: M1 writing files

**Checkpoint 1:** all tests pass; the content check finds 0 errors in the real files; the writer gets the French text to review.

### Phase 2: First playable text turn (`narration`, `dm`, `main-screen`)
- [ ] Task 9: Keyword tagging
- [ ] Task 10: DM reply checks and fixtures
- [ ] Task 11: Prompt builder
- [ ] Task 12: DM turn, copy-paste and fake connections
- [ ] Task 13: Autoloads and the turn loop
- [ ] Task 14: Main screen v0 (text only)

**Checkpoint 2:** a full text-only turn in copy-paste mode works in the local web build (build 1); S1 and S8 rerun with the fixed DM rules. Review with the lead.

### Phase 3: Story feel, own key, two languages
- [ ] Task 15: Story panel (typewriter, skip, still entries)
- [ ] Task 16: Burn, freeze and shock effects + stress test
- [ ] Task 17: Own-key connection and settings
- [ ] Task 18: English and French

**Checkpoint 3:** animated story in both languages, both AI modes, in the local web build (build 2).

### Phase 4: World (`world`)
- [ ] Task 19: Walk grid (path logic)
- [ ] Task 20: Placeholder art and the Mill Road zone
- [ ] Task 21: Hero click-to-move
- [ ] Task 22: World in the main screen
- [ ] Task 23: Scene director (`move_to`, `spawn`, `despawn`)

**Checkpoint 4:** the whole M1 loop works in the local web build (build 3): walk, act, animated story, the AI walks the hero and spawns a wolf. First team playtest, on the lead's computer.

### Phase 5: Release and the gate (`release`)
- [ ] Task 24: Release pipeline (checks, version label, build log)
- [ ] Task 25: M1 playtest and measurements
- [ ] Task 26: Engine and test-tool decision

**Checkpoint M1 gate:** all 9 M1 success criteria in SPEC.md are ticked or explained; the decision is written in `docs/PLAN.md`.

## Parallel work

| Can run at the same time | Condition |
|---|---|
| Task 2 · Tasks 3–4 · Tasks 5–8 · Task 19 | All only need Task 1 |
| Tasks 9, 10, 11 | After Checkpoint 1 |
| Tasks 15–16 and Task 17 | After Task 14 |
| World track (Tasks 19–21) and Phases 2–3 | Joins at Task 22 |

Contracts are already fixed in the spec, so parallel tasks don't need to agree on anything new. Two sessions (or two programmers) never edit the same file at once; `main.tscn`/`main.gd` changes go one at a time.

**Alban (second programmer).** A self-contained track suits a second programmer: the world track (Tasks 19–21) needs only Task 1, or the content track (Tasks 5–8). Which one, and how Alban's changes reach `main`, is open question Q-7.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| The web build can't copy/paste, or can't call the API | High: fails the gate | Task 2 tests both in week 1 on the local build; copy-paste could fall back to a "select all" text box |
| The itch.io frame blocks the clipboard (untested until the first upload, after M1) | Medium | The diagnostics scene rechecks it in a minute after the first upload; same "select all" fallback |
| 8 directions double the walking art for one artist | Medium | Mirrored left rows, diagonal fallback, placeholder art first (see `GUIDE-ARTISTE.md`) |
| Two programmers change the same files | Medium | Settle Q-7 first; give Alban a separate track; scene files change one at a time |
| Text effects too slow in the browser | High | Task 2 measures one effect; Task 16 stress test; still colours for old entries |
| Godot imports CSV files as translations, so they vanish from the export | Medium | Tasks 5–6 set "Keep File"; Task 24 checks the exported build loads content |
| Teammates' CSV files saved by French Excel (`;`, not UTF-8) | Medium | Task 5 accepts `;` and explains how to re-save |
| The AI invents places or forgets `move_to` (Haiku test S1, S8) | Medium | Reply checks keep the game safe; DM-rule fixes are an open question |
| 26 tasks is a lot for ~3 weeks of student time | Medium | Checkpoints show progress; the cut list below says what to drop first |
| The tile size answer (Q10) arrives mid-M1 | Low | Placeholder art; tile size is one setting; the zone is small |
| An API key leaks into the public repo or a build | High | `.gitignore`, key only in the settings file, the secret scan in Task 24 |

## Cut list (if M1 runs late, drop in this order)

1. `despawn` playback (the state still changes).
2. Reduce motion.
3. The stress-test scene (measure fps in the real game instead).

Never cut: the reply checks, copy-paste mode, the web spike, the M1 gate measurements, the first-launch language picker (the team chose "both languages, chosen at the start", Q2).

## Definition of done (every task)

- The task's acceptance criteria are met **and checked at runtime**, not only by reading the code.
- New logic has tests that fail without it; all tests pass; the content check passes.
- No debug prints, dead code or commented-out blocks; the change stays inside the task.
- If a contract changed, the spec was updated first (with the lead's OK).
- The lead approved the commit.

## Answered (October 19, 2026)

- The interim test runner (no add-on) is fine until the engine decision.
- The spike scene stays after M1, as a hidden diagnostics scene.
- The two DM-rule fixes from the Haiku test go in during Task 8.
- No itch.io upload for now: M1 builds are played locally.

## Open questions

- Q-7: how does Alban work in the repo (branches and pull requests, or direct pushes), and which track does Alban take?
- Q-6: when does the first itch.io upload happen (M2?), and under which account?
- Q10: tile size, 16 or 32 px (placeholder art and the zone use one setting until then).
