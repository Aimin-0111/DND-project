extends PanelContainer
## Top-left HUD: HP, gold, clock, location, language and save/load actions.

signal language_requested
signal save_requested
signal load_requested

@onready var hp_label: Label = $VBox/HP
@onready var gold_label: Label = $VBox/Gold
@onready var time_label: Label = $VBox/Time
@onready var place_label: Label = $VBox/Place
@onready var language_button: Button = $VBox/Actions/LanguageButton
@onready var save_button: Button = $VBox/Actions/SaveButton
@onready var load_button: Button = $VBox/Actions/LoadButton


func _ready() -> void:
	Game.state_changed.connect(_refresh)
	Content.language_changed.connect(_on_language_changed)
	language_button.pressed.connect(func() -> void: language_requested.emit())
	save_button.pressed.connect(func() -> void: save_requested.emit())
	load_button.pressed.connect(func() -> void: load_requested.emit())
	_refresh_language()
	_refresh(Game.state)


func _refresh(state: Dictionary) -> void:
	if state.is_empty():
		return
	var hero: Dictionary = state["hero"]
	hp_label.text = "%s %d/%d" % [Content.t("ui.hp"), int(hero["hp"]), int(hero["hp_max"])]
	gold_label.text = "%s %d" % [Content.t("ui.gold"), int(state["gold"])]
	time_label.text = _clock(int(state["time_minutes"]))
	place_label.text = Content.t("location.%s.name" % str(state["location"]))


func _on_language_changed(_lang: String) -> void:
	_refresh_language()
	_refresh(Game.state)


func _refresh_language() -> void:
	language_button.text = Content.language().to_upper()
	save_button.text = Content.t("ui.save")
	load_button.text = Content.t("ui.load")


func _clock(minutes: int) -> String:
	var hour := (minutes / 60) % 24
	var minute := minutes % 60
	return "%02d:%02d" % [hour, minute]
