extends Control
## The Menu of layout v2, opened by the top bar's Menu button
## (SPEC-main-screen, "Menu"): the AI mode at the top, then Save, Load,
## Language, Codex, AI settings and Close. It owns the settings dialog of M1 (AI mode
## and API key). Esc, Close or a click outside closes it, and so does choosing
## an entry, except a language: the menu stays open in the new language.

signal save_requested
signal load_requested
signal language_chosen(lang: String)
signal codex_requested

@onready var backdrop: Control = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var ai_mode_label: Label = $Panel/Margin/VBox/AiMode
@onready var save_button: Button = $Panel/Margin/VBox/SaveButton
@onready var load_button: Button = $Panel/Margin/VBox/LoadButton
@onready var languages: HBoxContainer = $Panel/Margin/VBox/Languages
@onready var language_label: Label = $Panel/Margin/VBox/Languages/Label
@onready var codex_button: Button = $Panel/Margin/VBox/CodexButton
@onready var ai_settings_button: Button = $Panel/Margin/VBox/AiSettingsButton
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton
@onready var settings_dialog: SettingsDialog = $SettingsLayer/SettingsDialog


func _ready() -> void:
	visible = false
	panel.add_theme_stylebox_override("panel", GameWindow.panel_style())
	# One button per language, each in its own language ("English", "Français").
	for lang in Content.LANGUAGES:
		var button := Button.new()
		button.name = lang
		button.pressed.connect(_on_language.bind(lang))
		languages.add_child(button)
	save_button.pressed.connect(_on_save)
	load_button.pressed.connect(_on_load)
	codex_button.pressed.connect(_on_codex)
	ai_settings_button.pressed.connect(_on_ai_settings)
	close_button.pressed.connect(close)
	backdrop.gui_input.connect(_on_backdrop_input)
	settings_dialog.saved.connect(_refresh_ai_mode)
	Content.language_changed.connect(_on_language_changed)
	_localize()


## Opens the menu with its top-left corner at `at` (under the Menu button)
## when given.
func open(at: Variant = null) -> void:
	if at is Vector2:
		panel.position = at
	_refresh_ai_mode()
	visible = true


func close() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_save() -> void:
	close()
	save_requested.emit()


func _on_load() -> void:
	close()
	load_requested.emit()


func _on_language(lang: String) -> void:
	language_chosen.emit(lang)


func _on_codex() -> void:
	close()
	codex_requested.emit()


func _on_ai_settings() -> void:
	close()
	settings_dialog.open()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


func _on_language_changed(_lang: String) -> void:
	_localize()


func _localize() -> void:
	save_button.text = Content.t("ui.save")
	load_button.text = Content.t("ui.load")
	language_label.text = Content.t("ui.language")
	for lang in Content.LANGUAGES:
		var button: Button = languages.get_node(lang)
		button.text = Content.t_in("ui.language_name", lang)
		button.disabled = lang == Content.language()
	codex_button.text = Content.t("ui.codex")
	ai_settings_button.text = Content.t("ui.ai_settings")
	close_button.text = Content.t("ui.close")
	_refresh_ai_mode()


## "AI: copy-paste" or "AI: own key", from the settings file.
func _refresh_ai_mode() -> void:
	var settings := SettingsStore.read(Content.settings_path)
	ai_mode_label.text = Content.t("ui.hud_ai_own_key" if settings.uses_own_key() else "ui.hud_ai_copy_paste")
