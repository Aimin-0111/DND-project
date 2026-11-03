extends RefCounted
## The travel command in the reply checks (SPEC-dm, Beta-0.3) and the MAP part
## of the prompt.

const START := "sq_24_24"
const HERE := "sq_24_23"
const MILL := ["mill_road", "mill_bridge", "old_mill"]


func run() -> Array:
	var failures: Array = []
	failures.append_array(_travel_checks())
	failures.append_array(_destination_checks())
	failures.append_array(_prompt_checks())
	return failures


## The hero is in a generated meadow north of the start square: north is a
## meadow, east a lake, west off the map, south the start square (visited).
func _allowed() -> Dictionary:
	return {
		"locations": MILL,
		"creatures": ["rust_wolf"],
		"items": ["rusty_sword", "healing_draught"],
		"quests": ["the_silent_mill"],
		"npcs": ["oda"],
		"skills": ["Stealth"],
		"travel": ["north", "south", START],
		"map": {
			"square": HERE, "kind": "meadow", "made": "generated", "places": [],
			"neighbours": {
				"north": {"square": "sq_24_22", "kind": "meadow", "can_enter": true, "visited": false, "places": []},
				"east": {"square": "sq_25_23", "kind": "lake", "can_enter": false, "visited": false, "places": []},
				"south": {"square": START, "kind": "road", "can_enter": true, "visited": true, "places": MILL},
				"west": {"square": "", "kind": "outside", "can_enter": false, "visited": false, "places": []},
			},
			"visited": [
				{"square": START, "kind": "road", "places": MILL},
				{"square": HERE, "kind": "meadow", "places": []},
			],
		},
	}


func _parse(commands: String, allowed: Dictionary = _allowed()) -> Dictionary:
	return DmReplyParser.parse("Narration.\n<<STATE>>\n{\"commands\": [%s]}" % commands, allowed)


func _travel_checks() -> Array:
	var failures: Array = []
	var cases := [
		['{"type": "travel", "to": "north"}', true, "a direction to a square the hero can enter"],
		['{"type": "travel", "to": "south"}', true, "a direction to a visited hand-made square"],
		['{"type": "travel", "to": "east"}', false, "a direction into a lake"],
		['{"type": "travel", "to": "west"}', false, "a direction off the map"],
		['{"type": "travel", "to": "up"}', false, "an unknown direction"],
		['{"type": "travel", "to": "sq_24_24"}', true, "a visited square id"],
		['{"type": "travel", "to": "sq_9_9"}', false, "a square never visited"],
		['{"type": "travel", "to": "sq_24_23"}', false, "the current square"],
		['{"type": "travel", "to": "sq_024_24"}', false, "a malformed square id"],
		['{"type": "travel", "to": 5}', false, "a number instead of text"],
		['{"type": "travel"}', false, "no destination"],
	]
	for entry in cases:
		var parsed := _parse(entry[0])
		var kept: bool = parsed["commands"].size() == 1
		if kept != entry[1]:
			failures.append("travel: %s should be %s: %s" % [entry[2], "kept" if entry[1] else "dropped", str(parsed)])
		if not kept and parsed["errors"].size() != 1:
			failures.append("travel: %s should be noted once" % entry[2])

	var two := _parse('{"type": "travel", "to": "north"}, {"type": "travel", "to": "south"}')
	if two["commands"] != [{"type": "travel", "to": "north"}] or two["errors"].size() != 1:
		failures.append("a second travel is dropped and noted: %s" % str(two))
	var bad_then_good := _parse('{"type": "travel", "to": "east"}, {"type": "travel", "to": "north"}')
	if bad_then_good["commands"] != [{"type": "travel", "to": "north"}]:
		failures.append("a refused travel doesn't block a good one after it")

	var extra := _parse('{"type": "travel", "to": "north", "square": "sq_0_0", "cell": [1, 1]}')
	if extra["commands"] != [{"type": "travel", "to": "north"}]:
		failures.append("extra keys on a travel are removed: %s" % str(extra["commands"]))

	var last := _parse('{"type": "weather", "kind": "rain"}, {"type": "move_to", "target": "old_mill"}, {"type": "travel", "to": "south"}')
	var types: Array = last["commands"].map(func(command: Dictionary) -> String: return command["type"])
	if types != ["travel", "weather", "move_to"]:
		failures.append("the travel plays first even when written last: %s" % str(types))

	var sixth := _parse('{"type":"weather","kind":"rain"},{"type":"weather","kind":"fog"},{"type":"weather","kind":"snow"},{"type":"weather","kind":"ash"},{"type":"weather","kind":"clear"},{"type":"travel","to":"north"}')
	if sixth["commands"].size() != 5 or sixth["commands"][0]["type"] == "travel":
		failures.append("a travel after the 5th command is dropped like any extra command")

	var m1 := _allowed()
	m1.erase("map")
	m1.erase("travel")
	var no_map := _parse('{"type": "travel", "to": "north"}, {"type": "move_to", "target": "old_mill"}', m1)
	if no_map["commands"] != [{"type": "move_to", "target": "old_mill"}]:
		failures.append("without a map view, travel is dropped and the M1 move_to check applies: %s" % str(no_map["commands"]))

	var odd := _parse('{"type": true}, {"type": 3}, {"type": ["travel"]}, {"type": {"travel": 1}}, {"type": "travel", "to": "north"}')
	if odd["commands"] != [{"type": "travel", "to": "north"}] or odd["errors"].size() != 4:
		failures.append("a type that isn't text is dropped and noted, and the travel still applies: %s" % str(odd))
	var odd_m1 := _parse('{"type": true}, {"type": "weather", "kind": "rain"}', m1)
	if odd_m1["commands"] != [{"type": "weather", "kind": "rain"}] or odd_m1["errors"].size() != 1:
		failures.append("without a map view, a type that isn't text doesn't drop the other commands: %s" % str(odd_m1))
	return failures


## The commands after a travel act in the destination square.
func _destination_checks() -> Array:
	var failures: Array = []
	var here := _parse('{"type": "move_to", "target": "old_mill"}, {"type": "spawn", "creature": "rust_wolf", "near": "mill_bridge"}, {"type": "spawn", "creature": "rust_wolf", "near": "hero"}')
	if here["commands"].size() != 1 or here["commands"][0].get("near") != "hero":
		failures.append("in a square with no places, only spawn near hero is kept: %s" % str(here["commands"]))
	var messages := " ".join(here["errors"])
	if not "not in this square" in messages:
		failures.append("a place of another square is reported as 'not in this square': %s" % messages)

	var back := _parse('{"type": "travel", "to": "sq_24_24"}, {"type": "move_to", "target": "old_mill"}, {"type": "spawn", "creature": "rust_wolf", "near": "mill_bridge"}')
	if back["commands"].size() != 3:
		failures.append("after travelling back to the start, its places are valid: %s" % str(back["errors"]))
	var south := _parse('{"type": "travel", "to": "south"}, {"type": "move_to", "target": "mill_road"}')
	if south["commands"].size() != 2:
		failures.append("a direction's destination places are valid after the travel: %s" % str(south["errors"]))
	var north := _parse('{"type": "travel", "to": "north"}, {"type": "move_to", "target": "mill_road"}')
	if north["commands"].size() != 1:
		failures.append("after travelling to a generated square, the mill's places are dropped")
	var unknown := _parse('{"type": "move_to", "target": "silver_tower"}')
	if not "unknown place" in " ".join(unknown["errors"]):
		failures.append("an invented place is still reported as unknown")
	return failures


func _prompt_checks() -> Array:
	var failures: Array = []
	var world := MapLoader.load_world(MapLoader.MAPS_DIR, ContentLoader.load_csv("res://content/data/locations.csv"))
	var state := GameState.new_game(12345)
	WorldState.settle(state, world)
	state["creatures"] = [
		{"id": "rust_wolf", "near": "mill_bridge", "square": START},
		{"id": "rust_wolf", "near": "hero", "square": HERE, "cell": [3, 4]},
	]
	state["hero_cell"] = [31, 0]
	GameState.apply_commands(state, [{"type": "travel", "to": "north"}], Dice.new(3), world)
	GameState.apply_commands(state, [{"type": "travel", "to": START}], Dice.new(3), world)

	var allowed := Content.allowed_ids()
	allowed["skills"] = GameState.allowed_skills(state)
	allowed["travel"] = WorldState.travel_targets(state, world)
	allowed["map"] = WorldState.view(state, world)
	var prompt := PromptBuilder.build(state, "Je regarde autour de moi.", "R", "C", allowed, "fr")
	var text := PromptBuilder.to_single_text(prompt)
	var at_state := text.find("=== STATE ===")
	var at_map := text.find("=== MAP ===")
	var at_ids := text.find("=== ALLOWED IDS ===")
	if not (at_state < at_map and at_map < at_ids):
		failures.append("the MAP part comes between STATE and ALLOWED IDS")
	var map_part := text.substr(at_map, at_ids - at_map)
	for expected in ['"square": "sq_24_24"', '"made": "by_hand"', '"neighbours"', '"visited"', '"sq_24_23"', '"old_mill"']:
		if not expected in map_part:
			failures.append("the MAP part should contain %s" % expected)
	if not '"travel"' in text.substr(at_ids) or prompt["allowed"].has("map"):
		failures.append("ALLOWED IDS lists the travel targets, and the map view isn't repeated there")
	if not allowed.has("map"):
		failures.append("building the prompt must not change the allowed ids it was given")
	for secret in ['"legend"', '"rows"', '"hero_cell"', '"squares"', '"cell"', '"seed"', '"rng_state"']:
		if secret in text:
			failures.append("%s must never be in the prompt" % secret)
	var state_part := text.substr(at_state, at_map - at_state)
	if state_part.count('"rust_wolf"') != 1:
		failures.append("STATE lists only the creatures of the hero's square")

	var m1 := PromptBuilder.to_single_text(PromptBuilder.build(state, "x", "R", "C", Content.allowed_ids(), "en"))
	if not "=== MAP ===\nnone" in m1:
		failures.append("without a map view the MAP part says none")

	var game_ids: Dictionary = Game.allowed_ids()
	if not game_ids.has("travel") or not (game_ids.get("map") is Dictionary) or game_ids["map"].get("square") != Game.state.get("square"):
		failures.append("Game.allowed_ids() carries the travel targets and the MAP view of the current square")
	return failures
