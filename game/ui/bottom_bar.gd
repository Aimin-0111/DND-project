extends PanelContainer
## The bottom bar of layout v2 (SPEC-main-screen, "Bottom bar"): the HP bar
## and the gold, refreshed on every state change. T3 adds the Steam and XP
## bars after HP (more StatBar instances) and the hotbar in Middle.

@onready var hp_bar: StatBar = $HBox/HP
@onready var gold_label: Label = $HBox/Gold


func _ready() -> void:
	Game.state_changed.connect(_refresh)
	Content.language_changed.connect(_on_language_changed)
	_refresh(Game.state)


func _on_language_changed(_lang: String) -> void:
	_refresh(Game.state)


func _refresh(state: Dictionary) -> void:
	if state.is_empty():
		return
	var hero: Dictionary = state["hero"]
	hp_bar.show_value(Content.t("ui.hp"), int(hero["hp"]), int(hero["hp_max"]))
	gold_label.text = "%s %d" % [Content.t("ui.gold"), int(state["gold"])]
