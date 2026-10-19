# Brasswake Reach — Project plan

*Last updated: October 19, 2026. Spec: [SPEC.md](../SPEC.md). M1 plan: [tasks/plan.md](../tasks/plan.md). Team questions: [QUESTIONS-EQUIPE.md](QUESTIONS-EQUIPE.md).*

## 🎯 In one sentence
A pixel-art RPG with an AI Dungeon Master: **40% of the screen is the story text** (with animated keywords) and **60% is an animated world** where the hero explores.

## ✅ Main decisions

| Topic | Choice | Why |
|---|---|---|
| Game engine | **Godot 4** (proposed, decided at the end of M1) | Its language (GDScript) is close to Python. Maps, animation and text effects are built in |
| Backup plan | TypeScript + Phaser 4 (web) | If Godot fails the prototype test |
| Tests | A small home-made test runner until the engine decision | Nothing to install before the engine is chosen |
| Game hosting | **itch.io**, after M1 | Free, made for indie games, can stay private while testing. During M1, builds are played on the lead's computer (no upload yet) |
| AI key safety | **Cloudflare Workers** | Free (100,000 requests/day), keeps the API key secret |
| Code storage | **Public GitHub repo** (the lead and Alban) | Permanent, safe history of every change. Public, so never commit a key |
| Team file sharing | **School OneDrive** | Everyone already has it |

## ⚠️ Four rules to remember
1. **Never put the Git project inside OneDrive.** OneDrive sync can corrupt Git.
2. **School OneDrive files disappear when accounts close** (e.g. after graduation). GitHub is the permanent copy.
3. **The AI never controls the game directly.** It can only send commands from a short, checked list (move, spawn, weather…).
4. **The repo is public.** Never commit an API key or any other secret.

## 📝 Team answers (October 19, 2026)

| Question | Answer | What it changes |
|---|---|---|
| 2. Language | C: both, chosen at the start | English + French from the start; the first-launch language picker can't be cut from M1 |
| 3. Mood | Magic, with a minimum of steampunk | The DM rules' setting line (M1 Task 8); the writer's lore |
| 4. Movement | Left to the lead | Click-to-move, as in the spec |
| 5. World | Made by hand: important places by hand, details and other areas generated, then stored | M3: generated parts are saved so they stay the same |
| 6. Combat | A + animation: turn-based with dice, animated | M3 combat |
| 7. AI's role | B: the AI narrates; the game owns the rules and dice | Already the design |
| 8. Animated words | "We'll see" | M1 keeps *burn*, *freeze*, *shock*; the full list later |
| 9. Art style | A: pixel art | — |
| 11. View | A: top-down | — |
| 12. Directions | B: 8 directions | Twice the walking drawings: left side mirrored from the right; diagonals fall back to left/right until drawn |
| 14. Placeholder images | A: yes | Free Kenney (CC0) art in M1 |
| 18. OneDrive | "Another programmer, Alban, is on GitHub" | Team of 4. How Alban works in the repo is open (SPEC.md Q-7) |

**Still to answer:** 1 (platforms, phones), 8, 10 (tile size), 13 (art software), 15–17 (writing), 18 (OneDrive access), 19–23 (organisation).

## 🧩 Features and difficulty

🟢 Easy · 🟡 Medium · 🔴 Hard

| Feature | Difficulty | Watch out for |
|---|---|---|
| 40/60 split screen | 🟢 | Small screens |
| Story text with typewriter effect | 🟢 | — |
| Animated keywords ("burn" 🔥, "freeze" ❄️…) | 🟢🟡 | Animate only recent lines so the game stays fast |
| Hero walks in a tile world, camera follows | 🟡 | Needs lots of art |
| Open world | 🔴 | Use **zones** linked by travel, not an endless map. Important places by hand, the rest generated once and stored |
| AI moves things in the scene | 🔴 | Short list of allowed commands, checked by code |
| Dice, HP, inventory, quests | 🟡 | Reuse ideas from the old prototype |
| Turn-based combat with animations | 🟡🔴 | Keeping rules, text and animation in sync |
| NPCs and creatures that move around | 🟡 | — |
| Day/night and weather | 🟡 | Speed on the web |
| **Amount of art for one artist** | 🔴 | Small pixel art, 8 directions (left side mirrored), free placeholder art first |
| AI waiting time and cost | 🟡🔴 | Hide waiting with animation; rolling story summary |
| Save files that keep working after updates | 🟡 | Version number + conversion for old saves |
| Music and sounds | 🟢🟡 | Optional |

## 👥 Who does what

| Person | Works on | Delivers as | Tools |
|---|---|---|---|
| **Lead (you)** | Code, rules, numbers, AI | Godot project on GitHub | Godot, VS Code, Python, Git |
| **Alban** | Code (second programmer); tasks to agree | Commits on GitHub | Godot, Git |
| **Artist** | Tiles, characters, creatures, icons | PNG or Aseprite files in OneDrive `art/` | Aseprite (~$20) or LibreSprite (free) |
| **Writer** | Lore, NPCs, quests, DM style | Text/Markdown or Word in OneDrive `writing/` | Any text editor, Word |

How it flows: **teammates → OneDrive → lead copies into the Git repo → new web build → playtests on the lead's computer for now (a private itch.io link later).**

## 🗓️ Milestones

| Step | When | Goal |
|---|---|---|
| **M0 Setup** | Week 1 | ✅ GitHub repo, spec and M1 plan (Oct 19). To do: Godot project, OneDrive share, guides for teammates |
| **M1 Prototype (decision)** | Weeks 2–4 | One small zone, a hero who walks, 3 animated keywords, one AI turn that spawns something, as a web build played locally. **Then: keep Godot or switch to Phaser** |
| **M2 Core systems** | Then | Rules, dice, sheet, inventory, quests, saves, copy-paste + API modes |
| **M3 World** | Then | Zones and travel, NPCs, day/night, weather, combat |
| **M4 Content** | Then | Art and writing at full speed, balance tools in Python |
| **M5 Release** | Then | Sound, settings, tutorial, public itch.io page, desktop version |

## 💻 Lead's computer
- ✅ Already installed: Git, VS Code, Python 3.13, Godot 4.7.2
- ➕ To add: Godot's web export templates (M1 Task 2), VS Code "godot-tools" extension, GitHub Desktop (optional)
- ➕ Later: Node.js (for the Cloudflare Worker), butler (itch.io upload tool)

## 📁 Project folders (outside OneDrive)
```
brasswake/
├─ SPEC.md, SPEC-*.md  the spec (full layout in SPEC.md)
├─ tasks/              M1 plan and task list
├─ game/               Godot project
│  └─ content/         art, writing, data copied from OneDrive
├─ examples/           reference examples, never shipped
├─ proxy/              AI key proxy (later)
├─ tools/              Python balance tools
└─ docs/               this plan, team questionnaire, build log
```
