extends Control
## Main shell: 40/60 split (stacked below 900 px), HUD, story panel and the
## copy-paste turn. The world stays in a SubViewport so its camera is isolated.

const SPLIT_RATIO := 0.6
const STACK_BELOW := 900

@onready var split: HSplitContainer = $Split
@onready var stack: VSplitContainer = $Stack
@onready var world_view: SubViewportContainer = $Split/WorldView
@onready var story_panel: PanelContainer = $Split/StoryPanel
@onready var story_log: RichTextLabel = $Split/StoryPanel/VBox/StoryLog
@onready var story_title: Label = $Split/StoryPanel/VBox/Title
@onready var action_input: LineEdit = $Split/StoryPanel/VBox/ActionBar/ActionInput
@onready var act_button: Button = $Split/StoryPanel/VBox/ActionBar/ActButton
@onready var status_label: Label = $Split/StoryPanel/VBox/Status
@onready var dialog: PanelContainer = $DialogLayer/PasteDialog
@onready var director: Node = $Split/WorldView/SubViewport/World/SceneDirector
@onready var hud = $HUDLayer/Hud
@onready var world = $Split/WorldView/SubViewport/World

var _busy := false
var _stacked := false


func _ready() -> void:
	resized.connect(_fit_layout)
	_fit_layout()
	call_deferred("_fit_layout")
	_localize()
	_show_demo_line()

	act_button.pressed.connect(_on_act)
	action_input.text_submitted.connect(func(_text: String) -> void: _on_act())
	dialog.submitted.connect(func(text: String) -> void: DM.submit_reply(text))
	dialog.cancelled.connect(func() -> void: DM.cancel_reply())
	DM.prompt_ready.connect(_on_prompt_ready)
	director.note.connect(_on_note)
	director.roll_requested.connect(_on_roll_requested)
	director.moved_to.connect(Game.set_location)
	hud.language_requested.connect(_on_language_requested)
	hud.save_requested.connect(_on_save)
	hud.load_requested.connect(_on_load)
	Content.language_changed.connect(_on_language_changed)


func _fit_layout() -> void:
	if split == null:
		return
	var stacked := size.x < STACK_BELOW
	_set_stacked(stacked)
	if _stacked:
		# VSplitContainer.split_offset is also relative to the centre.
		stack.split_offset = int(size.y * 0.05)
	else:
		split.split_offset = int(size.x * (SPLIT_RATIO - 0.5))


func _set_stacked(value: bool) -> void:
	if _stacked == value:
		return
	var target: Container = stack if value else split
	world_view.reparent(target)
	story_panel.reparent(target)
	split.visible = not value
	stack.visible = value
	_stacked = value


func _localize() -> void:
	story_title.text = Content.t("ui.title")
	action_input.placeholder_text = Content.t("ui.turn_action")
	act_button.text = Content.t("ui.act")
	status_label.text = Content.t("ui.ready")


func _show_demo_line() -> void:
	var tagger := KeywordTagger.new()
	tagger.load_keywords(Content.keywords(), Content.language())
	var sample := "La braise rouge, le givre bleu et l'éclair blanc."
	if Content.language() == "en":
		sample = "The fire, the frost and the lightning."
	story_log.add_entry(tagger.tag_option_c(sample))


func _on_act() -> void:
	if _busy:
		return
	var action := action_input.text.strip_edges()
	if action.is_empty():
		return
	action_input.text = ""
	story_log.add_plain_line("> " + action)
	_set_busy(true)
	status_label.text = Content.t("ui.waiting")

	var result: Dictionary = await DM.play_turn(action)
	if not bool(result.get("ok", false)):
		_set_busy(false)
		_show_errors(result.get("errors", []))
		return

	var tagger := KeywordTagger.new()
	tagger.load_keywords(Content.keywords(), Content.language())
	story_log.add_entry(tagger.tag_option_c(str(result["narration"])))
	await story_log.finished_typing

	Game.apply_changes(result.get("changes", {}))
	await director.run(result.get("commands", []))

	var error := Game.save("auto")
	if error == OK:
		status_label.text = Content.t("ui.saved")
	else:
		status_label.text = Content.t("ui.save_failed")
		story_log.add_plain_line("%s (%s)." % [Content.t("ui.save_failed"), str(error)])
	_set_busy(false)


func _on_prompt_ready(prompt_text: String) -> void:
	status_label.text = Content.t("ui.waiting")
	dialog.open(prompt_text)


func _on_note(message: String) -> void:
	status_label.text = message


func _on_roll_requested(skill: String, dc: int) -> void:
	status_label.text = "%s: %s (DC %d)" % [Content.t("ui.roll_requested"), skill, dc]
	story_log.add_plain_line("%s: %s (DC %d)." % [Content.t("ui.roll_requested"), skill, dc])


func _on_save() -> void:
	var error := Game.save("manual")
	if error == OK:
		status_label.text = Content.t("ui.saved")
	else:
		status_label.text = Content.t("ui.save_failed")
		story_log.add_plain_line("%s (%s)." % [Content.t("ui.save_failed"), str(error)])


func _on_load() -> void:
	var loaded := Game.load("manual")
	if not loaded:
		loaded = Game.load("auto")
	if not loaded:
		status_label.text = Content.t("ui.no_save")
		return
	_after_load()


func _after_load() -> void:
	_localize()
	var hero = world.get_node("Hero")
	var location := str(Game.state.get("location", "mill_road"))
	var marker := world.get_node_or_null("Locations/" + location) as Marker2D
	if marker != null:
		hero.global_position = marker.global_position
	hero.stop()
	for child in world.get_node("Creatures").get_children():
		child.queue_free()
	status_label.text = Content.t("ui.loaded")
	story_log.add_plain_line(Content.t("ui.loaded"))


func _on_language_requested() -> void:
	Game.set_language("en" if Content.language() == "fr" else "fr")


func _on_language_changed(_lang: String) -> void:
	_localize()


func _show_errors(errors: Array) -> void:
	status_label.text = Content.t("ui.error")
	var message := Content.t("ui.unknown_error")
	if not errors.is_empty():
		message = "; ".join(errors.map(func(error: Variant) -> String: return str(error)))
	story_log.add_plain_line("%s: %s" % [Content.t("ui.error"), message])


func _set_busy(value: bool) -> void:
	_busy = value
	act_button.disabled = value
	action_input.editable = not value
