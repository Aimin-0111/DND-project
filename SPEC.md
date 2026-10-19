# Spec: Brasswake Reach

*Status: approved October 19, 2026; updated the same day with the team's questionnaire answers and "no itch.io upload during M1" (living document: update it before the code when a decision changes). Background: [docs/PLAN.md](docs/PLAN.md), team questions: [docs/QUESTIONS-EQUIPE.md](docs/QUESTIONS-EQUIPE.md), static examples: [examples/](examples/README.md).*

This file holds the **capability map** and everything the modules share. Each module has its own spec next to this file (`SPEC-<module id>.md`). The map, not the file names, is the index of what exists.

## Objective

A solo RPG with an AI Dungeon Master. About **40% of the screen is the story** (narration with animated keywords such as "burn" flickering like fire) and about **60% is an animated world** where the hero walks, creatures appear and the weather changes.

- **Players:** one person playing alone, in English or French, in a web browser first (desktop later).
- **Team:** the lead (code, rules, numbers, AI), Alban (a second programmer, on GitHub), an artist and a writer. The artist and writer never touch code or GitHub: they deliver image files and text/spreadsheet files through the school OneDrive.
- **Why this design:** the AI tells the story, but the game owns the rules, the dice and the state. The AI can only *ask* for changes from a short checked list, so it can't break the game or invent loot.
- **Team choices (questionnaire, October 19, 2026):**
  - English and French, chosen at the first launch;
  - magic fantasy with a light steampunk touch;
  - pixel art, top-down view, characters walk in 8 directions;
  - free placeholder art until the artist's files arrive;
  - turn-based fights with dice (D&D style), animated (M3);
  - important places made by hand, the rest generated once and stored (M3).

  Details and the questions still open are in [docs/PLAN.md](docs/PLAN.md#-team-answers-october-19-2026).

**Success for the first milestone (M1):** a small playable prototype, exported for the web and played on the lead's computer (no itch.io upload during M1), that proves the idea works and gives enough evidence to **keep Godot or switch to Phaser** (see [M1 success criteria](#m1-success-criteria-the-decision-gate)).

## Tech stack (proposed, not locked)

The engine and programming language are **decided at the end of M1**. Until then:

| Part | Proposed | Fallback | Locked? |
|---|---|---|---|
| Engine + language | Godot 4.7 + GDScript | TypeScript + Phaser 4 | No, decided at the M1 gate |
| Test tool | A small home-made runner until the engine decision | — | No, chosen with the engine |
| Tools / balance | Python 3.13 | — | Yes |
| Game hosting | itch.io (private page first), **after M1**. M1 builds run on `localhost` | — | Yes |
| AI key proxy | Cloudflare Workers (module `proxy`, M2) | — | Yes |
| Code | GitHub, public repo `Aimin-0111/DND-project` (the lead and Alban) | — | Yes |
| Team files | School OneDrive (`art/`, `writing/`, `data/`) | — | Yes |

The module specs describe **behaviour, data formats and contracts** (state JSON, AI reply format, CSV columns). Those stay the same whichever engine wins. Engine-specific parts below (commands, code style) are marked *provisional*.

## Capability map (approved October 19, 2026)

| Module id | What it does | Depends on | When | Spec |
|---|---|---|---|---|
| `core` | The single game state, rule checks, seeded dice, applying changes within limits. Later: Rewind snapshots, versioned saves + migrations, JSON export/import | — | M1, M2 | [SPEC-core.md](SPEC-core.md) |
| `content` | Loads and checks the team's files (CSV, Markdown, art), looks things up by id, lists the ids the AI may use. EN + FR text | — | M1 | [SPEC-content.md](SPEC-content.md) |
| `narration` | Story text: typewriter, animated keywords (AI tags + word list), old entries stop animating, reduce motion | content | M1 | [SPEC-narration.md](SPEC-narration.md) |
| `dm` | One AI turn: prompt, connection (copy-paste, own key; proxy client later), reply checks, story summary. **Owns the command list and the reply format** | core, content | M1 | [SPEC-dm.md](SPEC-dm.md) |
| `world` | Animated scene: zone, walkable cells, click-to-move hero (8 directions), camera, named places, creatures, playing checked commands. Later: hand-made important places + generated areas stored in the save | content, dm (command list only) | M1, M3 | [SPEC-world.md](SPEC-world.md) |
| `main-screen` | 40/60 layout, HUD, action box, the turn loop, settings. Later: Sheet/Pack/Quests/Codex tabs, autosave | core, content, narration, dm, world | M1, M2 | [SPEC-main-screen.md](SPEC-main-screen.md) |
| `release` | Web build run locally, with a checklist and a build log. Later: private itch.io page, desktop builds, public page | main-screen | M1, M5 | [SPEC-release.md](SPEC-release.md) |
| `proxy` | Server holding our API key, implementing the `dm` turn/summary contract | dm (contract) | M2 | *not yet* |
| `combat` | Turn-based fights with dice (D&D style), animated and synced with the text | core, world, narration, dm | M3 | *not yet* |
| `balance-tools` | Python content checker + fight simulator | content, core (formats) | M4 | *not yet* |
| `audio` | Music and sound effects (optional) | main-screen | M5 | *not yet* |

**Build order.** M1: `core` + `content` → `narration` + `dm` → `world` → `main-screen` → `release`. Then `proxy` (M2), `combat` (M3), `balance-tools` (M4), `audio` (M5).

**Contracts live with the provider.** The state shape is in `SPEC-core.md`, the content file formats in `SPEC-content.md`, the command list and AI reply format in `SPEC-dm.md`.

**Cross-cutting: English + French from the start.**
- `content` stores display text in both languages.
- `narration` uses the keyword list of the current language.
- `dm` tells the AI which language to narrate in.
- `main-screen` takes every UI string from one translation table and has the language switch.

## Commands (provisional: Godot)

Set the Godot path once per terminal (Git Bash):

```bash
GODOT="/c/2026-2027/DND project/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
```

| Task | Command |
|---|---|
| Open the editor | `"$GODOT" --path game -e` |
| Run the game | `"$GODOT" --path game` |
| Run all automated tests | `"$GODOT" --headless --path game --script res://tests/run_all.gd` *(runner depends on the test tool decision)* |
| Export the web build | `"$GODOT" --headless --path game --export-release "Web" ../builds/web/index.html` |
| Play the web build (M1) | `python -m http.server 8000 --directory builds/web`, then open `http://localhost:8000` (a web build can't run from a double-clicked file) |
| Upload to itch.io (after M1) | Zip `builds/web/` and upload it on the itch.io dashboard; later `butler push builds/web <itch-user>/brasswake-reach:web` |
| Check content files (M4) | `python tools/check_content.py` *(module `balance-tools`)* |

## Project structure

```
brasswake/
├─ SPEC.md, SPEC-*.md     this spec and the module specs
├─ CLAUDE.md              notes for AI coding sessions
├─ docs/                  plan, team questionnaire
├─ game/                  the Godot project (project.godot)
│  ├─ src/
│  │  ├─ autoload/        Game, Content, DM: wiring only, no rules
│  │  ├─ core/            module core
│  │  ├─ content/         module content (loader + checks)
│  │  ├─ narration/       module narration (+ effects/)
│  │  ├─ dm/              module dm (+ connections/)
│  │  ├─ world/           module world (+ zones/, hero/, creatures/)
│  │  └─ main_screen/     module main-screen
│  ├─ content/            team files copied from OneDrive (code never writes here)
│  │  ├─ data/            *.csv
│  │  ├─ writing/         dm-rules.md, intro-*.md, places/, npcs/, lore/
│  │  └─ art/             *.png, *.aseprite
│  └─ tests/              automated tests + fixtures (saved AI replies)
├─ examples/              static examples: reference only, never shipped
├─ tools/                 Python tools (balance-tools, M4)
├─ proxy/                 Cloudflare Worker (proxy, M2)
└─ builds/                export output (git-ignored)
```

- Module ids are kebab-case (`main-screen`); folders use snake_case (`main_screen/`).
- **`src/` is the lead's code; `content/` is the team's work.** That split is what lets the artist and writer replace their files without touching code.
- The example scripts in `examples/godot/` move into `game/src/` and are wired up, not rewritten.

## Code style (provisional: GDScript)

```gdscript
class_name Rules
extends RefCounted
## Rule checks. No nodes, no screen: testable headless.

const SKILL_ABILITY := {"Athletics": "str", "Stealth": "dex", "Perception": "wis"}


## d20 + modifier against a difficulty. The game rolls; the AI never does.
static func skill_check(state: Dictionary, skill: String, dc: int, dice: Dice) -> Dictionary:
	var modifier := skill_modifier(state["hero"], skill)
	return dice.check(modifier, dc)


static func skill_modifier(hero: Dictionary, skill: String) -> int:
	if hero["skills"].has(skill):
		return int(hero["skills"][skill])   # int(): JSON numbers load as floats
	var score := int(hero["abilities"][SKILL_ABILITY.get(skill, "wis")])
	return floori((score - 10) / 2.0)
```

- **Names:** `snake_case` for files, folders, functions and variables; `PascalCase` for `class_name`; `UPPER_CASE` for constants; signals in past tense (`finished_typing`, `arrived`).
- **Types:** give every variable and function a type (`var hp: int`, `:=`). Convert JSON numbers with `int()`.
- **Where logic goes:** rules, checks and data handling go in `RefCounted` scripts or static functions, never in nodes. Nodes display and animate.
- **Talking between scenes:** "call down, signal up". A parent calls its children; a child emits a signal and never reaches up.
- **Ids:** lowercase ASCII `snake_case` (`rust_wolf`, `old_mill`). They are the links between code, CSV, Markdown and art file names.
- **Language:** code, comments and specs in English; files for teammates (guides, templates) in French.
- **Comments:** `##` doc comment on every class and public function; say *why*, not *what*.

## Testing strategy

The test tool is **not chosen yet** (it follows the engine decision). What must be tested is decided now:

| Level | What | How | When it runs |
|---|---|---|---|
| Logic tests | `core`, `content` checks, `narration` tagging, `dm` prompt + reply checks | Automated, headless, no window | Before every commit |
| Content check | Every team file loads, ids are unique and valid, references exist | Automated (same runner) | Before every commit and every build |
| AI reply fixtures | Saved replies (the 8 Haiku replies in `examples/ai-tests/` + crafted bad replies) run through the real reply checks | Automated | Before every commit |
| Scene checks | Walking, command playback, typewriter, layout | Manual checklist in each module spec | Before each build |
| M1 playtest | The scripted play-through in [M1 success criteria](#m1-success-criteria-the-decision-gate) | Manual, on the exported web build | At the M1 gate |
| AI quality | The 8 trap scenarios, 5 runs each, with the chosen model | Semi-manual (checker + reading) | Before choosing the model (M2) |

- Every public function in `core`, the `dm` reply checks and `narration` tagging has at least one test, including a bad-input case.
- No coverage percentage until the tool is chosen.
- A failing test is fixed or reported, never deleted or skipped to get a green run.

## Boundaries

**Always**
- Run the logic tests and the content check before each commit.
- Send every AI reply through the `dm` reply checks before it touches the state, the story or the world.
- Keep copy-paste mode working, whatever other AI connections exist.
- Let the game roll every die; the AI only asks for rolls.
- Take every UI string from the translation table (EN + FR).
- Link files by ids, and keep team files editable without code.

**Ask first**
- Adding an add-on, library or other dependency (including a test tool).
- Changing the state shape, the AI reply format or the command list.
- Changing content file formats (columns, folder names, file name rules): the artist and writer rely on them.
- Installing software (Node.js, butler…), creating accounts, or changing itch.io page visibility.
- Committing or pushing to GitHub.
- Anything that reverses a decision in the tech stack table.

**Never**
- Commit an API key, token or other secret. **The repo is public.**
- Put the Git repo inside OneDrive.
- Load executable resource files (`.tres`, `.res`, scripts) from a save the player imports. Saves are JSON only.
- Show AI text as markup other than the six effect tags (no links, images, font changes).
- Edit a teammate's file in `game/content/` without telling them: the next copy from OneDrive would undo it. Fix it at the source.
- Delete or skip a failing test to get a green run.

## M1 success criteria (the decision gate)

M1 is done when **all** of these are true on the exported web build, played from `localhost`:

1. **Screen:** the world fills about 60% and the story panel about 40%, at 1280×720 and 1920×1080, in Chrome, Edge and Firefox.
2. **Walking:** clicking on the map walks the hero there around obstacles, facing the way it moves in 8 directions (with placeholder art, diagonals may use the left/right walk); the camera follows.
3. **One AI turn, both connections:** typing an action and pressing Act produces a narrated turn in **copy-paste mode** and in **own-key mode**.
4. **Animated words:** the narration types out; *burn*, *freeze* and *shock* animate on words tagged by the AI **and** on words from the word list, in English and in French.
5. **The AI changes the scene:** a reply with `spawn` makes the creature fade in near the named place; a reply with `move_to` walks the hero there.
6. **Bad replies are harmless:** the fixture replies with unknown ids, too much gold, broken JSON or no `<<STATE>>` change nothing they shouldn't (logic tests prove it).
7. **Speed:** during typing + effects + walking, at least 55 fps on the lead's PC and 30 fps on a school laptop (web build). If no school laptop can run the local build, Chrome's 4× CPU slowdown on the lead's PC stands in, noted as such.
8. **Size:** the web download is measured and recorded; target 25 MB or less.
9. **Tests:** all logic tests and the content check pass.

**Engine decision (recorded in `docs/PLAN.md` at the gate).** Keep Godot unless one of these shows up:
- a blocker in the web build (clipboard, HTTPS calls to the API, text effects, start time over 15 s with Chrome's "Fast 4G" throttling);
- M1 took more than twice the planned 3 weeks because of the engine, not the scope;
- the artist's or writer's files can't be loaded without them changing their tools.

## Open questions

| # | Question | Who answers | Blocks |
|---|---|---|---|
| Q-1 | Team questionnaire, still open: platforms/phones (Q1), which words animate (Q8), tile size (Q10), art software (Q13), writing format and key scenes (Q15–Q17), OneDrive access and organisation (Q18–Q23). Answered on October 19: see [docs/PLAN.md](docs/PLAN.md#-team-answers-october-19-2026) | Team | `world` tile size, `content` writing format, `narration` effect list |
| Q-2 | Which test tool (decided with the engine) | Lead | Test runner command |
| Q-3 | Does the writer write Codex pages in both languages, or French only (the AI narrates in either)? | Writer + lead | `content` Codex tab (M2) |
| Q-4 | Fixed starting hero (Kael the ranger) or character creation? | Team | `core` new game (M2) |
| Q-5 | What happens at 0 HP: game over, knocked out, or Rewind offer? | Team | `core` rules (M2) |
| Q-6 | itch.io account name for the page and `butler`, and when the first upload happens (not in M1) | Lead | `release` after M1 |
| Q-7 | How Alban works in the repo: branches and pull requests the lead reviews, or direct pushes to `main`? Which tasks does Alban take? | Lead + Alban | Parallel work in the M1 plan |
