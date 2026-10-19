# Content files

Everything the writer and the artist edit lives here. The game reads these
files at startup; no code change is needed for a new name, place or lore entry.

## Folders

- `data/*.csv` — numbers only, language-neutral. See `tools/content_check.py`
  for the required columns.
- `i18n/strings.csv` — `key,fr,en`, one row per visible string.
- `writing/dm-rules.md` — stable instructions sent to the AI DM.
- `writing/fr/` and `writing/en/` — matching Markdown lore files.
- `art/` — PNG/Aseprite assets and `CREDITS.md`.

## Godot import settings

- All CSV files must be imported as **Keep File**, not as translations.
- Markdown files are non-resource files: keep `*.csv, *.md` in the export
  filter (see `game/export_presets.cfg`).
- The `.import` files that carry these settings are committed.

## Check before running the game

```bash
python3 tools/content_check.py --check --langs fr,en
```

The command fails on a missing column, duplicate id, bad dice notation, missing
FR/EN value, missing keyword pair or unmatched lore file.
