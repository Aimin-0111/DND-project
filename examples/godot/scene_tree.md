# Godot scene structure (static example)

How the main screen is built from Godot nodes. The **same two pieces** (the world and the story panel) are placed differently for each layout option in `interface/mockups.html`.

## The two main pieces

```
World (Node2D)                      ← the 60% animated scene, its own scene file: world/world.tscn
├─ Ground (TileMapLayer)            ← grass, roads, water, painted by the artist's tileset
├─ Decor (TileMapLayer)             ← trees, rocks, houses (y-sorted)
├─ Locations (Node2D)               ← named places the AI is allowed to use
│  ├─ old_mill (Marker2D)           ←   in group "locations"
│  ├─ mill_bridge (Marker2D)
│  └─ mill_bridge_east (Marker2D)
├─ Creatures (Node2D)               ← wolves, NPCs spawned here
├─ Hero (CharacterBody2D)           ← movement_free.gd / movement_click.gd / movement_grid.gd
│  ├─ AnimatedSprite2D              ←   walk_up/down/left/right, idle_*
│  ├─ CollisionShape2D
│  └─ Camera2D                      ←   follows the hero
├─ Weather (GPUParticles2D)         ← rain, snow, ash
├─ DayNight (CanvasModulate)        ← tints the whole world by time of day
└─ SceneDirector (Node)             ← scene_director.gd: runs the AI's checked commands

StoryPanel (PanelContainer)         ← the 40% text side, its own scene file: ui/story_panel.tscn
└─ VBoxContainer
   ├─ Tabs (TabContainer)
   │  ├─ Story (RichTextLabel)      ← narration_panel.gd + keyword effects
   │  ├─ Sheet (VBoxContainer)
   │  ├─ Pack (ItemList)
   │  ├─ Quests (Tree)
   │  └─ Codex (RichTextLabel)
   └─ ActionBar (HBoxContainer)
      ├─ ActionInput (LineEdit)     ← "What do you do?"
      ├─ ActButton (Button)
      └─ RollButton (Button)
```

## Main scene: layout options

The world is drawn inside a `SubViewport`, so its camera only fills its own part of the screen.

### Option A: side by side (recommended for computers)
```
Main (Control, full rect)
├─ HUD (CanvasLayer)                   ← HP, gold, time, place
└─ Split (HBoxContainer)               ← or HSplitContainer so the player can drag the divider
   ├─ WorldView (SubViewportContainer) ← stretch = true, size_flags_stretch_ratio = 6
   │  └─ SubViewport
   │     └─ World (instance of world.tscn)
   └─ StoryPanel (instance)            ← size_flags_stretch_ratio = 4
```

### Option B: stacked (phones / portrait)
Same as A, but `Split` is a `VBoxContainer` (or `VSplitContainer`). The game can swap A ↔ B when the window becomes taller than it is wide (`get_viewport().size_changed` signal).

### Option C: full-screen scene with floating story panel
```
Main (Node)
├─ World (instance of world.tscn)      ← fills the screen, no SubViewport needed
├─ HUD (CanvasLayer, layer 1)
└─ UI (CanvasLayer, layer 2)
   └─ StoryPanel (instance)            ← anchored bottom-right, ~45% × 50%, semi-transparent
```
The camera needs an offset so the hero isn't hidden under the panel.

## Autoloads (global singletons, Project Settings → Globals)

```
Game        ← holds the current state Dictionary, dice, save/load (core/)
Content     ← loads monsters/items/keywords/lore at start (content/content_loader.gd)
DM          ← picks the AI adapter (copy-paste / proxy / own key) and runs turns (ai/)
```

## Data flow for one turn

```
ActionInput ──text──▶ DM.play_turn()
                        │ PromptBuilder.build(state, action)
                        │ await adapter.generate_turn(prompt)   (2–10 s)
                        ▼
                    DmReplyParser.parse(reply)  ── drops unknown commands ──▶ errors (logged)
                        │ narration                 │ commands             │ state changes
                        ▼                           ▼                      ▼
              KeywordTagger → NarrationPanel   SceneDirector          Game.apply_changes()
              (typewriter + effects)           (walk, spawn, rain)    (HP, gold, quests, save)
```
