class_name ContentLoader
extends RefCounted
## Loads the teammates' files: CSV tables (numbers) and Markdown (writing).
## Two ways to get them into the game:
##
##   Option A (shown here): read the CSV/Markdown files when the game starts.
##     + Drop a new file in, run the game, done.
##     - A typo (missing column, "1d" instead of "1d6") is only found while playing.
##
##   Option B: a Python tool (tools/balance_sim.py --check) checks the files
##     first and can convert them to JSON. Typos are found before the game runs.
##   Recommended: both. Python checks, Godot loads.
##
## Godot gotchas:
##   - Godot imports .csv files as TRANSLATIONS by default. Select the data
##     CSVs in the FileSystem dock → Import tab → "Import As: Keep File".
##   - Export: add "*.csv, *.md" to "Filters to export non-resource files",
##     or they won't be inside the exported game.


## monsters.csv -> [{"id": "rust_wolf", "hp": 11, "damage": "2d4+2", ...}, ...]
static func load_csv(path: String) -> Array:
	var rows := []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Can't open %s" % path)
		return rows
	var header := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < header.size():
			continue   # empty line at the end of the file
		var row := {}
		for i in header.size():
			row[header[i]] = _typed(line[i])
		rows.append(row)
	return rows


## Turns a table into a lookup by id: by_id(monsters)["rust_wolf"]["hp"]
static func by_id(rows: Array) -> Dictionary:
	var out := {}
	for row in rows:
		out[row["id"]] = row
	return out


## Markdown -> Codex entries. Each "## Title" starts a new entry.
static func load_codex(path: String) -> Array:
	var entries := []
	var current := {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("## "):
			if not current.is_empty():
				entries.append(current)
			current = {"title": line.substr(3).strip_edges(), "text": ""}
		elif not current.is_empty():
			current["text"] += line + "\n"
	if not current.is_empty():
		entries.append(current)
	return entries


## "11" -> 11, "0.5" -> 0.5, "" -> null, anything else stays text.
static func _typed(value: String) -> Variant:
	value = value.strip_edges()
	if value == "":
		return null
	if value.is_valid_int():
		return value.to_int()
	if value.is_valid_float():
		return value.to_float()
	return value
