# Brasswake Reach

A solo RPG with an AI Dungeon Master that narrates each turn. About 40% of the screen is the story (narration with animated keywords, e.g. "burn" flickers like fire) and about 60% is an animated world (RPG + open world).

## Where things are

- **Spec:** `SPEC.md` (capability map, shared rules, boundaries, M1 success criteria) and one `SPEC-<module id>.md` per module. When a decision changes, update the spec before the code.
- **M1 plan:** `tasks/plan.md` (decisions, risks, cut list) and `tasks/todo.md` (26 tasks with acceptance criteria). Work one task at a time, in order.
- **Project plan and team answers:** `docs/PLAN.md`. Team questionnaire (French): `docs/QUESTIONS-EQUIPE.md`.
- **Examples:** `examples/` (mockups, Godot example scripts, the Haiku DM test). Reference only, never shipped: the scripts move into `game/src/` during the tasks.

## Current status (Oct 19, 2026)

- The spec and the M1 plan are approved. No game code yet: the next step is Task 1 (Godot project skeleton + test runner).
- M1 builds are web exports played on the lead's computer from `localhost`. No itch.io upload for now.
- Repo: public, https://github.com/Aimin-0111/DND-project, branch `main`.

## Team

- 4 people: the lead (code, numbers/balance, AI), Alban (a second programmer, on GitHub), an artist and a writer. The artist and writer don't use GitHub or code.
- Art and writing are plain files the artist and writer edit without code (images, Markdown/text, spreadsheets). They share them through the school OneDrive, and the lead copies them into `game/content/`. Never put the Git repo inside OneDrive.
- The lead knows Python, C++, HTML and CSS. Prefer tools close to those.
- `..\dnd-main-alpha` is an empty Godot 4.7 project.

## Decisions

- **Engine:** Godot 4.7 + GDScript (proposed), kept or replaced by TypeScript + Phaser 4 at the M1 gate. Godot console exe: `C:\2026-2027\DND project\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.
- **Tests:** a small home-made runner (`game/tests/run_all.gd`) until the engine decision.
- **Hosting:** itch.io after M1 (private page first). Cloudflare Workers as the AI key proxy (M2). Not Netlify.
- **Team answers (Oct 19):**
  - English + French, chosen at the first launch;
  - magic with a light steampunk touch;
  - pixel art, top-down view, 8 walking directions; free placeholder art first;
  - turn-based dice fights with animation;
  - important places made by hand, the rest generated and stored;
  - the AI narrates, the game owns the rules and dice.

  Details are in `docs/PLAN.md`.

## Old version (reference only)

- The first prototype was a plain-JS page on Netlify (https://brasswake-49a500.netlify.app). Its panels: Roll d20, Act, Dice tray, Sheet, Pack, Chart, Codex, Quests, Lore, Story, Ledger. It had HP, gold, Rewind and "Import save file".
- Its copy-paste loop: the game builds a full prompt, the player pastes it into a Claude chat and pastes the reply back.
- Source: `C:\Users\aimin\Downloads\brasswake-reach.zip` (about 2,550 lines, no dependencies). Use it as a reference (rules, DM prompt, save migration, API adapters), not as a base.
  - The DM protocol, kept in the new spec: narration, then a `<<STATE>>` line, then one JSON object. The game owns the state and rolls every die.
  - Why it's being replaced: the art was drawn in code and the game text lived inside JS, so the artist and writer couldn't edit their own work.
- Ideas from the earlier web architecture that the spec keeps: a pure, deterministic game core with a seeded RNG; one versioned state with migrations; an action log for Rewind; one AI connection interface whose replies are always checked.

## AI cost study (Oct 16, 2026)

- Prompt parts: rules, character sheet, pack, quests, lore/Codex, story summary, and optionally the full transcript.
- Model choice changes the cost per turn by about 100x.
- A full transcript gets far more expensive than a rolling story summary as a campaign grows. Prefer the summary.
- Prompt caching of the stable parts of the prompt saves a lot.
- Refreshing the story summary on Haiku 5.5 is cheap whichever main model is used.
- **Suggested setup:** Sonnet 5.5, story summary + full Codex, prompt caching on, effort "low", summary refresh on Haiku 5.5.
- Non-Claude models also compared: DeepSeek V4-Pro and GPT-6 Luna. No creative-writing ranking was found for either.
- **Next step:** a play test before choosing a model.

## Guidelines for working on this codebase

- Follow the boundaries in `SPEC.md` (Always / Ask first / Never). Ask before committing or pushing.
- Never commit an API key or other secret: **the repo is public**. Our key will live in the proxy (M2). In own-key mode, the player's key stays in the settings file on their device: never in a save, a log or a build.
- Don't break existing save files: add a migration whenever the state shape changes.
- Keep copy-paste mode working alongside any API mode.
- Send every AI reply through the `dm` reply checks before it touches the state, the story or the world.
- Take every UI string from the translation table (EN + FR).
