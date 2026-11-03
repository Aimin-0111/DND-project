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
- `maps/` — the world map (`world.png`, one pixel per square), the colour
  tables `kinds.csv` and `tiles.csv`, `squares.csv` and the hand-made
  squares in `squares/` (64 × 64 PNGs, one pixel per tile). Guide for the
  artist (French): `docs/GUIDE-CARTES.md`. Rules: `SPEC-map.md`.

## Godot import settings

- All CSV files must be imported as **Keep File**, not as translations.
- The PNGs in `maps/` are imported as **Image** (Import As: Image) so the
  game can read their pixels in an exported build.
- Markdown files are non-resource files: keep `*.csv, *.md` in the export
  filter (see `game/export_presets.cfg`).
- The `.import` files that carry these settings are committed.

## Check before running the game

```bash
python3 tools/content_check.py --check --langs fr,en
```

The command fails on a missing column, duplicate id, bad dice notation, missing
FR/EN value, missing keyword pair or unmatched lore file, and on map problems:
unknown colours (with the pixel position), wrong image sizes, markers outside
their square or on blocked tiles, hand-made squares off the world map. Exits
facing a square the hero can't enter are warnings. Its own tests:
`python3 tools/test_content_check.py`.
