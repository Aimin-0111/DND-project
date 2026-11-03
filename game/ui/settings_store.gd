class_name SettingsStore
extends RefCounted
## The AI part of the device settings file: section [ai] of user://settings.cfg,
## with the AI mode and the player's own API key. The key lives only in this
## file, on the player's device (in the browser's storage for the web version):
## never in a save, a log, the prompt or a build.
## Other sections, such as the language that Content keeps, are left as they are.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "ai"
const MODE_COPY_PASTE := "copy_paste"
const MODE_OWN_KEY := "own_key"
const MODES := [MODE_COPY_PASTE, MODE_OWN_KEY]

## Where the file lives. Tests use their own file, never the real one.
var path := DEFAULT_PATH
## Copy-paste is the free default and the safety net that always works.
var mode := MODE_COPY_PASTE
var api_key := ""


## Reads the [ai] section. A missing file, a missing value or an unknown mode
## gives the defaults: copy-paste mode and no key.
static func read(settings_path: String = DEFAULT_PATH) -> SettingsStore:
	var store := SettingsStore.new()
	store.path = settings_path
	var file := ConfigFile.new()
	if file.load(settings_path) != OK:
		return store
	var saved_mode := str(file.get_value(SECTION, "mode", MODE_COPY_PASTE))
	store.mode = saved_mode if saved_mode in MODES else MODE_COPY_PASTE
	store.api_key = clean_key(str(file.get_value(SECTION, "api_key", "")))
	return store


## Writes the [ai] section and keeps every other section of the file.
## An empty key is removed from the file rather than stored as "".
func write() -> Error:
	var file := ConfigFile.new()
	file.load(path)  # Keeps the other sections; fails harmlessly the first time.
	file.set_value(SECTION, "mode", mode if mode in MODES else MODE_COPY_PASTE)
	var key := clean_key(api_key)
	if not key.is_empty():
		file.set_value(SECTION, "api_key", key)
	elif file.has_section_key(SECTION, "api_key"):
		file.erase_section_key(SECTION, "api_key")
	return file.save(path)


func uses_own_key() -> bool:
	return mode == MODE_OWN_KEY


## Keeps only the visible ASCII characters of a pasted key. Spaces, tabs and
## line breaks come from copying, and would also break the HTTP header.
static func clean_key(text: String) -> String:
	var invisible := RegEx.create_from_string("[^!-~]")
	return invisible.sub(text, "", true)
