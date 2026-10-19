# Spec: `narration` (story text and animated words)

*Module of [SPEC.md](SPEC.md). Depends on: `content` (keyword lists). Used by: `main-screen`. When: M1 (burn, freeze, shock), later the other three effects.*

## Objective

Show the story the way a book would feel if it were alive. The AI's narration types out letter by letter, and some words move: *fire* flickers, *frost* sparkles, *lightning* jitters. The animation must stay readable, never slow the game, and never let the AI's text do anything except show words and the six effects.

## Which words get an effect (option C)

1. **The AI's tags:** the DM rules allow the AI to mark up to 4 words, like `[burn]torch[/burn]`.
2. **The word list:** `keywords.csv` (edited by the writer) tags the matching words the AI didn't tag. This matters: in the Haiku test, the AI used no tags at all.

| Rule | Value (adjustable) |
|---|---|
| AI tags kept per entry | 4 (first ones; tags beyond that are removed, the words stay) |
| Animated words per entry, AI + list | 6 |
| Longest text inside one AI tag | 30 characters (longer: the tags are removed, the text stays) |
| Matching | Whole words only, ignoring case and handling accents (`Éclair` matches `éclair`, `firewood` doesn't match `fire`), longest words first |
| Language | The keyword list of the current game language |

## Safety

The narration comes from the AI, so it is **untrusted**.

- Any markup that isn't one of the six effect tags shows as **plain text**: `[url=…]`, `[img]`, `[font_size=500]`, `[color]`…
- An effect tag only counts as a well-formed pair with nothing nested (`[burn]fire[/burn]`). An unclosed or nested tag shows as plain text.
- Player lines, dice results and system messages are always plain text.

## Effects

| Effect | Moving look | Still colour (old entries, reduce motion) | When |
|---|---|---|---|
| `burn` | Orange-yellow flicker, letters bob up | `#ff8a3d` | M1 |
| `freeze` | Pale blue, a sparkle wave runs across | `#9fd8ff` | M1 |
| `shock` | Yellow, letters jitter | `#ffe066` | M1 |
| `poison` | Green, slow wobble | `#8fd16a` | Later |
| `whisper` | Grey, fades in and out | `#b9b3c9` | Later |
| `holy` | Soft gold glow | `#ffe9a8` | Later |

An effect not built yet shows in its still colour.

## Interface

| Function / signal | Does |
|---|---|
| `tag(ai_text, lang) -> safe_markup` | Applies the safety rules, then option C. Pure function: testable headless |
| `add_entry(safe_markup)` | Adds a narration entry and types it out. Only the new entry types; older text stays shown |
| `add_plain_line(text, kind)` | Player action, dice result or system message, shown at once in a muted colour |
| `skip()` | Finishes the typing now (also on click or key press on the story) |
| `finished_typing` (signal) | Emitted when the entry is fully shown, typed or skipped |
| Settings | `chars_per_second` (45), `animated_entries` (4), `reduce_motion` (off), `max_effect_words` (6) |

- Only the newest `animated_entries` entries move; older ones switch to their still colour.
- **Reduce motion:** all effects use their still colour; the typewriter still runs unless text speed is set to instant (setting in M2).
- The story view follows new text unless the player has scrolled up to reread.

## Acceptance criteria

**M1**
- [ ] `tag()` fixtures, English and French:
  - `"The fire burns."` → both words `burn`.
  - `"firewood"` → nothing.
  - `"Un Éclair frappe"` (fr) → `Éclair` gets `shock`, original case kept.
  - `"[freeze]mist[/freeze] and fire"` → `mist` keeps `freeze`, `fire` gets `burn`.
  - `"[url=x]click[/url]"` → shown literally.
  - `"[burn]fire"` (unclosed) → shown literally.
  - 5 AI tags → only the first 4 kept.
  - 10 matching words → only 6 animated.
  - A 40-character AI tag → tags removed.
- [ ] A new entry types at about 45 characters per second; a click skips to the end; `finished_typing` fires once per entry in both cases.
- [ ] Adding an entry never re-types or flickers the older text.
- [ ] Burn, freeze and shock look like the table on screen (manual check).
- [ ] The 5th newest entry and older are still (manual check); with reduce motion nothing moves.
- [ ] With 100 entries in the story and 4 animating, the game holds 55+ fps on the lead's PC.

**Later**
- [ ] Poison, whisper and holy effects.
- [ ] Text speed setting, including "instant".

## Tests

- Automated: the `tag()` fixtures above, plus a check that every word in `keywords.csv` gets tagged in a sample sentence.
- Manual (before each build): typing, skipping, scrolling, the look of each effect, reduce motion.

## Boundaries (module)

- **Always:** pass AI text through `tag()`; never append it raw.
- **Ask first:** changing the effect list (it is also in the DM rules and `keywords.csv`).
- **Never:** let narration call the AI, change the state, or trigger world commands. It only shows text and emits `finished_typing`.

## Open questions

- Are 4 AI tags and 6 animated words per entry the right numbers? Tune after the first playtests.
- Should the old entries keep their still colour, or turn fully plain after many turns?
- Font: the team's choice of a readable font with French accents (Q9 in the questionnaire touches style).
