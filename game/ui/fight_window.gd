class_name FightWindow
extends GameWindow
## The fight screen (SPEC-fight.md): the hero and the creature face to face
## with their HP bars, the dice of the last roll, a log of the rounds and the
## actions Attack, Guard, Potion and Flee (also keys 1-4). Bosses get a red
## frame, a bigger picture and can't be fled from. The rules are core's Fight;
## this window only shows it. It can't be closed while the fight runs: once
## it is over, Continue (or Enter) closes it and `finished` gives the Fight
## back to main.gd, which writes the end into the state.

signal finished(fight: Fight)

const HERO_TEXTURE := preload("res://content/art/hero.png")
const CREATURE_ART := "res://content/art/creature-%s.png"
const PORTRAIT := Vector2(112, 112)
const BOSS_PORTRAIT := Vector2(160, 160)
const ROLL_SECONDS := 0.35
const BOSS_COLOUR := Color(0.85, 0.22, 0.18)
const HERO_COLOUR := "#9fd8a8"
const MONSTER_COLOUR := "#f0a080"

var fight: Fight
var hero_picture: TextureRect
var monster_picture: TextureRect
var hero_bar: StatBar
var monster_bar: StatBar
var monster_name: Label
var hero_name: Label
var dice_label: Label
var log_label: RichTextLabel
var actions: HBoxContainer
var buttons := {}
var continue_button: Button
var _animating := false


func _init() -> void:
	super()
	title_key = "fight.title"
	panel_size = Vector2(600, 470)


func _ready() -> void:
	super()
	close_button.visible = false
	var arena := HBoxContainer.new()
	arena.name = "Arena"
	arena.alignment = BoxContainer.ALIGNMENT_CENTER
	arena.add_theme_constant_override("separation", 24)
	body.add_child(arena)
	var hero_side := _side(arena, "Hero")
	hero_picture = hero_side[0]
	hero_name = hero_side[1]
	hero_bar = hero_side[2]
	var middle := VBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.custom_minimum_size = Vector2(150, 0)
	arena.add_child(middle)
	dice_label = Label.new()
	dice_label.name = "Dice"
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.add_theme_font_size_override("font_size", 28)
	dice_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	middle.add_child(dice_label)
	var monster_side := _side(arena, "Monster")
	monster_picture = monster_side[0]
	monster_name = monster_side[1]
	monster_bar = monster_side[2]
	log_label = RichTextLabel.new()
	log_label.name = "Log"
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.custom_minimum_size = Vector2(0, 110)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(log_label)
	actions = HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	body.add_child(actions)
	for action in Fight.ACTIONS:
		var button := Button.new()
		button.name = action.capitalize()
		button.custom_minimum_size = Vector2(110, 34)
		button.pressed.connect(choose.bind(action))
		actions.add_child(button)
		buttons[action] = button
	continue_button = Button.new()
	continue_button.name = "Continue"
	continue_button.custom_minimum_size = Vector2(160, 34)
	continue_button.pressed.connect(_on_continue)
	actions.add_child(continue_button)
	_localize()


## A picture, a name and an HP bar under it.
func _side(parent: Control, side_name: String) -> Array:
	var box := VBoxContainer.new()
	box.name = side_name
	box.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(box)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.custom_minimum_size = PORTRAIT
	box.add_child(picture)
	var label := Label.new()
	label.name = "Name"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var bar: StatBar = preload("res://ui/stat_bar.tscn").instantiate()
	bar.name = "HP"
	bar.custom_minimum_size = Vector2(170, 0)
	box.add_child(bar)
	return [picture, label, bar]


## Shows a new fight and opens the window.
func start(new_fight: Fight) -> void:
	fight = new_fight
	log_label.clear()
	dice_label.text = "VS"
	var hero_frame := AtlasTexture.new()
	hero_frame.atlas = HERO_TEXTURE
	hero_frame.region = Rect2(0, 0, 32, 32)
	hero_picture.texture = hero_frame
	hero_picture.modulate = Color.WHITE
	var art := CREATURE_ART % fight.monster_id.replace("_", "-")
	monster_picture.texture = load(art) if ResourceLoader.exists(art) else null
	monster_picture.modulate = Color.WHITE
	monster_picture.custom_minimum_size = BOSS_PORTRAIT if fight.boss else PORTRAIT
	var style := GameWindow.panel_style()
	if fight.boss:
		style.border_color = BOSS_COLOUR
		style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)
	_localize()
	_add_line(Content.t("fight.boss_intro" if fight.boss else "fight.intro").format({"name": _monster_name()}), "#e0b36a")
	_update()
	open()


## One action: the round is played by core, then shown with a short dice
## roll and the hits. Ignored while the last round still shows or when over.
func choose(action: String) -> void:
	if fight == null or fight.is_over() or _animating or not visible:
		return
	var events := fight.act(action)
	_animating = true
	_set_buttons_enabled(false)
	for event in events:
		await _show_event(event)
	_animating = false
	# The bottom bar and the rest of the screen show the new HP at once.
	Game.changed()
	_update()



func _show_event(event: Dictionary) -> void:
	if event.has("d20"):
		await _roll_dice(int(event["d20"]))
	var who := str(event.get("who", ""))
	var kind := str(event.get("kind", ""))
	var values := event.duplicate()
	values["name"] = _monster_name()
	var key := "fight.%s_%s" % [who, kind]
	if kind == "special":
		key = "fight.special.%s" % str(event.get("special", ""))
	elif kind == "charging":
		key = "fight.charge.%s" % str(event.get("special", ""))

	var text := Content.t(key).format(values)
	if kind == "special" and bool(event.get("guarded", false)):
		text += Content.t("fight.guarded")
	_add_line(text, HERO_COLOUR if who == "hero" else MONSTER_COLOUR)
	match kind:
		"hit", "critical", "special":
			var target := monster_picture if who == "hero" else hero_picture
			await _shake(target, kind != "hit")
			_update()
		"enraged":
			var tween := create_tween()
			tween.tween_property(monster_picture, "modulate", Color(1.0, 0.55, 0.5), 0.3)
			await tween.finished
		"down":
			var target := monster_picture if who == "monster" else hero_picture
			var tween := create_tween()
			tween.tween_property(target, "modulate:a", 0.25, 0.4)
			await tween.finished
		"heal":
			_update()
	if fight.is_over() and kind in ["down", "fled"]:
		_add_line(_ending_text(), "#e0b36a")


func _ending_text() -> String:
	match fight.result:
		Fight.WON:
			return Content.t("fight.won").format({"name": _monster_name(), "gold": int(fight.monster.get("gold", 0))})
		Fight.LOST:
			return Content.t("fight.lost")
		Fight.FLED:
			return Content.t("fight.escaped")
	return ""


## The d20 tumbles for a moment, then lands on the rolled number.
func _roll_dice(value: int) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ROLL_SECONDS * 1000.0:
		dice_label.text = "d20: %d" % randi_range(1, 20)
		await get_tree().create_timer(0.05).timeout
	dice_label.text = "d20: %d" % value


## A hit shakes the picture and flashes it red (harder for a critical).
func _shake(target: Control, hard: bool) -> void:
	var rest := target.position
	var strength := 8.0 if hard else 4.0
	var tween := create_tween()
	tween.tween_property(target, "self_modulate", Color(1.0, 0.35, 0.35), 0.05)
	for i in 4:
		tween.tween_property(target, "position", rest + Vector2(strength * (1 if i % 2 == 0 else -1), 0), 0.04)
	tween.tween_property(target, "position", rest, 0.04)
	tween.tween_property(target, "self_modulate", Color.WHITE, 0.1)
	await tween.finished


func _update() -> void:
	if fight == null:
		return
	var hero: Dictionary = fight.hero()
	hero_bar.show_value(Content.t("ui.hp"), int(hero["hp"]), int(hero["hp_max"]))
	monster_bar.show_value(Content.t("ui.hp"), fight.monster_hp, fight.monster_hp_max)
	buttons["potion"].text = Content.t("fight.potion").format({"n": fight.potions()})
	var over := fight.is_over()
	for action in buttons:
		buttons[action].visible = not over
	continue_button.visible = over
	_set_buttons_enabled(not over and not _animating)
	if over:
		continue_button.grab_focus()


func _set_buttons_enabled(on: bool) -> void:
	buttons["attack"].disabled = not on
	buttons["guard"].disabled = not on
	buttons["potion"].disabled = not on or fight == null or fight.potions() == 0
	buttons["flee"].disabled = not on or fight == null or not fight.can_flee()


func _add_line(text: String, colour: String) -> void:
	log_label.append_text("[color=%s]%s[/color]\n" % [colour, text.replace("[", "[lb]")])


func _monster_name() -> String:
	if fight == null:
		return ""
	return Content.t("monster.%s.name" % fight.monster_id)


func _localize() -> void:
	super()
	if fight != null:
		title_label.text = Content.t("fight.boss_title" if fight.boss else "fight.title").format({"name": _monster_name()})
		title_label.add_theme_color_override("font_color", BOSS_COLOUR if fight.boss else Color(0.95, 0.9, 0.8))
		monster_name.text = _monster_name()
		hero_name.text = Content.t("hero.kael.name")
	if buttons.is_empty():
		return
	buttons["attack"].text = Content.t("fight.attack")
	buttons["guard"].text = Content.t("fight.guard")
	buttons["flee"].text = Content.t("fight.flee")
	continue_button.text = Content.t("fight.continue")
	if fight != null:
		buttons["potion"].text = Content.t("fight.potion").format({"n": fight.potions()})


func _on_continue() -> void:
	if fight == null or not fight.is_over() or not visible:
		return
	visible = false
	closed.emit()
	finished.emit(fight)


## A fight can't be closed with Esc; keys 1-4 pick the actions, Enter goes on
## once it is over.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		return
	var index := [KEY_1, KEY_2, KEY_3, KEY_4].find(key.keycode)
	if index == -1:
		index = [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4].find(key.keycode)
	if index != -1:
		choose(Fight.ACTIONS[index])
		get_viewport().set_input_as_handled()
	elif key.keycode in [KEY_ENTER, KEY_KP_ENTER] and fight != null and fight.is_over():
		_on_continue()
		get_viewport().set_input_as_handled()


## The fight window blocks the world behind it.
func open() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	super()
