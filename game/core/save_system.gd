class_name SaveSystem
extends RefCounted
## JSON save slots under user://saves/, with a migration hook for later state
## shapes. Never load a .tres as a save: resource files can contain code.

const SAVE_DIR := "user://saves/"
const SLOT_RE := "^[a-z0-9_-]{1,32}$"


static func save_game(state: Dictionary, slot: String) -> Error:
	if not _valid_slot(slot):
		push_error("SaveSystem: invalid slot '%s'" % slot)
		return ERR_INVALID_PARAMETER
	var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		push_error("SaveSystem: cannot create %s" % SAVE_DIR)
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
			_:
				push_warning("SaveSystem: no migration from version %d" % version)
				return {}
		version += 1
		data["version"] = version
	return GameState.fill_defaults(data)


static func _valid_slot(slot: String) -> bool:
	var re := RegEx.new()
	re.compile(SLOT_RE)
	return re.search(slot) != null


static func _path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"
