# M1 acceptance checklist — 2026-10-19

| AC | Status | Evidence |
|---|---|---|
| AC1 — headless boot + tests | ✅ | `godot --headless --path game --quit` exit 0; `PASS: 13 test file(s)` |
| AC2 — content check FR/EN | ✅ | `python3 tools/content_check.py --check --langs fr,en` |
| AC3 — 40/60 + stacked layout | ✅ | Integration test + visual capture; stacked test at 800 px |
| AC4 — hero moves to 3 locations | ✅ | `test_scene_layout`, movement check (957 frames to mill) |
| AC5 — typewriter + 3 effects | ✅ | Visual capture; tagger tests; effects installed |
| AC6 — one copy-paste turn | ✅ | End-to-end simulated reply: narration, gold, quest, spawn, move |
| AC7 — invalid reply leaves state | ✅ | Invalid-reply UI check: gold/HP/location unchanged |
| AC8 — save/load + RNG | ✅ | Unit round-trip + UI save/load test |
| AC9 — FR/EN UI + content + prompt | ✅ | Language toggle test; prompt builder test |
| AC10 — unit + integration tests | ✅ | 13 test files pass |
| AC11 — S1/S6/S8 with real prompt | ⚠️ Partial | Archived replies parsed; no new model call (see `m1-ai-tests.md`) |
| AC12 — private itch.io build | ⚠️ Partial | macOS export built and launched; page/upload is a human action |
| AC13 — no secrets / hardcoded content | ✅ | No keys; content loads from CSV/MD; demo line is not game data |

## M1 status

The local vertical slice is playable end to end. Two acceptance items remain
outside the code:

1. **AC11**: run the three scenarios against the real model with the M1 prompt.
2. **AC12**: create the private itch.io page, upload the build and verify team
   access.

Until then, M1 is **not closed**, even though the code path is functional.
