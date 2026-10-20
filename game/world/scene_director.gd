extends Node
## Runs the AI's already-validated orders in the world, one after another.
## Commands arrive here only after DmReplyParser has accepted them.

signal note(message: String)
signal roll_requested(skill: String, dc: int)
signal moved_to(location_id: String)

@export var hero: Node2D
@export var creatures_root: Node2D
@export var weather_tint: CanvasModulate

const CREATURE_SCENES := "res://world/creatures/%s.tscn"
const WEATHER_COLORS := {
	"clear": Color.WHITE,
	"rain": Color(0.65, 0.72, 0.82),
	"fog": Color(0.82, 0.84, 0.86),
	"storm": Color(0.45, 0.5, 0.62),
	"snow": Color(0.85, 0.92, 1.0),
	"ash": Color(0.7, 0.66, 0.62),
}


func run(commands: Array) -> void:
	for command in commands:
		match str(command.get("type", "")):
			"move_to":
				var location_id := str(command.get("target", ""))
				var target := _location(location_id)
				if target != Vector2.INF:
					await hero.walk_to(target)
					moved_to.emit(location_id)
			"spawn":
				if _creature_count() < GameState.MAX_CREATURES:
					_spawn(str(command.get("creature", "")), str(command.get("near", "")))
			"despawn":
				_despawn(str(command.get("creature", "")))
			"weather":
				_set_weather(str(command.get("kind", "clear")))
			"emote":
				note.emit("%s: %s — %s" % [Content.t("ui.emote"), command.get("who", "?"), command.get("emote", "?")])
			"request_roll":
				roll_requested.emit(str(command.get("skill", "")), int(command.get("dc", 10)))
			_:
				push_warning("SceneDirector: unexpected command %s" % str(command))


func _location(id: String) -> Vector2:
	for marker in get_tree().get_nodes_in_group("locations"):
		if marker.name == id:
			return marker.global_position
	push_warning("SceneDirector: no marker for location '%s'" % id)
	return Vector2.INF


## Rebuilds creatures and weather from the state, e.g. after loading a save.
func show_state(state: Dictionary) -> void:
	for child in creatures_root.get_children():
		creatures_root.remove_child(child)
		child.queue_free()
	for creature in state.get("creatures", []):
		_spawn(str(creature.get("id", "")), str(creature.get("near", "")), false)
	_set_weather(str(state.get("weather", "clear")), false)


## The same creature id may appear twice; each node remembers its id.
func _spawn(creature_id: String, near_id: String, announce: bool = true) -> void:
	var path := CREATURE_SCENES % creature_id
	if not ResourceLoader.exists(path):
		push_warning("SceneDirector: no scene for creature '%s'" % creature_id)
		return
	var near := _location(near_id)
	if near == Vector2.INF:
		return
	var creature: Node2D = load(path).instantiate()
	creature.set_meta("creature_id", creature_id)
	creature.global_position = near + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
	creatures_root.add_child(creature)
	if announce:
		note.emit("%s: %s (%s)" % [Content.t("ui.spawned"), creature_id, near_id])


## Removes the most recently added creature with that id, like the state does.
func _despawn(creature_id: String) -> void:
	var children := creatures_root.get_children()
	for i in range(children.size() - 1, -1, -1):
		if children[i].get_meta("creature_id", "") == creature_id:
			children[i].queue_free()
			note.emit("%s: %s" % [Content.t("ui.despawned"), creature_id])
			return


func _creature_count() -> int:
	return creatures_root.get_children().filter(
		func(child: Node) -> bool: return not child.is_queued_for_deletion()
	).size()


func _set_weather(kind: String, announce: bool = true) -> void:
	if weather_tint != null:
		weather_tint.color = WEATHER_COLORS.get(kind, Color.WHITE)
	if announce:
		note.emit("%s: %s" % [Content.t("ui.weather"), kind])
