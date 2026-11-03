extends Node
## Autoload: the current state, dice, the world map and save/load.
## Content stays in the Content autoload; DM owns the AI turn. The world map
## reaches the DM through allowed_ids() (the MAP part and the travel targets).

signal state_changed(state: Dictionary)

var state: Dictionary = {}
var dice: Dice
## The loaded world grid (content/maps/), read once.
var world_map: WorldMap
var _started := false


func _ready() -> void:
	ensure_started()


## Lazy start keeps the autoload usable from headless tests.
func ensure_started(seed_value: int = 12345) -> void:
	if _started:
		return
	new_game(seed_value)


func new_game(seed_value: int = 12345) -> void:
	_started = true
	_ensure_map()
	dice = Dice.new(seed_value)
	state = GameState.new_game(seed_value)
	state["language"] = Content.language()
	Content.set_language(state["language"])
	for note in WorldState.settle(state, world_map):
		push_warning("New game: %s" % str(note))
	state["rng_state"] = dice.state()
	state_changed.emit(state)


## The map files are read once; their problems go to the debug log.
func _ensure_map() -> void:
	if world_map != null:
		return
	world_map = MapLoader.load_world(MapLoader.MAPS_DIR, Content.table("locations"))
	for problem in world_map.problems:
		push_warning("Map: %s" % problem)


## One checked turn: state changes, then the state side of the commands
## (requested rolls happen here). Returns notes about anything refused.
func apply_turn(changes: Dictionary, commands: Array) -> Array:
	var notes := GameState.apply_changes(state, changes)
	notes.append_array(GameState.apply_commands(state, commands, dice, world_map))
	state["turn"] = int(state.get("turn", 0)) + 1
	state["rng_state"] = dice.state()
	state_changed.emit(state)
	return notes


## Ids the DM may use. With the map: "travel" (the valid travel targets) and
## "map" (the MAP part of the prompt, also read by the reply checks).
func allowed_ids() -> Dictionary:
	var ids := Content.allowed_ids()
	ids["skills"] = GameState.allowed_skills(state)
	if world_map != null and not str(state.get("square", "")).is_empty():
		ids["travel"] = WorldState.travel_targets(state, world_map)
		ids["map"] = WorldState.view(state, world_map)
	return ids


func save(slot: String) -> Error:
	state["rng_state"] = dice.state()
	return SaveSystem.save_game(state, slot)


func load(slot: String) -> bool:
	var loaded := SaveSystem.load_game(slot)
	if loaded.is_empty():
		return false
	state = loaded
	_ensure_map()
	for note in WorldState.settle(state, world_map):
		push_warning("Load: %s" % str(note))
	dice = Dice.new(int(state.get("seed", 0)))
	dice.restore_state(int(state.get("rng_state", 0)))
	Content.set_language(str(state.get("language", "fr")))
	state_changed.emit(state)
	return true


func set_location(location_id: String) -> void:
	state["location"] = location_id
	state_changed.emit(state)


## The hero stopped walking on `cell` of the current square.
func set_hero_cell(cell: Vector2i) -> void:
	WorldState.set_hero_cell(state, world_map, cell)
	state_changed.emit(state)


## The kind of the hero's square ("forest", "road"…), for the HUD.
func square_kind() -> String:
	if world_map == null:
		return ""
	return world_map.kind_of(str(state.get("square", "")))


## The tiles of the hero's square, for the world to draw.
func square_tiles() -> PackedByteArray:
	if world_map == null:
		return PackedByteArray()
	return WorldState.square_tiles(state, world_map, str(state.get("square", "")))


func set_language(lang: String) -> void:
	state["language"] = lang
	Content.set_language(lang)
	state_changed.emit(state)
