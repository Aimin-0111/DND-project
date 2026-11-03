# Own-key mode (Task 17)

*Branch `Beta-0.3-own-key`, cut from `Beta-0.2`, 2026-11-03.*

Own-key mode lets a player use their own Claude API key: each turn goes straight from the game to the Claude API, with no paste dialog. The key is stored only on the player's device. Copy-paste mode is still the default and works as before.

## How to use it

1. **Get a key.** Claude Console → **API keys** → **Create key**. Scope it to **one workspace**, and give it an expiry date (see "Known limits" for why).
2. **Open the settings.** Click the gear button in the HUD (top left, after Load).
3. Under **AI mode**, pick **My own API key**. Paste the key into the masked field, then click **Save**.
4. The HUD now shows **AI: own key**. Type an action and press **Act**: the DM answers with no paste dialog.
5. **Later visits to the settings:**
   - The key field stays empty and says **A key is saved on this device**. The game never shows a saved key again.
   - **Save** with the field empty keeps the saved key. A key typed or pasted in the field replaces it.
   - **Clear** removes the key from the device at once, even if you then click Cancel.
   - To go back to the free mode, pick **Copy-paste (free)** and save.

Where the key lives:
- in `user://settings.cfg`, section `[ai]`;
- on Windows: `%APPDATA%\Godot\app_userdata\Brasswake Reach\settings.cfg`;
- in the web build: the browser's IndexedDB for the page's address, at `/userfs/godot/app_userdata/Brasswake Reach/settings.cfg`.

It is never in a save, a log, the prompt, the repo or a build. The player's own Claude account pays for the turns.

## What the game sends

Checked against the Claude API docs and the official TypeScript SDK source on 2026-11-03.

| Part | Value |
|---|---|
| Endpoint | `POST https://api.anthropic.com/v1/messages` |
| Key | `authorization: Bearer <key>` (the docs now call `x-api-key` the legacy header) |
| Version | `anthropic-version: 2026-10-21` |
| Web build only | `anthropic-dangerous-direct-browser-access: true`. Browsers block a direct call to the API without it (CORS) |
| Model and effort | `claude-sonnet-5-5`, `output_config.effort: "low"`. Thinking stays at the default (adaptive); at low effort the model skips it on most simple requests |
| Length | `max_tokens: 4096` |
| Cached part | `system`: two text blocks, `=== RULES ===` + the DM rules, then `=== CODEX ===` + the Codex. Each has `cache_control: {"type": "ephemeral"}` (5-minute cache) |
| Rest of the prompt | One user message: `PromptBuilder.to_single_text(prompt)` minus its RULES and CODEX parts. So both modes send exactly the same text, and any part the builder adds later (MAP…) reaches this mode too |
| Refusal fallback | `anthropic-beta: server-side-fallback-2026-07-01` with `"fallbacks": "default"` |
| Timeout | 90 s, using Godot's `HTTPRequest.timeout` |

Notes:
- **Cache size.** Sonnet 5.5 only caches a prefix of 512 tokens or more.
  - Today the rules (about 1.9 KB) are probably under that on their own, but rules + Codex are over it.
  - Expect a "cache write" on the first turn, then "cache read" on the turns that follow within 5 minutes.
  - Switching language changes the Codex, so the next turn writes a new cache entry.
- **Fallback.** On Sonnet 5.5, the default fallback only reruns `cyber` and `frontier_llm` declines (on Sonnet 5). A decline in this game is more likely `general_harms`, which has no fallback, so the player sees "The DM can't narrate that".
  - If a player's key gets a `400` about `anthropic-beta`, set `SERVER_FALLBACK := false` in `game/ai/own_key_adapter.gd`.
- **Why 4096 tokens.** That is room for a short think plus a long reply. A maxed-out reply still arrives before the 90 s timeout, so the player gets the text with a "cut off" warning instead of nothing.
- **No streaming.** A DM reply is short; one plain request keeps the code simple and fits Godot's `HTTPRequest`.

## Messages for the player

All of them are in `game/content/i18n/strings.csv`, in English and French.

| Case | Key | English text |
|---|---|---|
| No key set | `ui.ai_no_key` | No API key set. Add yours in Settings or switch to copy-paste mode. |
| Key refused (401) | `ui.ai_key_refused` | The API key was refused. Check it in Settings. |
| Service error (any other code, shown with it, e.g. "(529)") | `ui.ai_service_error` | The AI service answered with an error. Try again in a moment. |
| No answer after 90 s | `ui.ai_timeout` | No answer from the AI after 90 seconds. Try again. |
| Refusal | `ui.ai_refusal` | The DM can't narrate that. Try another action. |
| Reply cut off (the text is kept, a warning is logged) | `ui.ai_cut_off` | The DM's reply was cut off: the end may be missing. |
| **New:** can't reach the service (network off, DNS, TLS, CORS) | `ui.ai_network_error` | Can't reach the AI service. Check your internet connection. |

The last row is not in SPEC-dm's list yet. It covers a network failure, which has no HTTP code. **To do (lead): add it to SPEC-dm.**

Where the player sees them (`main.gd` was off limits for this task):
- **Failed turn:** `DM.play_turn` returns the message in `errors` (and in a new `status` key). Today's `main.gd` already prints it in the story as "Error: …". Nothing changes in the game state.
- **HUD:** shows the latest own-key message in amber under its buttons, until the next turn starts. It comes from the new `DM.connection_notice` signal. This is the only place the "cut off" warning shows today.
- **`DM.status_changed`:** also carries them, plus "Waiting for the AI DM", for when the status line in `main.gd` is wired to it.

## Debug log

- After each reply: `DM usage (claude-sonnet-5-5): input N, cache read N, cache write N, output N`. If a fallback model served the turn, its name shows instead.
- Warnings start with `Own key:`. For example:
  - `HTTP 401 authentication_error: Invalid bearer token (request-id: req_…)`;
  - `the model declined (category: general_harms)`;
  - `the reply was cut off (max_tokens); its text is kept`;
  - `network error (HTTPRequest result 3)`;
  - `no answer after 90 s`.
- The key never appears. As a safety net, any log line that contains it gets `[key]` instead.
- In the web build these lines go to the browser console (F12).

## Files

| File | What |
|---|---|
| `game/ai/own_key_adapter.gd` | New. The own-key connection (`OwnKeyAdapter`), with the same `generate_turn(prompt)` interface as copy-paste |
| `game/ui/settings_store.gd` | New. `SettingsStore` reads and writes the `[ai]` section (mode, key) and leaves the other sections alone. The language code in `content.gd` is unchanged |
| `game/ui/settings_dialog.gd`, `.tscn` | New. The settings dialog |
| `game/ui/icons/gear.svg` | New. The gear icon: the default font has no ⚙ character, so the web build would show a box. The artist can replace it (same name, about 20×20) |
| `game/ui/hud.gd`, `hud.tscn` | Gear button, "AI: …" line, own-key message line. The dialog sits in a `CanvasLayer` (layer 3) inside the HUD scene |
| `game/autoload/dm.gd` | Reads the settings at each turn and picks the connection. The copy-paste path is unchanged. New `connection_for()` and `connection_notice` |
| `game/content/i18n/strings.csv` | 20 new rows (EN + FR), right after `ui.load` |
| `game/tests/…` | 4 new test files, listed in `run_tests.gd` right after `test_smoke.gd` |
| `.gitignore` | Also ignores `settings.cfg` |

`main.gd`, `prompt_builder.gd`, `dm_reply_parser.gd`, `project.godot` and the specs are untouched. No autoload was added.

## What was tested (2026-11-03, Linux, Godot 4.7.2)

**Automated.** Run with `godot --headless --path game --import`, then `godot --headless --path game --script res://tests/run_tests.gd`.
- Result: `PASS: 18 test file(s)`, with no `SCRIPT ERROR`.
- The other engine warnings are the same as on `Beta-0.2` (from older tests that feed bad input on purpose).
- `python3 tools/content_check.py --check --langs fr,en` passes.

The new tests use no network and the fake key `FAKE-KEY-FOR-TESTS`. Their settings files are `user://__test_*.cfg`, deleted after each run; the real `settings.cfg` is never touched.

| Test file | Checks |
|---|---|
| `unit/test_settings_store.gd` | Round trip of mode and key. The `[general]` language survives. A pasted key loses its spaces and line breaks. An empty key is removed from the file. An unknown mode falls back to copy-paste. `DM.connection_for()` picks the right connection |
| `unit/test_own_key_request.gd` | Headers: Bearer key, version, beta header; the browser header only for web; no `x-api-key`. Model, `max_tokens`, effort low, fallbacks, no sampling settings. Two system blocks with cache markers. The user message has no RULES/CODEX, keeps the prompt order, and system + user rebuild the copy-paste text exactly, even when the lore contains part headers. The key appears only once, in the header. Timeout 90 s |
| `unit/test_own_key_response.gd` | Text (thinking and fallback blocks skipped), refusal (partial text dropped), cut-off (`max_tokens` and `model_context_window_exceeded`: text kept), 401, 500 (code and request id logged), 400/403/404/429/529, timeout, DNS, connection and TLS errors, a reply that isn't JSON, a reply with no text, the usage line, the messages in both languages, and the key scrubbed from logs. Also a no-key turn through the DM: it fails at once with the no-key message. The next turn, in copy-paste mode, still opens the paste dialog |
| `integration/test_settings_dialog.gd` | Gear opens the dialog. The key field is masked. Save. A reopened dialog says a key is saved but never shows it. An empty field keeps the key; a typed key replaces it. Clear (applies at once) and Cancel (saves nothing). The HUD mode line and message line. The dialog follows the language |

**Mutation check.** Eight deliberate bugs, each caught by at least one new test:
- 401 not treated as "refused";
- browser header always sent;
- refusal keeping its text;
- DM ignoring own-key mode;
- the settings write losing the language;
- Clear not removing the key;
- Save with an empty field wiping the key;
- the dialog showing the saved key.

**Desktop checks in the real engine** (scripts outside the repo, not committed):
- **Screenshots** (Xvfb, OpenGL): the HUD and the dialog look right in English and French, at 1280×720.
- **A full DM turn against the real API with the fake key.** The API answered `401 authentication_error: Invalid bearer token`, and the player got "The API key was refused…" in about 80 ms. The game kept running frames, and Godot's log files did not contain the key.
- **DNS failure:** the network message, at once.
- **A local server that accepts the connection and never answers** (timeout lowered to 4 s for the check): `RESULT_TIMEOUT` and the "no answer" message. 573 frames ran during the wait, so the game did not freeze.

**Web build in Chromium.**
- **How it was built:** with the repo's Web preset and the official 4.7.2 no-threads web template, then served from `localhost` with `python -m http.server`.
- **Settings:** language picker, gear, mode list, masked key field, Save, Clear and the reopened dialog all work by mouse and keyboard. The settings file shows up in IndexedDB with the `[ai]` section. After Clear, the key is gone from IndexedDB.
- **Own-key turn with the fake key:**
  - The game sent `authorization`, `anthropic-version`, `anthropic-beta`, `anthropic-dangerous-direct-browser-access`, `content-type` and `accept`. The key was only in `authorization`.
  - The API answered `401` with `access-control-allow-origin: *`, so the game could read it. The story and the HUD said "The API key was refused…". HP and gold did not change, and Act worked again.
  - The browser console showed the 401 warning and never the key.
- **Without the browser-access header**, a page on `localhost` can't read the API's answer at all (checked with a plain `fetch`): that header is required.
- **Browser offline:** "Can't reach the AI service…" in the story and the HUD. The game kept animating and unlocked.
- **Back in copy-paste mode,** Act opens the paste dialog with the prompt, and no API request is made.
- The exported files contain no `sk-ant` string and no `api_key` value.

**Not tested here:**
- a real key (there is none in this environment), so no successful own-key turn, no real `DM usage` line and no real cache numbers;
- Windows and macOS;
- Firefox and Edge.

## Manual checks left for the lead

Type the key at runtime only. Never paste it into a file in the repo, a commit message or a chat.

1. **Real key, editor.**
   - Open the project and press Play. Gear → My own API key → paste → Save. The HUD shows "AI: own key".
   - Type an action, press Act. Expect: no paste dialog, the narration types out and the commands play.
   - The Output panel shows a `DM usage (…)` line.
   - Play a second turn within 5 minutes: `cache read` should be above 0. If it stays at 0, note it for the cost study.
2. **Real key, web build.** Install the web export templates first (Editor → Manage Export Templates), then:

   ```bash
   "$GODOT" --headless --path game --export-release "Web" ../builds/web/index.html
   python -m http.server 8000 --directory builds/web
   ```

   - Open `http://localhost:8000`, set the key in the gear dialog and play a turn.
   - The browser console (F12) shows the `DM usage` line.
   - The browser side (CORS) was already checked here with a fake key, so a failure now most likely means a problem with the key or the account.
3. **Wrong key.** Save a wrong key (change one character) and play a turn.
   - Expect "The API key was refused. Check it in Settings." in the story and in the HUD.
   - HP, gold, place and time do not change. The game is not saved.
4. **Network off.** Turn off Wi-Fi and play a turn in own-key mode.
   - Expect "Can't reach the AI service…" (or, if the connection hangs, "No answer from the AI after 90 seconds" after 90 s).
   - The hero keeps animating the whole time, and Act works again afterwards.
5. **Clear.** Gear → Clear → Cancel. `settings.cfg` (path above) no longer has an `api_key` line. The next own-key turn says "No API key set".
6. **Copy-paste still works.** Switch back to Copy-paste (free) and play one turn with the paste dialog.
7. **No key in the repo:** `git grep -n -E 'sk-ant-[A-Za-z0-9]|api_key *= *"[^"]'` finds nothing. `.gitignore` now also lists `settings.cfg`, in case a copy of the settings file lands in the repo folder.

When checks 1–4 pass, Task 17 can be checked in `tasks/todo.md`. It is still open, because its acceptance needs the real key.

## Known limits and follow-ups

- **Keys not scoped to a workspace.** The API wants an extra `anthropic-workspace-id` header for those and answers `400` without it ("service error (400)"; the log says why). The game doesn't send that header, so players should create a key for one workspace.
- **Action text.** `main.gd` empties the action box when the turn starts. SPEC-main-screen (step 5a) says a failed turn keeps the text. Not changed here, because `main.gd` was off limits.
- **Status line.** `main.gd` doesn't listen to `DM.status_changed` yet.
  - Once it does, it can show `result.status` instead of "Error: …".
  - The HUD message line can then go.
- **No automatic retry** on `429`, `500` or `529`: the player presses Act again.
- **Browser storage on itch.io (check before the first upload).**
  - In the web build the key sits in IndexedDB, which any page on the same address can read.
  - itch.io serves many HTML games from one shared domain. If that is still the case, another game on that domain could read the key.
  - This was not verified. M1 builds stay on `localhost`, so it doesn't apply yet.
- **The key is readable on the device.** Anyone who can open that computer account or browser profile can read the settings file, as for any "bring your own key" app. A key with an expiry date and a spend limit keeps the risk small.
