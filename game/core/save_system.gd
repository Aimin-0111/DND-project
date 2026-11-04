class_name SaveSystem
extends RefCounted
## JSON save slots under user://saves/, with a migration hook for later state
## shapes. Never load a .tres as a save: resource files can contain code.

const SAVE_DIR := "user://saves/"
const SLOT_RE := "^[a-z0-9_-]{1,32}$"

## Where the slots live. The test runner points this at a test folder, so the
## tests never touch the player's own saves.
static var save_dir := SAVE_DIR


static func save_game(state: Dictionary, slot: String) -> Error:
	if not _valid_slot(slot):
		push_error("SaveSystem: invalid slot '%s'" % slot)
		return ERR_INVALID_PARAMETER
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		push_error("SaveSystem: cannot create %s" % save_dir)
		return err
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot write %s" % _path(slot))
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state, "\t"))
	return OK


static func load_game(slot: String) -> Dictionary:
	if not _valid_slot(slot):
		push_error("SaveSystem: invalid slot '%s'" % slot)
		return {}
	var path := _path(slot)
	if not FileAccess.file_exists(path):
		return {}
	return import_save_text(FileAccess.get_file_as_string(path))


## The slots of `slots` that have a save file, the last written first (Load
## and Resume take the first that loads). File times have one-second steps: on
## a tie the slot that comes first in `slots` stays first.
static func slots_newest_first(slots: Array) -> Array:
	var found: Array = []
	for slot in slots:
		var name := str(slot)
		if _valid_slot(name) and FileAccess.file_exists(_path(name)):
			found.append({"slot": name, "time": FileAccess.get_modified_time(_path(name)), "order": found.size()})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["time"] != b["time"]:
			return a["time"] > b["time"]
		return a["order"] < b["order"])
	return found.map(func(entry: Dictionary) -> String: return entry["slot"])


static func delete_save(slot: String) -> void:
	if _valid_slot(slot) and FileAccess.file_exists(_path(slot)):
		DirAccess.remove_absolute(_path(slot))


## Used by "Import save file": the text comes from the player, so it is
## untrusted. Only JSON is accepted, never a Godot resource.
static func import_save_text(text: String) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary) or not data.has("version"):
		push_warning("SaveSystem: not a Brasswake save file")
		return {}
	return migrate(data)


static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version > GameState.VERSION:
		push_warning("SaveSystem: save is from a newer game version")
		return {}
	if version < 1:
		push_warning("SaveSystem: unsupported save version %d" % version)
		return {}
	while version < GameState.VERSION:
		match version:
			1:
				data = _v1_to_v2(data)
			_:
				push_warning("SaveSystem: no migration from version %d" % version)
				return {}
		version += 1
		data["version"] = version
	return GameState.fill_defaults(data)


## Version 1 (Beta-0.1/0.2, one zone) -> 2 (Beta-0.3, a grid of squares).
## The square and the hero's tile can't be known without the map: they stay
## empty here and WorldState.settle fills them from the v1 location (and each
## creature's square from its place) once the map is loaded.
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	data["square"] = ""
	data["hero_cell"] = []
	data["squares"] = {}
	var creatures: Variant = data.get("creatures")
	if creatures is Array:
		for creature in creatures:
			if creature is Dictionary:
				creature["square"] = ""
	return data


static func _valid_slot(slot: String) -> bool:
	var re := RegEx.new()
	re.compile(SLOT_RE)
	return re.search(slot) != null


static func _path(slot: String) -> String:
	return save_dir + slot + ".json"
