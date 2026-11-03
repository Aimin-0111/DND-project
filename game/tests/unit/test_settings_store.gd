extends RefCounted
## The [ai] settings round trip, on a test file (never the real settings file),
## and the DM's choice of connection from those settings.

const TEST_PATH := "user://__test_ai_settings.cfg"
const FAKE_KEY := "FAKE-KEY-FOR-TESTS"


func run() -> Array:
	var failures: Array = []
	DirAccess.remove_absolute(TEST_PATH)

	var fresh := SettingsStore.read(TEST_PATH)
	if fresh.mode != SettingsStore.MODE_COPY_PASTE or not fresh.api_key.is_empty():
		failures.append("no file should mean copy-paste and no key, got %s" % fresh.mode)
	if fresh.path != TEST_PATH:
		failures.append("read() should remember its path")

	# The language section written by Content must survive an [ai] write.
	var other := ConfigFile.new()
	other.set_value("general", "language", "en")
	other.save(TEST_PATH)

	var store := SettingsStore.read(TEST_PATH)
	store.mode = SettingsStore.MODE_OWN_KEY
	var pasted := "  " + FAKE_KEY + "\n"
	store.api_key = pasted
	if store.write() != OK:
		failures.append("write() should succeed")
	var back := SettingsStore.read(TEST_PATH)
	if back.mode != SettingsStore.MODE_OWN_KEY or not back.uses_own_key():
		failures.append("mode did not survive the round trip: %s" % back.mode)
	if back.api_key != FAKE_KEY:
		failures.append("the key should come back without the pasted spaces and line break")
	var file := ConfigFile.new()
	file.load(TEST_PATH)
	if file.get_value("general", "language", "") != "en":
		failures.append("writing [ai] lost the [general] language")
	if file.get_value("ai", "api_key", "") != FAKE_KEY:
		failures.append("the key should be stored under [ai] api_key")

	back.api_key = ""
	back.write()
	file = ConfigFile.new()
	file.load(TEST_PATH)
	if file.has_section_key("ai", "api_key"):
		failures.append("an empty key should be removed from the file")
	if SettingsStore.read(TEST_PATH).mode != SettingsStore.MODE_OWN_KEY:
		failures.append("clearing the key should keep the mode")

	file.set_value("ai", "mode", "proxy")
	file.save(TEST_PATH)
	if SettingsStore.read(TEST_PATH).mode != SettingsStore.MODE_COPY_PASTE:
		failures.append("an unknown mode should fall back to copy-paste")

	if SettingsStore.clean_key(" FAKE KEY\tFOR\r\nTESTS ") != "FAKEKEYFORTESTS":
		failures.append("clean_key should drop spaces, tabs and line breaks")
	if SettingsStore.clean_key("abc-DEF_123") != "abc-DEF_123":
		failures.append("clean_key should keep visible characters")

	failures.append_array(_check_connection_choice())
	DirAccess.remove_absolute(TEST_PATH)
	return failures


func _check_connection_choice() -> Array:
	var failures: Array = []
	var dm = (Engine.get_main_loop() as SceneTree).root.get_node("DM")
	var settings := SettingsStore.new()
	settings.mode = SettingsStore.MODE_OWN_KEY
	if dm.connection_for(settings) != dm.own_key:
		failures.append("own-key mode should use the own-key connection")
	settings.mode = SettingsStore.MODE_COPY_PASTE
	if dm.connection_for(settings) != dm.adapter:
		failures.append("copy-paste mode should use the copy-paste connection")
	if dm.connection_for(SettingsStore.read(TEST_PATH + ".missing")) != dm.adapter:
		failures.append("no settings file should mean copy-paste")
	return failures
