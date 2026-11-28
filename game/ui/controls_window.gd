class_name ControlsWindow
extends GameWindow
## Menu → Controls: which keys move the hero (W A S D, Z Q S D for AZERTY
## keyboards, or the arrow keys only) and whether a click walks, plus a list
## of the keys. A choice is saved at once in the device settings file and
## `changed` tells main.gd to use it.

signal changed(controls: ControlsStore)

var controls: ControlsStore
var move_label: Label
var layout_buttons := {}
var click_box: CheckBox
var help_label: Label


func _init() -> void:
	super()
	title_key = "ui.controls"
	panel_size = Vector2(460, 300)


func _ready() -> void:
	super()
	controls = ControlsStore.read(Content.settings_path)
	move_label = Label.new()
	move_label.name = "MoveLabel"
	body.add_child(move_label)
	var row := HBoxContainer.new()
	row.name = "Layouts"
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	var group := ButtonGroup.new()
	for layout in ControlsStore.LAYOUTS:
		var button := Button.new()
		button.name = layout
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_on_layout.bind(layout))
		row.add_child(button)
		layout_buttons[layout] = button
	click_box = CheckBox.new()
	click_box.name = "ClickToMove"
	click_box.toggled.connect(_on_click_toggled)
	body.add_child(click_box)
	help_label = Label.new()
	help_label.name = "Help"
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_color_override("font_color", Color(0.7, 0.76, 0.78))
	body.add_child(help_label)
	_localize()
	_refresh()


func _refresh() -> void:
	if controls == null:
		return
	for layout in layout_buttons:
		layout_buttons[layout].set_pressed_no_signal(layout == controls.layout)
	click_box.set_pressed_no_signal(controls.click_to_move)


func _localize() -> void:
	super()
	if move_label == null:
		return
	move_label.text = Content.t("controls.move")
	for layout in layout_buttons:
		layout_buttons[layout].text = Content.t("controls." + layout)
	click_box.text = Content.t("controls.click")
	help_label.text = Content.t("controls.help")


func _on_layout(layout: String) -> void:
	controls.layout = layout
	_save()


func _on_click_toggled(on: bool) -> void:
	controls.click_to_move = on
	_save()


func _save() -> void:
	var error := controls.write()
	if error != OK:
		push_warning("Controls: the settings file could not be saved (%s)" % error)
	changed.emit(controls)
