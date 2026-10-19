class_name ContentLoader
extends RefCounted
## Loads the team's files at runtime: numeric CSV tables and Markdown lore.
## The CSVs are imported as "Keep File" in Godot, not as translations.

## Reads a CSV with a header row. Numbers become int/float, empty cells null.
static func load_csv(path: String) -> Array:
	var rows: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ContentLoader: cannot open %s" % path)
		return rows
	var header := file.get_csv_line()
	if header.is_empty():
		push_warning("ContentLoader: empty CSV %s" % path)
		return rows
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty() or (line.size() == 1 and line[0] == ""):
			continue
		if line.size() < header.size():
			push_warning("ContentLoader: short row in %s" % path)
			continue
		var row := {}
		for i in header.size():
			row[String(header[i])] = _typed(line[i])
		rows.append(row)
	return rows


## Turns rows into a dictionary keyed by id.
static func by_id(rows: Array) -> Dictionary:
	var out := {}
	for row in rows:
		if row is Dictionary and row.has("id"):
			out[String(row["id"])] = row
	return out


## Markdown -> codex entries. Each "## Title" starts a new entry.
static func load_codex(path: String) -> Array:
	var entries: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ContentLoader: cannot open %s" % path)
		return entries
	var current := {}
	for line in file.get_as_text().split("\n"):
		if line.begins_with("## "):
			if not current.is_empty():
				entries.append(current)
			current = {"title": line.substr(3).strip_edges(), "text": ""}
		elif not current.is_empty():
			current["text"] += line + "\n"
	if not current.is_empty():
		entries.append(current)
	return entries


## One Markdown file as plain text, with its "##" headings kept.
static func load_codex_text(path: String) -> String:
	var parts: PackedStringArray = []
	for entry in load_codex(path):
		parts.append("## %s\n%s" % [entry["title"], String(entry["text"]).strip_edges()])
	return "\n\n".join(parts)


## strings.csv -> { key: { "fr": "...", "en": "..." } }
static func load_strings(path: String) -> Dictionary:
	var out := {}
	for row in load_csv(path):
		var key := str(row.get("key", "")).strip_edges()
		if key.is_empty():
			continue
		out[key] = {"fr": str(row.get("fr", "")), "en": str(row.get("en", ""))}
	return out


## Keeps a string as text, then converts integers and floats.
static func _typed(value: String) -> Variant:
	var text := value.strip_edges()
	if text.is_empty():
		return null
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return text
