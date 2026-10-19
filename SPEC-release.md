# Spec: `release` (builds, later itch.io)

*Module of [SPEC.md](SPEC.md). Depends on: `main-screen`. When: M1 (web build played locally), after M1 (private itch.io page, date open), M5 (desktop build, public page).*

## Objective

Turn the project into something the team can play **from one link**, with no install. Each build is checked the same way before anyone plays it, so playtesters never get a broken or unsafe build.

**Decided October 19, 2026: no itch.io upload during M1.** M1 builds are exported for the web and played on the lead's computer from `localhost`. The itch.io steps wait in [When the team wants a link](#when-the-team-wants-a-link-after-m1).

## M1: web build, played locally

| Item | Rule |
|---|---|
| Build | Web export, **single-threaded**, so it will also run on itch.io later without special server settings |
| Included | Everything in `game/src/` and `game/content/` (the CSV and Markdown files must be listed in the export filters), including the diagnostics scene |
| Excluded | `game/tests/`, `examples/`, `docs/`, any `.env` or key file |
| Output | `builds/web/` (git-ignored) |
| Run | `python -m http.server 8000 --directory builds/web`, then open `http://localhost:8000`. A web build can't run from a double-clicked file. `localhost` counts as a secure page, so the clipboard works |
| Version | A label in the settings screen: `M1 build <n> (<git short hash>)` |
| Diagnostics | The web-check scene from the M1 spike (copy, paste, API call, one animated word, fps) stays in the build. Clicking the version label 5 times opens it, to check a new computer or browser quickly |
| Build log | One line per build in `docs/BUILDS.md`: date, build number, git hash, download size, start time, fps measured, notes |

## Checklist before every build

1. All logic tests pass.
2. The content check passes with no errors.
3. The build contains no secret: search the exported files for `sk-ant` and `api_key` values; nothing found.
4. Version label bumped.
5. Manual scene checks from `world`, `narration` and `main-screen` done on the exported build (not only in the editor).
6. One real turn in copy-paste mode and one in own-key mode on the exported build.
7. Build log line written.

## When the team wants a link (after M1)

- **Page:** kind of project HTML; visibility **Restricted** (or draft); viewport 1280×720 with a fullscreen button.
- **Upload:** zip `builds/web/`, upload it on the itch.io dashboard, "This file will be played in the browser".
- **Recheck on the page:**
  - copy and paste inside the page's frame (the diagnostics scene does this in a minute);
  - an own-key turn;
  - the time to the first screen on the school Wi-Fi;
  - whether the school network allows itch.io and the Claude API.
- **The checklist gains a step:** "8. The page is still not public."

## Acceptance criteria

**M1**
- [ ] The exported build starts in current Chrome, Edge and Firefox on Windows, served from `localhost` (Safari: not tested in M1).
- [ ] The time to the first screen is measured with Chrome's "Fast 4G" network throttling and written in the build log; target 10 seconds or less. It stands in for the school Wi-Fi until a hosted build exists.
- [ ] The download size is measured and written in the build log; target 25 MB or less.
- [ ] Content files load in the exported build (an exported build without the CSV/Markdown files must be impossible to miss: the content check runs at start and shows errors).
- [ ] Own-key mode works from the exported build (the API accepts direct calls from the browser).
- [ ] Copy-paste works in the exported build.
- [ ] Clicking the version label 5 times opens the diagnostics scene.

**First itch.io upload (after M1)**
- [ ] The rechecks above pass on the page, and the page is not public.

**M5**
- [ ] Windows desktop build (zip), uploaded to the same page.
- [ ] Public page with screenshots, description (EN + FR) and controls.
- [ ] Uploads with `butler` instead of the dashboard.

## Tests

The checklist above is the test. Steps 1–3 can become one script later.

## Boundaries (module)

- **Always:** run the full checklist; share or upload only builds made from a commit (the hash in the label must exist on GitHub).
- **Ask first:** the first upload, making the page public, changing who can see it, creating accounts, installing `butler`.
- **Never:** put an API key, test key or `.env` file in a build; commit `builds/`.

## Open questions

- Q-6: the itch.io account name for the page, and when the first upload happens.
- Until there is a link, playtests happen on the lead's computer. Who plays first once there is one: only the team, or a few classmates too (password-protected page)?
