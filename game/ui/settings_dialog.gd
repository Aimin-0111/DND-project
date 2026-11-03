class_name SettingsDialog
extends Control
## Settings dialog, opened by the HUD's gear button: the AI mode and the
## player's own API key, stored only in the settings file on this device
## (SettingsStore).
##
## The key field is masked and starts empty: a saved key is never shown again,
## only "A key is saved". Save applies the mode, and the key if one was typed
## or pasted (it replaces the saved one); an empty field keeps the saved key.
## Clear removes the saved key at once. Cancel or Esc closes without saving.

signal saved

## The order of the items in the mode list.
const MODES := [SettingsStore.MODE_COPY_PASTE, SettingsStore.MODE_OWN_KEY]

var _has_saved_key := false

@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var mode_label: Label = $Center/Panel/Margin/VBox/ModeLabel
@onready var mode_option: OptionButton = $Center/Panel/Margin/VBox/ModeOption
@onready var key_label: Label = $Center/Panel/Margin/VBox/KeyLabel
@onready var key_field: LineEdit = $Center/Panel/Margin/VBox/KeyRow/KeyField
@onready var clear_button: Button = $Center/Panel/Margin/VBox/KeyRow/ClearButton
@onready var key_note: Label = $Center/Panel/Margin/VBox/KeyNote
@onready var feedback_label: Label = $Center/Panel/Margin/VBox/Feedback
@onready var cancel_button: Button = $Center/Panel/Margin/VBox/Buttons/CancelButton
@onready var save_button: Button = $Center/Panel/Margin/VBox/Buttons/SaveButton


func _ready() -> void:
	visible = false
	key_field.secret = true
	key_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	for mode in MODES:
		mode_option.add_item(mode)
	save_button.pressed.connect(_on_save)
	cancel_button.pressed.connect(close)
	clear_button.pressed.connect(_on_clear)
	key_field.text_submitted.connect(_on_key_submitted)
	Content.language_changed.connect(_on_language_changed)
	_localize()


## Shows the saved mode, and whether a key is saved (never the key itself).
func open() -> void:
	var settings := SettingsStore.read(Content.settings_path)
	mode_option.select(maxi(MODES.find(settings.mode), 0))
	_has_saved_key = not settings.api_key.is_empty()
	key_field.text = ""
	_show_key_hint()
	_show_feedback("")
	visible = true
	key_field.grab_focus()


## Closes without saving and empties the key field.
func close() -> void:
	visible = false
	key_field.text = ""
	_show_feedback("")


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_save() -> void:
	var settings := SettingsStore.read(Content.settings_path)
	settings.mode = MODES[maxi(mode_option.selected, 0)]
	var typed := SettingsStore.clean_key(key_field.text)
	if not typed.is_empty():
		settings.api_key = typed
	if settings.write() != OK:
		_show_feedback(Content.t("ui.save_failed"))
		return
	close()
	saved.emit()


## Clear applies at once, even if the dialog is then cancelled: the player
## asked for the key to be gone from this device. The saved mode stays.
func _on_clear() -> void:
	key_field.text = ""
	var settings := SettingsStore.read(Content.settings_path)
	settings.api_key = ""
	if settings.write() != OK:
		_show_feedback(Content.t("ui.save_failed"))
		return
	_has_saved_key = false
	_show_key_hint()
	_show_feedback(Content.t("ui.key_cleared"))


func _on_key_submitted(_text: String) -> void:
	_on_save()


func _on_language_changed(_lang: String) -> void:
	_localize()


func _localize() -> void:
	title_label.text = Content.t("ui.settings")
	mode_label.text = Content.t("ui.ai_mode")
	mode_option.set_item_text(0, Content.t("ui.ai_mode_copy_paste"))
	mode_option.set_item_text(1, Content.t("ui.ai_mode_own_key"))
	key_label.text = Content.t("ui.api_key")
	clear_button.text = Content.t("ui.clear")
	key_note.text = Content.t("ui.api_key_note")
	cancel_button.text = Content.t("ui.cancel")
	save_button.text = Content.t("ui.settings_save")
	_show_key_hint()


## The empty field's hint: whether a key is already saved on this device.
func _show_key_hint() -> void:
	key_field.placeholder_text = Content.t("ui.api_key_saved" if _has_saved_key else "ui.api_key_placeholder")


func _show_feedback(message: String) -> void:
	feedback_label.text = message
	feedback_label.visible = not message.is_empty()
