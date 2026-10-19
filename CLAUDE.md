# Brasswake Reach

A solo tabletop RPG played in the browser, with an AI Dungeon Master that narrates each turn.

- Live site: https://brasswake-49a500.netlify.app (static site on Netlify)
- Panels: Roll d20, Act, Dice tray, Sheet, Pack, Chart, Codex, Quests, Lore, Story, Ledger
- Game state shown in the UI: HP, gold, a Rewind button, "Import save file"
- Current AI loop (copy-paste mode): each turn the game builds a full prompt with everything the AI needs. The player pastes it into a Claude chat, then pastes the reply back into the game ("The AI's reply", "Continue the story"). There is also a "Test connection" button.

## Current status (Oct 17, 2026)

- This folder has **no source code yet**. The team plans to **start over** with a fresh codebase.
- The old version's source is in `C:\Users\aimin\Downloads\brasswake-reach.zip`: about 2,550 lines of plain JS, no dependencies. `build.sh` joins the files into one HTML file. Use it as a reference (rules, DM prompt, save migration, API adapters), not as a base.
  - The DM protocol: narration, then a `<<STATE>>` line, then one JSON object. The page owns state and rolls every die.
  - Old weak points for teamwork: all art is drawn in code (`sprites.js`, `creatures.js`, `icons.js`, `map.js` canvas), and the game text lives inside JS (`data.js`), so the artist and writer can't edit their own work.

## Team

- 3 people: the lead (code, numbers/balance), an artist, and a writer. The artist and writer don't use GitHub or code.
- Keep art and writing in plain files they can edit without code (image files, Markdown/text, spreadsheets), loaded by the game.
- The lead knows Python, C++, HTML and CSS. Prefer tools close to those.
- `..\dnd-main-alpha` is an empty Godot 4.7 project.

## Current direction (Oct 17, 2026) — see `docs/PLAN.md`

The vision grew: about 40% narration text with animated keywords (e.g. "burn" flickers like fire) and about 60% animated scene (RPG + open world). This **replaces** the earlier "stay on the web / Netlify" decision.

- **Proposed engine: Godot 4 (GDScript)**, confirmed or rejected by the M1 prototype. Fallback: TypeScript + Phaser 4.
- **Hosting:** itch.io for the game, Cloudflare Workers as the AI key proxy. Not Netlify.
- **Sharing:** code in a private GitHub repo (lead only). Art and writing go through the school OneDrive. Never put the Git repo inside OneDrive.
- Open team questions are in `docs/QUESTIONS-EQUIPE.md` (French). Update the plan when the answers come in.

## Earlier web architecture (superseded; still useful ideas: versioned saves, action log, AI adapter, seeded RNG)

- **Language and build:** TypeScript + Vite, still deployed as a static site.
- **Pure game core:** a module with no DOM access that holds state, rules, dice and prompt building. It is deterministic (same input, same output) and uses a seeded RNG so dice rolls are reproducible and testable.
- **State:** one serializable state object with a `version` field and migration functions, so old save files keep loading.
- **Action log + snapshots:** record every player action and derive state from the log. This powers Rewind, debugging and replays.
- **AI adapter:** one interface, `generateTurn(context) -> reply`, with swappable implementations:
  - copy-paste mode (free default, always kept working as a fallback)
  - direct API mode through a Netlify Function that holds the API key
  - The adapter validates and parses every reply. AI output is untrusted.
- **UI layer:** only renders state and dispatches actions. Svelte is the suggested pick; Preact or Solid are alternatives.
- **Persistence:** IndexedDB for autosave (localStorage is too small for long campaigns), plus JSON export/import of save files.
- **Delivery:** optionally a PWA with a service worker for offline play.

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

- Never put an API key in client-side code. Use the Netlify Function, or let each player paste their own key and store it locally.
- Don't break existing save files: add a migration whenever the state shape changes.
- Keep copy-paste mode working alongside any API mode.
- Avoid canvas, WebGL or a game engine unless a specific feature needs it (e.g. animated dice or a map), and then use it only for that component.
