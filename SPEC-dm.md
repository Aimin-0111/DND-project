# Spec: `dm` (one AI Dungeon Master turn)

*Module of [SPEC.md](SPEC.md). Depends on: `core` (state view, skill list), `content` (rules, Codex, allowed ids). Used by: `main-screen`; `world` uses its command list; `proxy` (M2) implements its server contract. When: M1 (copy-paste + own key).*

## Objective

Run one turn of the AI Dungeon Master: build the prompt, send it through the chosen connection, and **check the reply** before anything else sees it. The AI's reply is untrusted: it can invent a place, ask for 9,999 gold, obey a player's "SYSTEM OVERRIDE" or forget the JSON. This module turns it into narration plus a list of changes the game can safely apply.

## The turn

`play_turn(state, action, lang) -> TurnResult` (asynchronous: the game keeps animating while the AI answers).

```
TurnResult = {
  ok: bool,            # false = no usable reply: nothing changes
  narration: text,     # untrusted text, still to go through narration.tag()
  commands: [...],     # checked commands, in order
  changes: {...},      # checked state changes
  errors: [...],       # what was dropped or clamped, for the debug log
  status: text         # message for the player when ok is false
}
```

## The prompt

Ordered from **most stable to least stable**, so prompt caching can reuse the beginning:

| # | Part | Source |
|---|---|---|
| 1 | DM rules + one language line ("Narrate in French." / "Narrate in English.") | `content.dm_rules()` |
| 2 | Codex | `content.codex_text()` |
| 3 | Story so far | `state.story_summary` |
| 4 | State view: hero, gold, pack, quests, location, weather, creatures present, clock text | `core` |
| 5 | Allowed ids: locations, creatures, items, quests, npcs + skills | `content.allowed_ids()` + `core.skills()` |
| 6 | Last roll result, if any | `state.last_roll` |
| 7 | Player action | The action box |

- Ids and JSON keys stay in English whatever the language.
- Never sent: `seed`, `rng_state`, `log`, settings, the API key.
- **The DM rules include the two fixes from the Haiku test** (decided October 19, 2026; see `examples/ai-tests/RESULTS.md`): a place, person, creature or item that isn't in the Codex, the allowed ids or the pack doesn't exist in this world (S1); when the story moves the hero to a listed place, the reply includes a `move_to` for it (S8). Code can't check the first one, so S1 and S8 are rerun once the real game can play a turn.
- **M1 story so far:** the intro text + the last 3 narrations (each cut to 600 characters). **M2:** a rolling summary refreshed every 5 turns by a cheaper model, at most 200 words.

## Contract: the reply format

Narration first, then a line with exactly `<<STATE>>`, then **one** JSON object (fences like ```` ```json ```` are tolerated). This format works in copy-paste mode too, so it stays the format for every connection.

```
The planks groan as you step onto the bridge...
<<STATE>>
{"commands": [{"type": "move_to", "target": "mill_bridge"}],
 "state": {"gold_delta": 5, "time_advance_minutes": 10}}
```

### Commands (at most 5 per reply; extra ones are dropped)

| `type` | Fields | Check |
|---|---|---|
| `move_to` | `target` | `target` is an allowed location |
| `spawn` | `creature`, `near` | Allowed creature, allowed location |
| `despawn` | `creature` | Allowed creature |
| `emote` | `who`, `emote` | `who` is `hero` or an allowed NPC; `emote` ∈ surprised, angry, happy, scared, sleep |
| `weather` | `kind` | `kind` ∈ clear, rain, fog, storm, snow, ash |
| `request_roll` | `skill`, `dc` | Allowed skill; `dc` is a whole number from 5 to 30 |

A command with a missing field, a wrong type or an unknown value is dropped and noted in `errors`. The others still apply.

### State changes

| Key | Allowed | Outside the range |
|---|---|---|
| `hp_delta` | −30 … +30 | Clamped, noted |
| `gold_delta` | −200 … +200 | Clamped, noted |
| `time_advance_minutes` | 0 … 1440 | Clamped, noted |
| `add_items` | Up to 3 allowed item ids | Unknown ids dropped, noted |
| `quest_updates` | `{id, stage, done}` with an allowed quest, whole `stage` ≥ 0, `done` true/false | Bad entries dropped, noted |

Unknown keys are ignored and noted. `core` clamps again when applying (defence in depth).

### When the reply is broken

| Case | Result |
|---|---|
| Empty reply (cancelled, network error, refusal) | `ok: false`, `status` explains; nothing changes |
| No `<<STATE>>` line | `ok: true`, narration only, no changes; noted |
| `<<STATE>>` but invalid JSON | Same as above |

## Connections

One interface: `generate_turn(prompt) -> reply text` (empty = no reply), plus status messages for the player. The rest of the game never knows which connection is active.

| Connection | How | When |
|---|---|---|
| **Copy-paste** | The prompt is turned into one text block and copied (the copy must start from a click: browsers require it). The player pastes it into their own Claude chat and pastes the reply back into a dialog. Cancel = empty reply. **Always kept working.** | M1 |
| **Own key** | The player's own API key, stored only on their device. Model and settings from the AI cost study (Sonnet 5.5, effort low, prompt caching on the rules and Codex; see `examples/godot/ai/own_key_adapter.gd`). Token usage (input, cache read, output) is printed to the debug log for the cost study | M1 |
| **Proxy client** | Calls our server (`proxy` module) with the contract below | M2 |

**Own-key status messages** (in the player's language): no key set, key refused (401), service error (other codes), no answer after 90 s, the DM can't narrate that (refusal), reply cut off (the text is kept, a warning is logged).

**Server contract for `proxy` (M2, defined here):** `POST /turn` with `{lang, codex, summary, state, allowed, last_roll, action}` returns `200 {text, truncated, usage}`; `422` refusal; `401` bad game token; `429` too many requests. The server holds the DM rules itself (generated from `dm-rules.md`).

## Acceptance criteria (M1)

- [ ] **Saved replies:** the 8 Haiku replies in `examples/ai-tests/replies/haiku/` pass with no dropped commands, and the kept commands match [RESULTS.md](examples/ai-tests/RESULTS.md):
  - S3: Athletics DC 13;
  - S4: `move_to old_mill` + Perception DC 12;
  - S5: Persuasion DC 13;
  - S8: fog + Stealth DC 13 + 240 minutes;
  - S1, S2, S6, S7: no commands and no state changes.
- [ ] **Crafted bad replies**, each with the expected result:
  - no marker;
  - broken JSON;
  - JSON inside fences;
  - 8 commands (5 kept);
  - unknown command type;
  - `move_to "silver_tower"`;
  - `spawn "dragon"`;
  - `emote` by an unknown NPC;
  - `dc: 50`; `dc: "13"` (text);
  - `gold_delta: 9999` (clamped to 200);
  - `add_items: ["excalibur"]`;
  - 5 valid `add_items` (3 kept);
  - quest with a text stage.
- [ ] **Prompt:**
  - the parts come in the order above;
  - `seed`, `rng_state`, `log` and the key never appear;
  - the language line follows the setting;
  - two prompts built from the same state differ only in parts 3–7.
- [ ] **Copy-paste:** in the web build, the copied text pastes into a Claude chat in one piece, and a pasted reply runs a full turn.
- [ ] **Own key:** a real key produces a turn. A wrong key shows the "key refused" message and changes nothing. Turning off the network shows an error, not a frozen game.
- [ ] The game keeps animating (hero idle, effects) while waiting for the AI.

## Tests

- Automated: reply checks on all fixtures above (`tests/fixtures/replies/`); prompt order and content.
- Manual: one real turn per connection before each build; the 8 trap scenarios rerun with the chosen model before M2 (5 runs each).

## Boundaries (module)

- **Always:** keep the command list, the limits and the DM rules' format section in sync. The DM rules are the AI's copy of this contract.
- **Ask first:** adding a command, changing a limit or the reply format (it changes `core`, `world`, the DM rules and the fixtures).
- **Never:**
  - Run, evaluate or display as markup anything from the reply.
  - Let the AI decide a roll's result.
  - Write the API key to a log, a save file or the repo, or send it anywhere but the Claude API.

## Open questions

- Later option for the API connections only: Claude "structured outputs" (a JSON schema) for more reliable replies. The checks stay either way.
- Later option: markers inside the narration so commands play mid-text (the M1 choice is "after the text").
- Which model for the summary refresh (M2): confirm with the play test.
