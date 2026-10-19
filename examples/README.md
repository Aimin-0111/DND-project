# Brasswake Reach — static examples

Examples of the interface and the code structure, based on [docs/PLAN.md](../docs/PLAN.md). **Nothing here is a playable game yet.** The aim is to show how each feature is organised and compare options before the team decides.

- Engine in the examples: **Godot 4 (GDScript)**, the proposed choice.
- Hosting: itch.io for the game, Cloudflare Workers for the AI proxy.
- Open the mockups: [interface/mockups.html](interface/mockups.html) (double-click; opens in any browser).

## What's where

| Folder | Contents | For |
|---|---|---|
| [interface/mockups.html](interface/mockups.html) | Static screens: 3 layouts, keyword effects, panels, one AI turn, movement, AI modes | Everyone |
| [godot/scene_tree.md](godot/scene_tree.md) | How the screen is built from Godot nodes + data flow of one turn | Lead |
| [godot/core/](godot/core/) | `dice.gd` seeded dice · `game_state.gd` the state Dictionary · `save_system.gd` saves + migrations | Lead |
| [godot/narration/](godot/narration/) | `keyword_tagger.gd` · `narration_panel.gd` typewriter · `effects/` burn, freeze, shock | Lead |
| [godot/ai/](godot/ai/) | `prompt_builder.gd` · 3 adapters (copy-paste, proxy, own key) · `dm_reply_parser.gd` checks the AI | Lead |
| [godot/world/](godot/world/) | 3 movement options · `walk_grid.gd` path-finding · `scene_director.gd` runs AI commands | Lead |
| [godot/content/](godot/content/) | `content_loader.gd` reads CSV + Markdown | Lead |
| [proxy/worker.ts](proxy/worker.ts) | Cloudflare Worker that hides the API key (Sonnet 5.5 turns, Haiku 5.5 summaries) | Lead |
| [content/data/](content/data/) | `monsters.csv`, `items.csv`, `keywords.csv` | Lead + writer |
| [content/writing/](content/writing/) | `pnj-modele.md`, `lieu-modele.md` (French templates), `dm-rules.md` | Writer |
| [content/art/GUIDE-ARTISTE.md](content/art/GUIDE-ARTISTE.md) | Formats, file names, animation sheets (French) | Artist |
| [tools/balance_sim.py](tools/balance_sim.py) | Checks the CSV files; simulates fights | Lead |
| [ai-tests/](ai-tests/) | Hallucination test: 8 trap scenarios, Haiku's replies, the checker, and [RESULTS.md](ai-tests/RESULTS.md) | Lead |

## Features with several options

| Feature | Options | Suggested | Where |
|---|---|---|---|
| Screen layout | A side by side · B stacked · C full scene + floating panel | A on computers, B on phones | mockups §1, `scene_tree.md` |
| Which words get effects | A AI tags · B word list · C both | C | mockups §2, `keyword_tagger.gd` |
| Sheet / Pack / Quests | A tabs in story panel · B drawer · C pause menu | A | mockups §3 |
| AI → game format | A text + `<<STATE>>` JSON · B structured outputs (API only) | A (copy-paste mode needs it) | `dm_reply_parser.gd` |
| When AI commands play | A after the text · B markers inside the text | A first | `scene_director.gd` |
| Hero movement | A free (keys) · B click to move · C grid steps | B to start | mockups §5, `world/` |
| AI connection | copy-paste · our proxy · player's own key | all three, behind one interface | mockups §6, `ai/` |
| Game state storage | A Dictionary + JSON · B Godot Resources | A (B is unsafe for imported saves) | `game_state.gd` |
| Loading content | A read files at start · B Python check/convert first | both | `content_loader.gd`, `balance_sim.py` |

## How these examples were checked

- **GDScript:** every file was parse-checked with Godot 4.7.2 (headless), and a smoke test ran the core logic: seeded dice, the three keyword options (including French accents), the reply checker (bad commands dropped, gold clamped), saves and a v1→v3 migration, prompt order, and CSV/Markdown loading. All 26 checks passed. Scripts that need a real scene (movement, scene director, the story panel) only parse; they haven't been run.
- **Python:** `python tools/balance_sim.py --check` and the fight simulation run.
- **Not checked:** `proxy/worker.ts` (Node.js isn't installed yet) and anything that calls the real Claude API.

## Try the Python tool

```bash
python examples/tools/balance_sim.py --check
```

```bash
python examples/tools/balance_sim.py --fights 5000
```
