# Spec: `dm` (one AI Dungeon Master turn)

*Module of [SPEC.md](SPEC.md). Depends on: `core` (state view, skill list), `content` (rules, Codex, allowed ids), `map` (the MAP part and the travel checks, through `core`'s map view). Used by: `main-screen`; `world` uses its command list; `proxy` (M2) implements its server contract. When: M1 (copy-paste + own key), Beta-0.3 (`travel` and the MAP part, lead's decisions of November 2, 2026).*

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
  suggestions: [...],  # Beta-0.4: up to 3 checked plain texts for the chips (may be empty)
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
| 4 | State view: hero, gold, pack, quests, location, weather, creatures present **in the current square**, clock text. Beta-0.4: the hero also shows Steam, level, XP (and the XP of the next level), the armour class and attack bonus computed by `core`, and the equipped items | `core` |
| 5 | **MAP** (Beta-0.3): the current square (id, kind, made by hand or generated, its places), the four neighbours (id, kind, whether the hero can enter, whether visited, their places) and the visited squares (id, kind, places) | `core`'s map view, from `state` + `map` |
| 6 | Allowed ids: locations, creatures, items, quests, npcs + skills + `travel` (the valid `to` values this turn) | `content.allowed_ids()` + `core.skills()` + the map view |
| 7 | Last roll result, if any. Beta-0.4: then "Since your last reply:" and the `events` (items the player used), if any | `state.last_roll`, `state.events` |
| 8 | Player action | The action box, or the automatic travel action ([SPEC-main-screen.md](SPEC-main-screen.md#exits-the-automatic-travel-turn)) |

- Ids and JSON keys stay in English whatever the language.
- Never sent: `seed`, `rng_state`, `log`, settings, the API key, and (Beta-0.3) the stored tiles (`squares`) and `hero_cell`.
- In Godot the MAP view reaches `PromptBuilder.build` inside the allowed ids (`allowed["map"]`); the builder takes it out of ALLOWED IDS and prints it as its own part. The reply checks read the same view, so the prompt and the checks can't disagree.
- **The DM rules include the two fixes from the Haiku test** (decided October 19, 2026; see `examples/ai-tests/RESULTS.md`): a place, person, creature or item that isn't in the Codex, the allowed ids or the pack doesn't exist in this world (S1); when the story moves the hero to a listed place, the reply includes a `move_to` for it (S8). Code can't check the first one, so S1 and S8 are rerun once the real game can play a turn.
- **Beta-0.3 rules:** how to use `travel` (a direction from MAP the hero can enter, or a visited square id; at most one; the other commands then apply to the new square); describe a generated square by its kind and never invent named places there. Changing `dm-rules.md` invalidates the prompt cache: rerun S1 and S8, plus one exit turn.
- **Beta-0.4 rules** (new lines in `dm-rules.md`; tell the writer):
  - give `xp_gain` when the hero overcomes something: about 50 for a creature beaten or avoided cleverly, 100–300 for a quest stage;
  - use `steam_delta` when the hero spends Steam on magic or gets it back (rest, brass tonic machines…);
  - end with up to 3 short `suggestions` of what the hero could do next, in the player's language.
- **M1 story so far:** the intro text + the last 3 narrations (each cut to 600 characters). **M2:** a rolling summary refreshed every 5 turns by a cheaper model, at most 200 words.

## Contract: the reply format

Narration first, then a line with exactly `<<STATE>>`, then **one** JSON object (fences like ```` ```json ```` are tolerated). This format works in copy-paste mode too, so it stays the format for every connection.

**The marker line (Beta-0.4).** These rules answer the two questions in [docs/m1-ai-tests.md](docs/m1-ai-tests.md); Claude decided them on the lead's behalf on November 4, 2026.
- The marker is a line holding `<<STATE>>` with nothing else on it but spaces or tabs.
- A marker inside a sentence is still not a marker.
- **Several marker lines:**
  - the **last** one is used, and this is noted;
  - the narration is the text before it, with the earlier marker lines taken out.
  - Why the last one: the AI's own block comes last in the format, and an earlier one usually quotes the player.

**Top-level keys:**
- `commands` and `state`, as below;
- `suggestions` (Beta-0.4, optional): what the hero could do next, shown as chips ([SPEC-main-screen.md](SPEC-main-screen.md#suggested-actions)). It is a list of texts:
  - at most 3 are kept;
  - each is trimmed, its line breaks become spaces, tags like `[burn]` are removed, and it is cut to 60 characters;
  - an entry that isn't text, or is empty, is dropped and noted;
  - suggestions never change the state.

Any other key is ignored and noted.

```
The planks groan as you step onto the bridge...
<<STATE>>
{"commands": [{"type": "move_to", "target": "mill_bridge"}],
 "state": {"gold_delta": 5, "time_advance_minutes": 10}}
```

### Commands (at most 5 per reply; extra ones are dropped)

| `type` | Fields | Check |
|---|---|---|
| `travel` | `to` | Beta-0.3. `to` is `north`, `east`, `south` or `west` and leads to an existing square the hero can enter, or `to` is the id of a square the hero has visited (not the current one). At most one per reply: later ones are dropped |
| `move_to` | `target` | `target` is a place **in the current square** (the destination square when the reply travels). Without a map view (tests, M1): an allowed location |
| `spawn` | `creature`, `near` | Allowed creature; `near` is a place in the current square (as for `move_to`) or `hero` |
| `despawn` | `creature` | Allowed creature |
| `emote` | `who`, `emote` | `who` is `hero` or an allowed NPC; `emote` ∈ surprised, angry, happy, scared, sleep |
| `weather` | `kind` | `kind` ∈ clear, rain, fog, storm, snow, ash |
| `request_roll` | `skill`, `dc` | Allowed skill; `dc` is a whole number from 5 to 30 |

A command with a missing field, a wrong type or an unknown value is dropped and noted in `errors`. The others still apply.

**Travel plays first.** The kept `travel` is moved to the front of the checked list, and every other command in that reply applies to the destination square: `move_to` and `spawn near` are checked against the destination's places. The checked travel keeps only `type` and `to`; `core` fills in the destination `square` and the arrival `cell` when it applies it.

### State changes

| Key | Allowed | Outside the range |
|---|---|---|
| `hp_delta` | −30 … +30 | Clamped, noted |
| `gold_delta` | −200 … +200 | Clamped, noted |
| `time_advance_minutes` | 0 … 1440 | Clamped, noted |
| `add_items` | Up to 3 allowed item ids | Unknown ids dropped, noted |
| `quest_updates` | `{id, stage, done}` with an allowed quest, whole `stage` ≥ 0, `done` true/false | Bad entries dropped, noted |
| `xp_gain` | 0 … 300 (Beta-0.4) | Clamped, noted |
| `steam_delta` | −30 … +30 (Beta-0.4) | Clamped, noted |

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

**Own-key status messages** (in the player's language; keys `ui.ai_*` in `strings.csv`): no key set, key refused (401), service error (other codes), can't reach the service (no HTTP answer at all: network off, DNS, TLS or CORS; `ui.ai_network_error`), no answer after 90 s, the DM can't narrate that (refusal), reply cut off (the text is kept, a warning is logged). While the request runs, the connection also sends "Waiting for the AI DM" (`ui.waiting`).

**Server contract for `proxy` (M2, defined here):** `POST /turn` with `{lang, codex, summary, state, map, allowed, last_roll, action}` returns `200 {text, truncated, usage}`; `422` refusal; `401` bad game token; `429` too many requests. The server holds the DM rules itself (generated from `dm-rules.md`).

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
  - two prompts built from the same state differ only in parts 3–8.
- [ ] **Copy-paste:** in the web build, the copied text pastes into a Claude chat in one piece, and a pasted reply runs a full turn.
- [ ] **Own key:** a real key produces a turn. A wrong key shows the "key refused" message and changes nothing. Turning off the network shows an error, not a frozen game.
- [ ] The game keeps animating (hero idle, effects) while waiting for the AI.

## Acceptance criteria (Beta-0.3)

- [ ] **Travel checks** (automated): a direction to an enterable square is kept; a direction to a lake, a mountain or off the map is dropped; a visited square id is kept, an unvisited or malformed one is dropped, the current square is dropped; a second travel is dropped; the kept travel comes first even when the AI wrote it last; extra keys on a travel are removed.
- [ ] After a travel, `move_to` and `spawn near` are checked against the destination's places; `spawn near hero` is kept.
- [ ] Without a map view (the M1 fixtures), the old checks apply unchanged.
- [ ] **Prompt:** a MAP part between STATE and ALLOWED IDS, with the current square, its places, the four neighbours and the visited squares; ALLOWED IDS lists the `travel` targets; no stored tiles (`legend`, `rows`) and no `hero_cell` in the prompt.
- [ ] `dm-rules.md` explains `travel` and says generated squares are described by their kind, with no invented named places.

## Acceptance criteria (Beta-0.4)

- [ ] `xp_gain` and `steam_delta` inside their ranges are kept; outside values are clamped and noted; a value that isn't a number is dropped and noted.
- [ ] **`suggestions`:**
  - up to 3 are kept, trimmed, as plain text of at most 60 characters;
  - a 4th is dropped and noted, and so is an entry that isn't text or is empty;
  - with no `suggestions` the result has an empty list;
  - suggestions never touch the state.
- [ ] **The marker:**
  - `  <<STATE>>\t` (spaces and a tab around it) is the marker;
  - with two marker lines the last one is used and this is noted, and the narration holds no marker line;
  - a marker inside a sentence is still narration.
- [ ] **The prompt:**
  - the state view shows Steam, level, XP, the armour class, the attack bonus and the equipment;
  - part 7 shows the events, and they are gone from the next prompt.
- [ ] The 8 archived Haiku replies and the crafted bad replies give the same results as before, except the marker fixtures, whose expected results change on purpose (listed in the test).

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
