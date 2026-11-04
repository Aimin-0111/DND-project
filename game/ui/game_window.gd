class_name GameWindow
extends Control
## A window over the main screen (backpack, world map, Codex): a panel in the
## middle with a title, a close button and a Body for its contents. Esc or the
## close button closes it; with close_on_click_outside a click outside the
## panel closes it too. Otherwise the screen around the panel stays usable:
## the world keeps running (SPEC-main-screen). main.gd opens the windows and
## keeps one open at a time.
##
## A window's own script extends this one; its _ready() calls super() first,
## then adds its contents to `body`. open() calls _refresh() just before it shows.

signal opened
signal closed

## The strings.csv key of the title.
@export var title_key := ""
@export var panel_size := Vector2(520, 380)
@export var close_on_click_outside := false

## Panel/Margin/VBox/{Header/{Title, CloseButton}, Body}, built in _init().
var panel: PanelContainer
var title_label: Label
var close_button: Button
## The window's contents go here.
var body: VBoxContainer


## The opaque, framed panel of the windows and the menu.
static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.13)
	style.border_color = Color(0.55, 0.45, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _init() -> void:
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", panel_style())
	add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "VBox"
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.name = "Header"
	box.add_child(header)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	close_button = Button.new()
	close_button.name = "CloseButton"
	header.add_child(close_button)
	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if close_on_click_outside:
		var backdrop := Control.new()
		backdrop.name = "Backdrop"
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.gui_input.connect(_on_backdrop_input)
		add_child(backdrop)
		move_child(backdrop, 0)
	panel.custom_minimum_size = panel_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	close_button.pressed.connect(close)
	Content.language_changed.connect(_on_language_changed)
	_localize()


func open() -> void:
	_refresh()
	visible = true
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Fills the window from the state; called by open().
func _refresh() -> void:
	pass


## Relabels the window; a window with more labels adds them after super().
func _localize() -> void:
	title_label.text = Content.t(title_key)
	close_button.text = Content.t("ui.close")


func _on_language_changed(_lang: String) -> void:
	_localize()
	if visible:
		_refresh()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
