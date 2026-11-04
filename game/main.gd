extends Control
## Main shell: 40/60 split (stacked below 900 px), HUD, story panel and the
## copy-paste turn. The world stays in a SubViewport so its camera is isolated.
## A walk that ends on an exit of the square sends the automatic travel turn
## ("I head north (forest).", SPEC-main-screen.md); the DM decides the travel.

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
	# Own-key messages are long: the status line wraps rather than widening
	# the story panel.
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	act_button.pressed.connect(_on_act)
	action_input.text_submitted.connect(func(_text: String) -> void: _on_act())
	dialog.submitted.connect(func(text: String) -> void: DM.submit_reply(text))
	dialog.cancelled.connect(func() -> void: DM.cancel_reply())
	DM.prompt_ready.connect(_on_prompt_ready)
	DM.status_changed.connect(_on_dm_status)
	director.note.connect(_on_note)
	director.roll_requested.connect(_on_roll_requested)
	director.moved_to.connect(Game.set_location)
	world.walk_ended.connect(_on_walk_ended)
	hud.language_requested.connect(_on_language_requested)
	hud.save_requested.connect(_on_save)
	hud.load_requested.connect(_on_load)
	Content.language_changed.connect(_on_language_changed)
	if Content.has_language_choice():
		_start()
	else:
		_ask_language()


## Once the language is known: resume the newer save if there is one (a page
## reload continues the game, bug B8), else the new game's intro line, in the
## language just known (bug B5).
func _start() -> void:
	if _load_newest():
		_after_load(Content.t("ui.resumed"))
		return
	_show_demo_line()


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
	story_log.add_entry(tagger.tag_option_c(Content.t("story.demo_line")))


func _on_act() -> void:
	if _busy:
		return
	var action := action_input.text.strip_edges()
	if action.is_empty():
		return
	_play_turn(action, action, "")


## A walk ended on `cell`: the state takes the tile, and at an exit the DM is
## asked about travel at once, with what the player had typed.
func _on_walk_ended(cell: Vector2i) -> void:
	if _busy:
		return
	Game.set_hero_cell(cell)
	var direction: String = world.exit_at(cell)
	if direction.is_empty():
		return
	var beyond := Game.world_map.neighbour(str(Game.state.get("square", "")), direction)
	if not Game.world_map.can_enter(beyond):
		status_label.text = Content.t("ui.way_blocked")
		Game.set_hero_cell(world.step_back())
		return
	var typed := action_input.text.strip_edges()
	var action := exit_action(direction, Game.world_map.kind_of(beyond))
	if not typed.is_empty():
		action += " " + typed
	_play_turn(action, typed, direction)


## The automatic action at an exit: "I head north (forest)." in the player's language.
func exit_action(direction: String, kind: String) -> String:
	var kind_name := Content.t("kind.%s.name" % kind).to_lower()
	return Content.t("travel." + direction).format({"kind": kind_name})


## One turn. `typed` is what the player wrote (it goes back into the box if
## the turn fails); `exit_direction` is set for the automatic travel turn, and
## the hero then steps back inside the square unless the reply travelled.
func _play_turn(action: String, typed: String, exit_direction: String) -> void:
	action_input.text = ""
	story_log.add_plain_line("> " + action)
	_set_busy(true)
	status_label.text = Content.t("ui.waiting")
	Game.set_hero_cell(world.hero_cell())
	var square_before := str(Game.state.get("square", ""))

	var result: Dictionary = await DM.play_turn(action)
	if not bool(result.get("ok", false)):
		action_input.text = typed
		if not exit_direction.is_empty():
			Game.set_hero_cell(world.step_back())
		_set_busy(false)
		if bool(result.get("cancelled", false)):
			_show_cancelled()
		else:
			_show_failure(result)
		return

	var narration := str(result["narration"])
	if not narration.is_empty():
		var tagger := KeywordTagger.new()
		tagger.load_keywords(Content.keywords(), Content.language())
		story_log.add_entry(tagger.tag_option_c(narration))
		await story_log.finished_typing
		GameState.remember_narration(Game.state, narration)
	# A turn can succeed with a message for the player (own key: the reply was
	# cut off). It stays in the story, under the narration it is about.
	var notice := str(result.get("status", ""))
	if not notice.is_empty():
		story_log.add_plain_line(notice)

	var commands: Array = result.get("commands", [])
	for note in Game.apply_turn(result.get("changes", {}), commands):
		push_warning("Turn: %s" % str(note))
	await director.run(commands)
	Game.set_hero_cell(world.hero_cell())
	if not exit_direction.is_empty() and str(Game.state.get("square", "")) == square_before:
		Game.set_hero_cell(world.step_back())

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


## The connection's messages for the player during a turn ("Waiting for the
## AI DM", why an own-key turn failed, a cut-off reply). Already translated;
## "" means nothing to say.
func _on_dm_status(message: String) -> void:
	if _busy and not message.is_empty():
		status_label.text = message


func _on_note(message: String) -> void:
	status_label.text = message


## The roll already happened in Game.apply_turn; this shows its result.
func _on_roll_requested(_skill: String, _dc: int) -> void:
	var roll: Variant = Game.state.get("last_roll")
	if not (roll is Dictionary):
		return
	var outcome := Content.t("ui.roll_success") if roll["success"] else Content.t("ui.roll_failure")
	var line := "%s: d20 %d %+d = %d (%s %d) - %s" % [
		roll["skill"], roll["d20"], roll["modifier"], roll["total"], Content.t("ui.dc"), roll["dc"], outcome,
	]
	status_label.text = line
	story_log.add_plain_line(line)


func _on_save() -> void:
	if not _busy:
		Game.set_hero_cell(world.hero_cell())
	var error := Game.save("manual")
	if error == OK:
		status_label.text = Content.t("ui.saved")
	else:
		status_label.text = Content.t("ui.save_failed")
		story_log.add_plain_line("%s (%s)." % [Content.t("ui.save_failed"), str(error)])


func _on_load() -> void:
	if not _load_newest():
		status_label.text = Content.t("ui.no_save")
		return
	_after_load(Content.t("ui.loaded"))


## Loads the newer of the manual save and the autosave (bug B7), or the other
## one if the newer doesn't load. A load keeps the language the player picked
## on this device: it is a device setting, not part of the game.
func _load_newest() -> bool:
	var language := Content.language()
	for slot in SaveSystem.slots_newest_first(["manual", "auto"]):
		if Game.load(slot):
			if Content.language() != language:
				Game.set_language(language)
			else:
				Game.state["language"] = language
			return true
	return false


## `story_line`: "Game loaded" after Load, "Game resumed" at start.
func _after_load(story_line: String) -> void:
	_localize()
	world.show_state(Game.state)
	status_label.text = Content.t("ui.loaded")
	story_log.add_plain_line(story_line)


func _on_language_requested() -> void:
	Game.set_language("en" if Content.language() == "fr" else "fr")
	Content.remember_language()


## First launch: the player picks the language before anything else. The
## shade covers the screen so the world can't be clicked meanwhile.
func _ask_language() -> void:
	var picker := ColorRect.new()
	picker.name = "LanguagePicker"
	picker.color = Color(0.0, 0.0, 0.0, 0.6)
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "%s / %s" % [Content.t_in("ui.choose_language", "en"), Content.t_in("ui.choose_language", "fr")]
	box.add_child(title)
	for lang in Content.LANGUAGES:
		var button := Button.new()
		button.name = lang
		button.text = Content.t_in("ui.language_name", lang)
		button.pressed.connect(_on_language_picked.bind(lang, picker))
		box.add_child(button)
	$DialogLayer.add_child(picker)
	_set_busy(true)


func _on_language_picked(lang: String, picker: Control) -> void:
	Game.set_language(lang)
	Content.remember_language()
	picker.queue_free()
	_set_busy(false)
	_start()


func _on_language_changed(_lang: String) -> void:
	_localize()


## A cancelled turn (copy-paste Cancel or Esc) is the player's choice, not an
## error (bug B4): "Turn cancelled." in the story, and the status back to Ready.
func _show_cancelled() -> void:
	status_label.text = Content.t("ui.ready")
	story_log.add_plain_line(Content.t("ui.turn_cancelled"))


## A failed turn. The connection's own message (own key: "No API key set…", or
## the pasted prompt refused) goes on the status line and in the story as it
## is; without one the generic "Error: …" shows.
func _show_failure(result: Dictionary) -> void:
	var status := str(result.get("status", ""))
	if not status.is_empty():
		status_label.text = status
		story_log.add_plain_line(status)
		return
	_show_errors(result.get("errors", []))


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
	world.set_locked(value)
