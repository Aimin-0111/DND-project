extends PanelContainer
## The top bar of layout v2 (SPEC-main-screen): the Menu button at the left,
## the place · clock · weather in the middle and the Backpack button at the
## right. main.gd opens the menu and the backpack window on its signals. The
## Journal button (M2) joins Backpack at the right.

signal menu_pressed
signal backpack_pressed

@onready var menu_button: Button = $HBox/MenuButton
@onready var backpack_button: Button = $HBox/BackpackButton
@onready var place_label: Label = $HBox/Info/Place
@onready var place_dot: Label = $HBox/Info/PlaceDot
@onready var clock_label: Label = $HBox/Info/Clock
@onready var weather_label: Label = $HBox/Info/Weather


func _ready() -> void:
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	backpack_button.pressed.connect(func() -> void: backpack_pressed.emit())
	Game.state_changed.connect(_refresh)
	Content.language_changed.connect(_on_language_changed)
	_on_language_changed(Content.language())


func _on_language_changed(_lang: String) -> void:
	menu_button.text = Content.t("ui.menu")
	backpack_button.text = Content.t("ui.backpack")
	_refresh(Game.state)


func _refresh(state: Dictionary) -> void:
	if state.is_empty():
		return
	var place := _place_text(state)
	place_label.text = place
	place_label.visible = not place.is_empty()
	place_dot.visible = not place.is_empty()
	clock_label.text = _clock(int(state.get("time_minutes", 0)))
	weather_label.text = Content.t("weather.%s" % str(state.get("weather", "clear")))


## The place where the hero is; between places (and in generated squares),
## the kind of the square ("Forest" / "Forêt").
func _place_text(state: Dictionary) -> String:
	var location := str(state.get("location", ""))
	if not location.is_empty():
		return Content.t("location.%s.name" % location)
	var kind := Game.square_kind()
	return "" if kind.is_empty() else Content.t("kind.%s.name" % kind)


## "Day 1, 08:00": the clock the DM gets in the prompt, in the player's language.
func _clock(minutes: int) -> String:
	var day := minutes / (24 * 60) + 1
	var time := "%02d:%02d" % [(minutes / 60) % 24, minutes % 60]
	return Content.t("ui.clock").format({"day": day, "time": time})
