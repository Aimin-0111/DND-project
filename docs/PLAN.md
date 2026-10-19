# Brasswake Reach — Project plan

*Last updated: October 17, 2026. Team questions: [QUESTIONS-EQUIPE.md](QUESTIONS-EQUIPE.md).*

## 🎯 In one sentence
A pixel-art RPG with an AI Dungeon Master: **40% of the screen is the story text** (with animated keywords) and **60% is an animated world** where the hero explores.

## ✅ Main decisions (proposed)

| Topic | Choice | Why |
|---|---|---|
| Game engine | **Godot 4** | Its language (GDScript) is close to Python. Maps, animation and text effects are built in |
| Backup plan | TypeScript + Phaser 4 (web) | If Godot fails the prototype test |
| Game hosting | **itch.io** | Free, made for indie games, can stay private while testing |
| AI key safety | **Cloudflare Workers** | Free (100,000 requests/day), keeps the API key secret |
| Code storage | **Private GitHub repo** (only the lead uses it) | Permanent, safe history of every change |
| Team file sharing | **School OneDrive** | Everyone already has it |

## ⚠️ Three rules to remember
1. **Never put the Git project inside OneDrive.** OneDrive sync can corrupt Git.
2. **School OneDrive files disappear when accounts close** (e.g. after graduation). GitHub is the permanent copy.
3. **The AI never controls the game directly.** It can only send commands from a short, checked list (move, spawn, weather…).

## 🧩 Features and difficulty

🟢 Easy · 🟡 Medium · 🔴 Hard

| Feature | Difficulty | Watch out for |
|---|---|---|
| 40/60 split screen | 🟢 | Small screens |
| Story text with typewriter effect | 🟢 | — |
| Animated keywords ("burn" 🔥, "freeze" ❄️…) | 🟢🟡 | Animate only recent lines so the game stays fast |
| Hero walks in a tile world, camera follows | 🟡 | Needs lots of art |
| Open world | 🔴 | Use **zones** linked by travel, not an endless map |
| AI moves things in the scene | 🔴 | Short list of allowed commands, checked by code |
| Dice, HP, inventory, quests | 🟡 | Reuse ideas from the old prototype |
| Turn-based combat with animations | 🟡🔴 | Keeping rules, text and animation in sync |
| NPCs and creatures that move around | 🟡 | — |
| Day/night and weather | 🟡 | Speed on the web |
| **Amount of art for one artist** | 🔴 | Small pixel art, 4 directions, free placeholder art first |
| AI waiting time and cost | 🟡🔴 | Hide waiting with animation; rolling story summary |
| Save files that keep working after updates | 🟡 | Version number + conversion for old saves |
| Music and sounds | 🟢🟡 | Optional |

## 👥 Who does what

| Person | Works on | Delivers as | Tools |
|---|---|---|---|
| **Lead (you)** | Code, rules, numbers, AI | Godot project on GitHub | Godot, VS Code, Python, Git |
| **Artist** | Tiles, characters, creatures, icons | PNG or Aseprite files in OneDrive `art/` | Aseprite (~$20) or LibreSprite (free) |
| **Writer** | Lore, NPCs, quests, DM style | Text/Markdown or Word in OneDrive `writing/` | Any text editor, Word |

How it flows: **teammates → OneDrive → lead copies into the Git repo → new build on a private itch.io page → everyone playtests from one link.**

## 🗓️ Milestones

| Step | When | Goal |
|---|---|---|
| **M0 Setup** | Week 1 | Git + GitHub, Godot project, folders, OneDrive share, guides for teammates |
| **M1 Prototype (decision)** | Weeks 2–4 | One small zone, a hero who walks, 3 animated keywords, one AI turn that spawns something, on itch.io. **Then: keep Godot or switch to Phaser** |
| **M2 Core systems** | Then | Rules, dice, sheet, inventory, quests, saves, copy-paste + API modes |
| **M3 World** | Then | Zones and travel, NPCs, day/night, weather, combat |
| **M4 Content** | Then | Art and writing at full speed, balance tools in Python |
| **M5 Release** | Then | Sound, settings, tutorial, public itch.io page, desktop version |

## 💻 Lead's computer
- ✅ Already installed: Git, VS Code, Python 3.13, Godot 4.7.2
- ➕ To add: GitHub account + GitHub Desktop, VS Code "godot-tools" extension
- ➕ Later: Node.js (for the Cloudflare Worker), butler (itch.io upload tool)

## 📁 Project folders (outside OneDrive)
```
brasswake/
├─ game/        Godot project
│  └─ content/  art, writing, data copied from OneDrive
├─ proxy/       AI key proxy (later)
├─ tools/       Python balance tools
├─ reference/   old web prototype
└─ docs/        this plan, team questionnaire
```
