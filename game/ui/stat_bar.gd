class_name StatBar
extends HBoxContainer
## One bar of the bottom bar: its name, the bar and its numbers ("14/20").
## HP uses it in T1; T3 adds Steam (blue) and XP (amber) as more instances of
## stat_bar.tscn, each with its own fill_color (SPEC-main-screen, "Bottom bar").

## HP is red, Steam blue, XP amber.
@export var fill_color := Color(0.82, 0.22, 0.2)

@onready var name_label: Label = $Name
@onready var bar: ProgressBar = $Bar
@onready var value_label: Label = $Value


func _ready() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.1, 0.11, 0.13)
	background.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)


## `value` out of `maximum`, as given by core. `numbers` replaces the "14/20"
## text when set (the XP bar adds the level).
func show_value(label: String, value: int, maximum: int, numbers: String = "") -> void:
	name_label.text = label
	# The maximum first: a ProgressBar clamps its value to the current maximum.
	bar.max_value = maxi(maximum, 1)
	bar.value = clampi(value, 0, maxi(maximum, 1))
	value_label.text = numbers if not numbers.is_empty() else "%d/%d" % [value, maximum]
