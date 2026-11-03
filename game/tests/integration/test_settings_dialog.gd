extends RefCounted
## The HUD's gear button and the settings dialog, on a test settings file:
## masked key field, Save, Clear, Cancel, the HUD's AI mode line and notice.

const TEST_SETTINGS := "user://__test_settings_dialog.cfg"
const FAKE_KEY := "FAKE-KEY-FOR-TESTS"


func run() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["no SceneTree available"]
	var content = tree.root.get_node("Content")
	var dm = tree.root.get_node("DM")
	var real_settings: String = content.settings_path
	var start_language: String = content.language()
	content.settings_path = TEST_SETTINGS
	DirAccess.remove_absolute(TEST_SETTINGS)

	var hud = load("res://ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	var gear: Button = hud.get_node("VBox/Actions/SettingsButton")
	var mode_line: Label = hud.get_node("VBox/AiMode")
	var notice: Label = hud.get_node("VBox/AiNotice")
	var dialog: Control = hud.get_node("SettingsLayer/SettingsDialog")
	var mode_option: OptionButton = dialog.get_node("Center/Panel/Margin/VBox/ModeOption")
	var key_field: LineEdit = dialog.get_node("Center/Panel/Margin/VBox/KeyRow/KeyField")
	var feedback: Label = dialog.get_node("Center/Panel/Margin/VBox/Feedback")

	if gear.icon == null or not gear.text.is_empty():
		failures.append("the gear button should be an icon (the font has no gear glyph)")
	if dialog.visible:
		failures.append("the settings dialog should start hidden")
	if mode_line.text != content.t("ui.hud_ai_copy_paste"):
		failures.append("the HUD should show copy-paste mode by default, got '%s'" % mode_line.text)

	gear.pressed.emit()
	if not dialog.visible:
		failures.append("the gear button should open the settings dialog")
	if not key_field.secret:
		failures.append("the key field must be masked")
	if mode_option.selected != 0 or not key_field.text.is_empty():
		failures.append("a fresh dialog should show copy-paste and no key")
	if key_field.placeholder_text != content.t("ui.api_key_placeholder"):
		failures.append("with no saved key, the field should ask for one")
	var note: Label = dialog.get_node("Center/Panel/Margin/VBox/KeyNote")
	if note.text != content.t("ui.api_key_note"):
		failures.append("the 'stored only on this device' note is missing")

	mode_option.select(1)
	key_field.text = FAKE_KEY
	dialog.get_node("Center/Panel/Margin/VBox/Buttons/SaveButton").pressed.emit()
	var saved := SettingsStore.read(TEST_SETTINGS)
	if saved.mode != SettingsStore.MODE_OWN_KEY or saved.api_key != FAKE_KEY:
		failures.append("Save should store own-key mode and the key")
	if dialog.visible or not key_field.text.is_empty():
		failures.append("Save should close the dialog and empty the key field")
	if mode_line.text != content.t("ui.hud_ai_own_key"):
		failures.append("the HUD should show own-key mode after Save")

	gear.pressed.emit()
	if mode_option.selected != 1:
		failures.append("reopening should show the saved mode")
	if not key_field.text.is_empty() or key_field.placeholder_text != content.t("ui.api_key_saved"):
		failures.append("reopening should say a key is saved, never show the key")
	dialog.get_node("Center/Panel/Margin/VBox/Buttons/SaveButton").pressed.emit()
	if SettingsStore.read(TEST_SETTINGS).api_key != FAKE_KEY:
		failures.append("Save with an empty field should keep the saved key")

	gear.pressed.emit()
	var replacement := FAKE_KEY + "-2"
	key_field.text = replacement
	dialog.get_node("Center/Panel/Margin/VBox/Buttons/SaveButton").pressed.emit()
	if SettingsStore.read(TEST_SETTINGS).api_key != replacement:
		failures.append("a typed key should replace the saved one")

	gear.pressed.emit()
	dialog.get_node("Center/Panel/Margin/VBox/KeyRow/ClearButton").pressed.emit()
	if SettingsStore.read(TEST_SETTINGS).api_key != "" or not key_field.text.is_empty():
		failures.append("Clear should remove the key from the file at once")
	if SettingsStore.read(TEST_SETTINGS).mode != SettingsStore.MODE_OWN_KEY:
		failures.append("Clear should keep the saved mode")
	if not feedback.visible or feedback.text != content.t("ui.key_cleared"):
		failures.append("Clear should say the key was removed")
	if key_field.placeholder_text != content.t("ui.api_key_placeholder"):
		failures.append("after Clear, the field should ask for a key again")

	mode_option.select(0)
	key_field.text = "NOT-SAVED"
	dialog.get_node("Center/Panel/Margin/VBox/Buttons/CancelButton").pressed.emit()
	var after_cancel := SettingsStore.read(TEST_SETTINGS)
	if dialog.visible or after_cancel.mode != SettingsStore.MODE_OWN_KEY or after_cancel.api_key != "":
		failures.append("Cancel should close without saving")

	dm.connection_notice.emit("Test notice")
	if not notice.visible or notice.text != "Test notice":
		failures.append("the HUD should show the own-key notice")
	dm.connection_notice.emit("")
	if notice.visible:
		failures.append("an empty notice should hide it")

	var other := "en" if start_language == "fr" else "fr"
	content.set_language(other)
	var title: Label = dialog.get_node("Center/Panel/Margin/VBox/Title")
	if title.text != content.t_in("ui.settings", other) or mode_option.get_item_text(1) != content.t_in("ui.ai_mode_own_key", other):
		failures.append("the dialog should follow the language")
	content.set_language(start_language)

	tree.root.remove_child(hud)
	hud.free()
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.settings_path = real_settings
	return failures
