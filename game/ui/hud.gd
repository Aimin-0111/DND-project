extends PanelContainer
## Top-left HUD: HP, gold, clock, location, AI mode, language and save/load
## actions, and the gear button that opens the settings dialog.

signal language_requested
signal save_requested
signal load_requested

@onready var hp_label: Label = $VBox/HP
@onready var gold_label: Label = $VBox/Gold
@onready var time_label: Label = $VBox/Time
@onready var place_label: Label = $VBox/Place
@onready var ai_mode_label: Label = $VBox/AiMode
@onready var language_button: Button = $VBox/Actions/LanguageButton
@onready var save_button: Button = $VBox/Actions/SaveButton
@onready var load_button: Button = $VBox/Actions/LoadButton
@onready var settings_button: Button = $VBox/Actions/SettingsButton
@onready var ai_notice_label: Label = $VBox/AiNotice
@onready var settings_dialog: SettingsDialog = $SettingsLayer/SettingsDialog


func _ready() -> void:
	Game.state_changed.connect(_refresh)
	Content.language_changed.connect(_on_language_changed)
	DM.connection_notice.connect(_show_notice)
	language_button.pressed.connect(func() -> void: language_requested.emit())
	save_button.pressed.connect(func() -> void: save_requested.emit())
	load_button.pressed.connect(func() -> void: load_requested.emit())
	settings_button.pressed.connect(settings_dialog.open)
	settings_dialog.saved.connect(_on_settings_saved)
	_show_notice("")
	_refresh_language()
	_refresh(Game.state)


func _refresh(state: Dictionary) -> void:
	if state.is_empty():
		return
	var hero: Dictionary = state["hero"]
	hp_label.text = "%s %d/%d" % [Content.t("ui.hp"), int(hero["hp"]), int(hero["hp_max"])]
	gold_label.text = "%s %d" % [Content.t("ui.gold"), int(state["gold"])]
	time_label.text = _clock(int(state["time_minutes"]))
	place_label.text = _place_text(state)


## The place where the hero is; between places (and in generated squares),
## the kind of the square ("Forest" / "Forêt").
func _place_text(state: Dictionary) -> String:
	var location := str(state.get("location", ""))
	if not location.is_empty():
		return Content.t("location.%s.name" % location)
	var kind := Game.square_kind()
	return "" if kind.is_empty() else Content.t("kind.%s.name" % kind)


func _on_language_changed(_lang: String) -> void:
	_refresh_language()
	_refresh(Game.state)


func _refresh_language() -> void:
	language_button.text = Content.language().to_upper()
	save_button.text = Content.t("ui.save")
	load_button.text = Content.t("ui.load")
	settings_button.tooltip_text = Content.t("ui.settings")
	_refresh_ai_mode()


## "AI: copy-paste" or "AI: own key", from the settings file.
func _refresh_ai_mode() -> void:
	var settings := SettingsStore.read(Content.settings_path)
	ai_mode_label.text = Content.t("ui.hud_ai_own_key" if settings.uses_own_key() else "ui.hud_ai_copy_paste")


func _on_settings_saved() -> void:
	_show_notice("")
	_refresh_ai_mode()


## Own-key messages (a failed or cut-off turn), shown until the next turn.
func _show_notice(message: String) -> void:
	ai_notice_label.text = message
	ai_notice_label.visible = not message.is_empty()


func _clock(minutes: int) -> String:
	var hour := (minutes / 60) % 24
	var minute := minutes % 60
	return "%02d:%02d" % [hour, minute]
