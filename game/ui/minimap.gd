class_name Minimap
extends MapView
## The minimap at the top right of the world panel: the 7 x 7 squares around
## the hero's square. It redraws on every state change, so after each travel
## and each load. A click opens the world map (main.gd); it never travels.

signal pressed


func _ready() -> void:
	around = 7
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.state_changed.connect(_on_state_changed)
	Content.language_changed.connect(_on_language_changed)
	_on_language_changed(Content.language())
	_on_state_changed(Game.state)


func _on_state_changed(state: Dictionary) -> void:
	refresh(Game.world_map, state)


func _on_language_changed(_lang: String) -> void:
	tooltip_text = Content.t("ui.world_map_hint")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()
