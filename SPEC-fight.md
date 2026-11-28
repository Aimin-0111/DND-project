# Spec: `combat` (fights, Beta-0.5)

*Brought forward from M3 on November 27, 2026, at the lead's request ("add normal fight and boss fight"). Code: `game/core/fight.gd` (rules), `game/ui/fight_window.gd` (screen), wired in `game/main.gd`.*

## Objective

Turn-based dice fights, owned by the game: the AI never rolls and never decides a fight. The DM hears about a fight afterwards, through the story so far.

## How a fight starts and ends

- **Start:** the hero comes within reach (26 px, under one tile) of a creature drawn in the world. Creatures come from the DM's `spawn` command or from `maps/creatures.csv` (placed in a box, they join the state on the box's first visit).
- A creature the DM spawns right next to the hero waits until the hero moves away and comes back: fights never start by surprise at the end of a turn.
- The world and the action box wait during a fight. Esc doesn't close the fight window.
- **Won:** the creature leaves the state and its `gold` goes to the hero.
- **Fled:** nothing more; that creature waits until the hero is 3 × 26 px away.
- **Lost:** the hero wakes on the start place (`mill_road`) with half HP, 8 hours later. There is no game over (team default Q-5).
- Every fight adds 5 minutes. One line goes into the story and into the story so far ("Kael defeated Rust Wolf and won 3 gold."). Then an autosave.

## A round

The hero acts, then the creature answers (unless the fight ended).

| Action (key) | Rule |
|---|---|
| Attack (1) | d20 + 2 (proficiency) + the best of the STR and DEX modifiers, against the creature's `ac`. Damage: the first weapon in the pack (`items.csv` `damage`, else `1d2`) + that modifier. A natural 20 rolls the weapon dice twice; a natural 1 misses |
| Guard (2) | +2 AC against the answer, and a special attack does half damage |
| Potion (3) | The first pack item with a `heal` (`items.csv`) heals that much, up to max HP, and leaves the pack. Refused with none left (the round isn't used) |
| Flee (4) | Acrobatics check (DEX) against 10 + the creature's `level`. Never against a boss (refused, the round isn't used) |

The creature's answer: d20 + `attack_bonus` against the hero's AC, then `damage`. A creature with a `special` uses it every `special_every` rounds instead: `special_damage`, no roll, halved by Guard. The round before, it **charges** it (a warning line), so the player can guard.

**Bosses** (`boss` = true): no fleeing, a red frame and a bigger picture. At half HP or less they become **enraged**: +2 to hit, and the special comes one round sooner.

## Data (`data/monsters.csv`, `data/items.csv`)

New optional columns. Empty cells mean "none".

- `monsters.csv`: `gold`, `boss` (true/false), `special` (an id with strings `fight.special.<id>` and `fight.charge.<id>`), `special_damage` (dice), `special_every` (rounds).
- `items.csv`: `damage` (dice, weapons) and `heal` (dice, potions).

**Balance (Beta-0.5, level 1 hero, 12 HP, 2 potions).** This is a simulated player who guards when warned and drinks a potion at 5 HP or less, over 500 seeded fights:

| Creature | Win rate |
|---|---|
| Brass beetle | ≈ 100% |
| Rust wolf (the lead's M1 numbers) | ≈ 68% |
| Mill golem (boss: 16 HP, AC 12, +3, 1d6, steam 2d4+1 every 3 rounds) | ≈ 57% |

## Later

XP from fights (with T2's levels), several creatures at once, fights started by the DM, the fight drawn in the world instead of a window, status effects (M3).

## Tests

`tests/unit/test_fight.gd` covers the rules with seeded dice. `tests/integration/test_beta05_screen.gd` plays a whole fight on the real main scene.
