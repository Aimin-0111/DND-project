extends Node
## Plays the AI's commands in the world, one after another. Commands arrive
## here ONLY after DmReplyParser has checked them.
##
## When should the commands play? Two options:
##   Option A (used here): after the narration has finished typing.
##     Simple and readable: the player reads, then watches.
##   Option B: markers inside the narration, e.g. "...a wolf {1} appears",
##     run when the typewriter reaches them. More cinematic, but the AI must
##     place markers correctly and the typewriter must report its position.

signal roll_requested(skill: String, dc: int)

## Any of the three movement scripts: they all have walk_to().
@export var hero: Node2D
@export var creatures_root: Node2D
@export var weather_particles: GPUParticles2D
@export var day_night: CanvasModulate

## One scene per creature id from monsters.csv: res://world/creatures/rust_wolf.tscn
const CREATURE_SCENES := "res://world/creatures/%s.tscn"

const SKY := {
	"night": Color(0.25, 0.3, 0.5),
	"dawn": Color(0.9, 0.75, 0.7),
	"day": Color.WHITE,
	"dusk": Color(0.95, 0.65, 0.5),
}


func run(commands: Array) -> void:
	var walker = hero   # untyped on purpose: walk_to() exists on all three scripts
	for cmd in commands:
		match cmd["type"]:
			"move_to":
				await walker.walk_to(_location(cmd["target"]))
			"spawn":
				await _spawn(cmd["creature"], _location(cmd["near"]))
			"despawn":
				_despawn(cmd["creature"])
			"emote":
				pass   # show a small bubble (!, ?, zzz) above "who"
			"weather":
				weather_particles.emitting = cmd["kind"] != "clear"
			"request_roll":
				roll_requested.emit(cmd["skill"], int(cmd["dc"]))


## Called by the game whenever the clock changes.
func set_time_of_day(hour: int) -> void:
	var sky: Color = SKY["night"]
	if hour >= 5 and hour < 8:
		sky = SKY["dawn"]
	elif hour >= 8 and hour < 18:
		sky = SKY["day"]
	elif hour >= 18 and hour < 21:
		sky = SKY["dusk"]
	create_tween().tween_property(day_night, "color", sky, 2.0)


## Locations are Marker2D nodes in group "locations", named by id ("old_mill").
func _location(id: String) -> Vector2:
	for marker in get_tree().get_nodes_in_group("locations"):
		if marker.name == id:
			return marker.global_position
	push_warning("No marker for location '%s'" % id)
	return hero.global_position


func _spawn(creature_id: String, near: Vector2) -> void:
	var path := CREATURE_SCENES % creature_id
	if not ResourceLoader.exists(path):
		push_warning("No scene for creature '%s' yet" % creature_id)
		return
	var creature: Node2D = load(path).instantiate()
	creature.name = creature_id
	creature.global_position = near + Vector2(randf_range(-16, 16), randf_range(-16, 16))
	creature.modulate.a = 0.0
	creatures_root.add_child(creature)
	# Fade in so it doesn't just pop up.
	await create_tween().tween_property(creature, "modulate:a", 1.0, 0.6).finished


func _despawn(creature_id: String) -> void:
	var creature := creatures_root.get_node_or_null(creature_id)
	if creature:
		creature.queue_free()
