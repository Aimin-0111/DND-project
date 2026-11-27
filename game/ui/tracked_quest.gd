class_name TrackedQuest
extends Label
## The tracked quest at the top left of the world panel (SPEC-main-screen,
## "Tracked quest"): the first unfinished quest's title, then the text of its
## current stage, in the current language; hidden when no quest is running.
## "First" follows the order of quests.csv, so it stays the same after a load
## (saves sort their keys). Clicks go through to the world until the Journal
## exists (M2).

## Room kept free at the right of the world panel for the minimap.
const RIGHT_ROOM := 128.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.78)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	add_theme_stylebox_override("normal", style)
	get_parent().resized.connect(_fit)
	Game.state_changed.connect(_refresh)
	Content.language_changed.connect(_on_language_changed)
	_refresh(Game.state)


func _on_language_changed(_lang: String) -> void:
	_refresh(Game.state)


func _refresh(state: Dictionary) -> void:
	var quest := first_unfinished(state)
	visible = not quest.is_empty()
	if quest.is_empty():
		return
	text = Content.t("ui.tracked_quest").format({
		"title": Content.t("quest.%s.title" % quest["id"]),
		"stage": Content.t("quest.%s.stage%d" % [quest["id"], quest["stage"]]),
	})
	_fit()


## {"id", "stage"} of the first unfinished quest of the state, in the order
## of quests.csv, or {} when none is running. Broken entries are skipped.
static func first_unfinished(state: Dictionary) -> Dictionary:
	var quests: Variant = state.get("quests")
	if not (quests is Dictionary):
		return {}
	for row in Content.table("quests"):
		var id := str(row.get("id", ""))
		var entry: Variant = quests.get(id)
		if not (entry is Dictionary):
			continue
		var done: Variant = entry.get("done", false)
		var stage: Variant = entry.get("stage", 0)
		if (done is bool and done) or not (stage is int or stage is float):
			continue
		return {"id": id, "stage": int(stage)}
	return {}


## As wide as its text, but never under the minimap: a longer text ends with "…".
func _fit() -> void:
	var font := get_theme_font("font")
	var wanted := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x
	wanted += get_theme_stylebox("normal").get_minimum_size().x + 1.0
	var room := maxf(get_parent_area_size().x - position.x - RIGHT_ROOM, 40.0)
	size = Vector2(minf(wanted, room), 0.0)
