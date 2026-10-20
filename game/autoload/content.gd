extends Node
## Autoload: content tables, bilingual strings, lore, keywords and allowed ids.
## The language can change at runtime without reloading the scene.

signal language_changed(language: String)

const LANGUAGES := ["fr", "en"]
const DATA_DIR := "res://content/data/"
const WRITING_DIR := "res://content/writing/"
const STRINGS_PATH := "res://content/i18n/strings.csv"
const RULES_PATH := "res://content/writing/dm-rules.md"
const TABLES := ["monsters", "items", "locations", "quests", "keywords"]

## Device settings, never in a save. Tests point this elsewhere.
var settings_path := "user://settings.cfg"

var _language := "fr"
var _strings: Dictionary = {}
var _tables: Dictionary = {}
var _keywords: Array = []
var _codex: PackedStringArray = []
var _rules := ""
var _loaded := false


func _ready() -> void:
	_ensure_loaded()


## Loads once on first use. This also makes the content available to headless
## tests that run before the scene tree has emitted _ready on the autoload.
func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_language = _default_language()
	_strings = ContentLoader.load_strings(STRINGS_PATH)
	for table_name in TABLES:
		_tables[table_name] = ContentLoader.load_csv(DATA_DIR + table_name + ".csv")
	_rules = _read_text(RULES_PATH)
	_apply_language(_language)


func language() -> String:
	_ensure_loaded()
	return _language


func set_language(lang: String) -> void:
	_ensure_loaded()
	_apply_language(lang)


func _apply_language(lang: String) -> void:
	if not lang in LANGUAGES:
		push_error("Content: unsupported language '%s'" % lang)
		return
	_language = lang
	_keywords = []
	for row in _tables.get("keywords", []):
		if str(row.get("lang", "")) == lang:
			_keywords.append(row)
	_codex = _load_codex(lang)
	language_changed.emit(lang)


## Visible text for a key. Missing keys return the key and warn.
func t(key: String) -> String:
	return t_in(key, language())


## Same, in a given language (the first-launch picker shows both).
func t_in(key: String, lang: String) -> String:
	_ensure_loaded()
	var entry: Variant = _strings.get(key)
	if not (entry is Dictionary):
		push_warning("Content: missing key '%s'" % key)
		return key
	var value := str(entry.get(lang, ""))
	if value.is_empty():
		push_warning("Content: missing %s for '%s'" % [lang, key])
		return key
	return value


## True once the player picked a language (first launch asks).
func has_language_choice() -> bool:
	var settings := ConfigFile.new()
	return settings.load(settings_path) == OK and settings.has_section_key("general", "language")


func remember_language() -> void:
	var settings := ConfigFile.new()
	settings.load(settings_path)
	settings.set_value("general", "language", language())
	settings.save(settings_path)


func table(name: String) -> Array:
	_ensure_loaded()
	return _tables.get(name, [])


func find(name: String, id: String) -> Dictionary:
	for row in table(name):
		if str(row.get("id", "")) == id:
			return row
	return {}


func allowed_ids() -> Dictionary:
	_ensure_loaded()
	return {
		"locations": _ids("locations"),
		"creatures": _ids("monsters"),
		"items": _ids("items"),
		"quests": _ids("quests"),
		"npcs": _npc_ids(),
	}


func keywords() -> Array:
	_ensure_loaded()
	return _keywords


func codex_text() -> String:
	_ensure_loaded()
	return "\n\n".join(_codex)


func rules() -> String:
	_ensure_loaded()
	return _rules


func _ids(table_name: String) -> Array:
	var out: Array = []
	for row in table(table_name):
		var id := str(row.get("id", ""))
		if not id.is_empty():
			out.append(id)
	return out


## Writing entries carry an "- **Id** : <id>" line. Ids that aren't places
## are characters: the allowed "who" of an emote.
func _npc_ids() -> Array:
	var re := RegEx.new()
	re.compile("\\*\\*(?:Id|Identifiant)\\*\\*\\s*:\\s*([a-z0-9_]+)")
	var places := _ids("locations")
	var out: Array = []
	for match in re.search_all(codex_text()):
		var id := match.get_string(1)
		if not id in places and not id in out:
			out.append(id)
	return out


func _load_codex(lang: String) -> PackedStringArray:
	var entries := PackedStringArray()
	var folder := WRITING_DIR + lang + "/"
	var dir := DirAccess.open(folder)
	if dir == null:
		push_error("Content: cannot open lore folder %s" % folder)
		return entries
	var names := dir.get_files()
	names.sort()
	for name in names:
		if name.ends_with(".md"):
			entries.append(ContentLoader.load_codex_text(folder + name))
	return entries


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Content: cannot open %s" % path)
		return ""
	return file.get_as_text()


## The saved choice, else the system language, else English.
func _default_language() -> String:
	var settings := ConfigFile.new()
	if settings.load(settings_path) == OK:
		var saved := str(settings.get_value("general", "language", ""))
		if saved in LANGUAGES:
			return saved
	return "fr" if OS.get_locale_language() == "fr" else "en"
