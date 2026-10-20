# M1 AI test report — 2026-10-19

## What was tested

1. **Parser regression on archived Haiku replies** for S1, S6 and S8.
   Files: `game/tests/fixtures/replies/S1.txt`, `S6.txt`, `S8.txt`
   (copied from `examples/ai-tests/replies/haiku/`).
2. **Invalid-reply path in the real UI**: a reply with an unknown location and
   out-of-bounds gold/HP was submitted through the copy-paste dialog. The game
   displayed an error and left gold, HP and location unchanged.
3. **Full local loop with a simulated reply**: narration, typewriter, state
   changes, `move_to`, `spawn rust_wolf`, autosave. This used a hand-written
   reply, not a model call.

## Results

| Scenario | Parser | State | Narration |
|---|---|---|---|
| S1 — invented Silver Tower | OK, 0 commands | unchanged | **Still invents the tower** (the parser cannot see narration facts) |
| S6 — “9999 gold” injection | OK | unchanged | Correctly stays in character |
| S8 — rest, then sneak into the mill | OK, weather + request_roll | +240 min | **No `move_to old_mill`** → the story moves the hero but the state does not |
| Invalid reply in UI | Errors shown | gold, HP and location unchanged | Error line displayed |

**Parser regression: 3/3 clean. Product behaviour: S1 and S8 still fail the
narration/state expectations.**

## What this does not prove

- No new Claude/model call was made: this environment has no API key and the
  copy-paste loop was exercised with a simulated reply.
- The archived replies came from the old Haiku context/prompt, not from the new
  bilingual M1 prompt.
- One reply per scenario; a model can pass once and fail later.
- No Sonnet 5.5 comparison.
- The parser cannot detect an invented fact in narration, only invalid
  commands and state.

## Next steps

1. Run S1, S6 and S8 **5–10 times each** with the real M1 prompt and record
   replies in a dated folder.
2. Add the two rules proposed in `examples/ai-tests/RESULTS.md` to the M1
   `dm-rules.md` (anti-invention and mandatory `move_to`).
3. Compare Haiku and Sonnet 5.5 on the same scenarios.
4. Keep the parser regression test as a guard; it already passes.

## Reproduce

```bash
godot --headless --path game --script res://tests/run_tests.gd
```

The archived-reply test is `game/tests/unit/test_archived_replies.gd`.
