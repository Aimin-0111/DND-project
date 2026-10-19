class_name SaveSystem
extends RefCounted
## Save slots as JSON files, with migrations so OLD saves keep loading
## after the game changes.
##
## Where saves go:
##   - Windows desktop build: %APPDATA%/Godot/app_userdata/Brasswake Reach/saves/
##   - Web build: "user://" is stored in the browser (IndexedDB) automatically.
##
## Rule for the team: every time the shape of the state changes,
## bump GameState.VERSION and add one _vN_to_vN+1() function below.

const SAVE_DIR := "user://saves/"


static func save_game(state: Dictionary, slot: String) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(SAVE_DIR + slot + ".json", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state, "\t"))
	return OK


static func load_game(slot: String) -> Dictionary:
	var path := SAVE_DIR + slot + ".json"
	if not FileAccess.file_exists(path):
		return {}
	return import_save_text(FileAccess.get_file_as_string(path))


## Also used by "Import save file": the text comes from the player, so treat
## it as untrusted. Only JSON is accepted, never Godot resource files.
static func import_save_text(text: String) -> Dictionary:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("version"):
		push_warning("Not a Brasswake save file.")
		return {}
	return migrate(data)


static func migrate(data: Dictionary) -> Dictionary:
	# JSON has no integers: every number comes back as a float (3 -> 3.0).
	# Convert numbers you need as int, like the version.
	var v := int(data["version"])
	if v > GameState.VERSION:
		push_warning("This save comes from a newer version of the game.")
		return {}
	while v < GameState.VERSION:
		match v:
			1:
				data = _v1_to_v2(data)
			2:
				data = _v2_to_v3(data)
		v += 1
		data["version"] = v
	return data


## Example: version 1 stored gold inside the hero; version 2 moved it to the top.
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	data["gold"] = data["hero"].get("gold", 0)
	data["hero"].erase("gold")
	return data


## Example: version 3 added the rolling story summary and the action log.
static func _v2_to_v3(data: Dictionary) -> Dictionary:
	data["story_summary"] = data.get("story_summary", "")
	data["log"] = data.get("log", [])
	return data
