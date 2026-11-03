extends RefCounted
## Crafted bad AI replies and robustness inputs (SPEC-dm acceptance criteria).
## Each file in tests/fixtures/replies/bad/ has one fault next to valid parts:
## the fault is dropped, clamped or makes the reply narration only, it is
## noted in errors, and the valid parts still apply. Then, whatever the input
## (empty, junk, 1 MB, random), the parser must return a result that keeps
## the SPEC-dm contract.

const BAD := "res://tests/fixtures/replies/bad/"
const MARKER := "<<STATE>>"
const MB := 1024 * 1024
const RANDOM_REPLIES := 500

## The world of the Haiku test (examples/ai-tests/dm_test_context.md), with
## Oda as the one NPC who may emote.
const ALLOWED := {
	"locations": ["mill_road", "old_mill", "mill_bridge", "mill_bridge_east", "copper_river"],
	"creatures": ["rust_wolf", "bog_ghoul", "cinder_imp", "brass_sentinel", "river_troll"],
	"items": ["rusty_sword", "hunting_bow", "leather_coat", "healing_draught", "tallow_candle", "brass_key"],
	"skills": ["Athletics", "Acrobatics", "Stealth", "Perception", "Investigation", "Persuasion", "Insight", "Survival"],
	"quests": ["the_silent_mill"],
	"npcs": ["oda_miller"],
}

## SPEC-dm's limits, written out again so the contract check below doesn't
## trust the parser's own constants.
const MAX_COMMANDS := 5
const MAX_ADD_ITEMS := 3
const FIELDS := {
	"move_to": ["target"],
	"spawn": ["creature", "near"],
	"despawn": ["creature"],
	"emote": ["who", "emote"],
	"weather": ["kind"],
	"request_roll": ["skill", "dc"],
}
const EMOTES := ["surprised", "angry", "happy", "scared", "sleep"]
const WEATHER := ["clear", "rain", "fog", "storm", "snow", "ash"]
const RANGES := {"hp_delta": [-30, 30], "gold_delta": [-200, 200], "time_advance_minutes": [0, 1440]}
const STATE_KEYS := ["hp_delta", "gold_delta", "time_advance_minutes", "add_items", "quest_updates"]

## One crafted reply per case in SPEC-dm's acceptance criteria, in the same
## order, with what the parser must keep. Every result but "kept" (fences are
## tolerated) must be noted in errors.
const CRAFTED := [
	{"file": "no_marker.txt", "result": "narration only"},
	{"file": "broken_json.txt", "result": "narration only"},
	{
		"file": "fenced_json.txt", "result": "kept",
		"commands": [{"type": "weather", "kind": "rain"}, {"type": "emote", "who": "oda_miller", "emote": "angry"}],
		"state": {"time_advance_minutes": 10},
	},
	{
		"file": "eight_commands.txt", "result": "dropped",
		"commands": [
			{"type": "move_to", "target": "mill_bridge"},
			{"type": "weather", "kind": "fog"},
			{"type": "spawn", "creature": "rust_wolf", "near": "mill_bridge"},
			{"type": "emote", "who": "oda_miller", "emote": "scared"},
			{"type": "request_roll", "skill": "Perception", "dc": 12},
		],
		"state": {"time_advance_minutes": 5},
	},
	{
		"file": "unknown_command.txt", "result": "dropped",
		"commands": [{"type": "emote", "who": "hero", "emote": "angry"}],
		"state": {"time_advance_minutes": 1},
	},
	{
		"file": "move_to_silver_tower.txt", "result": "dropped",
		"commands": [{"type": "emote", "who": "oda_miller", "emote": "angry"}],
		"state": {"time_advance_minutes": 30},
	},
	{
		"file": "spawn_dragon.txt", "result": "dropped",
		"commands": [{"type": "emote", "who": "hero", "emote": "happy"}],
	},
	{
		"file": "emote_unknown_npc.txt", "result": "dropped",
		"commands": [{"type": "emote", "who": "oda_miller", "emote": "angry"}],
	},
	{
		"file": "dc_50.txt", "result": "dropped",
		"commands": [{"type": "emote", "who": "oda_miller", "emote": "scared"}],
		"state": {"time_advance_minutes": 1},
	},
	{
		"file": "dc_text.txt", "result": "dropped",
		"commands": [{"type": "emote", "who": "oda_miller", "emote": "angry"}],
		"state": {"time_advance_minutes": 5},
	},
	{
		"file": "gold_9999.txt", "result": "clamped",
		"commands": [{"type": "emote", "who": "oda_miller", "emote": "surprised"}],
		"state": {"gold_delta": 200, "time_advance_minutes": 1},
	},
	{
		"file": "add_items_excalibur.txt", "result": "dropped",
		"state": {"time_advance_minutes": 2},
	},
	{
		"file": "five_add_items.txt", "result": "dropped",
		"state": {"add_items": ["tallow_candle", "brass_key", "healing_draught"], "time_advance_minutes": 15},
	},
	{
		"file": "quest_text_stage.txt", "result": "dropped",
		"commands": [{"type": "emote", "who": "oda_miller", "emote": "angry"}],
		"state": {"time_advance_minutes": 5},
	},
]

## The other rows of SPEC-dm's command and state tables that
## test_dm_reply_parser.gd doesn't cover: [what, JSON block, kept commands,
## kept state, noted].
const RULES := [
	[
		"the limits themselves are allowed",
		'{"commands": [{"type": "request_roll", "skill": "Stealth", "dc": 5}, {"type": "request_roll", "skill": "Insight", "dc": 30}], "state": {"hp_delta": -30, "gold_delta": 200, "time_advance_minutes": 1440, "add_items": ["brass_key", "brass_key", "tallow_candle"], "quest_updates": [{"id": "the_silent_mill", "stage": 0}]}}',
		[{"type": "request_roll", "skill": "Stealth", "dc": 5}, {"type": "request_roll", "skill": "Insight", "dc": 30}],
		{"hp_delta": -30, "gold_delta": 200, "time_advance_minutes": 1440, "add_items": ["brass_key", "brass_key", "tallow_candle"], "quest_updates": [{"id": "the_silent_mill", "stage": 0, "done": false}]},
		false,
	],
	[
		"one step past each limit",
		'{"commands": [{"type": "request_roll", "skill": "Stealth", "dc": 4}, {"type": "request_roll", "skill": "Insight", "dc": 31}, {"type": "weather", "kind": "ash"}], "state": {"hp_delta": 31, "gold_delta": -201, "time_advance_minutes": 1441}}',
		[{"type": "weather", "kind": "ash"}],
		{"hp_delta": 30, "gold_delta": -200, "time_advance_minutes": 1440},
		true,
	],
	[
		"time going back",
		'{"state": {"time_advance_minutes": -15, "gold_delta": 3}}',
		[], {"time_advance_minutes": 0, "gold_delta": 3}, true,
	],
	[
		"unknown weather",
		'{"commands": [{"type": "weather", "kind": "hail"}, {"type": "emote", "who": "hero", "emote": "sleep"}]}',
		[{"type": "emote", "who": "hero", "emote": "sleep"}], {}, true,
	],
	[
		"unknown emote",
		'{"commands": [{"type": "emote", "who": "oda_miller", "emote": "dance"}, {"type": "weather", "kind": "clear"}]}',
		[{"type": "weather", "kind": "clear"}], {}, true,
	],
	[
		"spawn near an unknown place",
		'{"commands": [{"type": "spawn", "creature": "rust_wolf", "near": "silver_tower"}, {"type": "spawn", "creature": "bog_ghoul", "near": "old_mill"}]}',
		[{"type": "spawn", "creature": "bog_ghoul", "near": "old_mill"}], {}, true,
	],
	[
		"a missing field",
		'{"commands": [{"type": "move_to"}, {"type": "despawn", "creature": "rust_wolf"}]}',
		[{"type": "despawn", "creature": "rust_wolf"}], {}, true,
	],
	[
		"a field of the wrong type",
		'{"commands": [{"type": "move_to", "target": 3}, {"type": "move_to", "target": "copper_river"}]}',
		[{"type": "move_to", "target": "copper_river"}], {}, true,
	],
	[
		"an unknown quest",
		'{"state": {"quest_updates": [{"id": "the_dragon_hunt", "stage": 1}, {"id": "the_silent_mill", "stage": 1, "done": true}]}}',
		[], {"quest_updates": [{"id": "the_silent_mill", "stage": 1, "done": true}]}, true,
	],
	[
		"commands that are not a list",
		'{"commands": {"type": "move_to", "target": "old_mill"}, "state": {"gold_delta": 4}}',
		[], {"gold_delta": 4}, true,
	],
	[
		"state that is not an object",
		'{"commands": [{"type": "weather", "kind": "snow"}], "state": [{"gold_delta": 4}]}',
		[{"type": "weather", "kind": "snow"}], {}, true,
	],
]

## The four problems in docs/m1-ai-tests.md, "Found by the tests", with what
## SPEC-dm asks for: [what, reply, narration, kept commands, kept state,
## noted]. A reply that starts with { or [ is a JSON block after "The road is
## quiet." and the marker line (narration null); one that names a file is
## read from tests/fixtures/replies/bad/ and checked with Unix and Windows
## line breaks; any other text is the whole reply.
const FOUND := [
	# 1. From 2^63 up, int() overflowed before clamping: −200, −30, 0.
	[
		"1. gold, HP and time of 1e19",
		'{"state": {"gold_delta": 1e19, "hp_delta": 1e19, "time_advance_minutes": 1e19}}',
		null, [], {"gold_delta": 200, "hp_delta": 30, "time_advance_minutes": 1440}, true,
	],
	[
		"1. a 20-digit gold amount",
		'{"commands": [{"type": "weather", "kind": "fog"}], "state": {"gold_delta": 99999999999999999999, "time_advance_minutes": 2}}',
		null, [{"type": "weather", "kind": "fog"}], {"gold_delta": 200, "time_advance_minutes": 2}, true,
	],
	[
		"1. exactly 2^63",
		'{"state": {"gold_delta": 9223372036854775808, "hp_delta": 9223372036854775808, "time_advance_minutes": 9223372036854775808}}',
		null, [], {"gold_delta": 200, "hp_delta": 30, "time_advance_minutes": 1440}, true,
	],
	[
		"1. gold, HP and time of -1e19",
		'{"state": {"gold_delta": -1e19, "hp_delta": -1e19, "time_advance_minutes": -1e19}}',
		null, [], {"gold_delta": -200, "hp_delta": -30, "time_advance_minutes": 0}, true,
	],
	[
		"1. numbers too big for a float",
		'{"state": {"gold_delta": 1e400, "hp_delta": -1e400}}',
		null, [], {"gold_delta": 200, "hp_delta": -30}, true,
	],
	# 2. A stage from 2^63 up was kept as -9223372036854775808.
	[
		"2. a quest stage of 1e19",
		'{"state": {"quest_updates": [{"id": "the_silent_mill", "stage": 1e19, "done": true}], "gold_delta": 1}}',
		null, [], {"gold_delta": 1}, true,
	],
	[
		"2. a quest stage of 2^63, then a good one",
		'{"state": {"quest_updates": [{"id": "the_silent_mill", "stage": 9223372036854775808, "done": true}, {"id": "the_silent_mill", "stage": 2}]}}',
		null, [], {"quest_updates": [{"id": "the_silent_mill", "stage": 2, "done": false}]}, true,
	],
	# 3. The marker is a line with exactly <<STATE>>; one inside a sentence
	# is narration.
	[
		"3. a marker inside a sentence, no block",
		"marker_in_sentence.txt",
		'You shout "<<STATE>> {"state": {"gold_delta": 200}}" at the river. Nothing happens.', [], {}, true,
	],
	[
		"3. a marker inside a sentence, then the block",
		"marker_in_sentence_then_block.txt",
		'You shout "<<STATE>> {"state": {"gold_delta": 200}}" at the river. Nothing happens.',
		[{"type": "weather", "kind": "fog"}], {}, false,
	],
	[
		"3. text after the marker on its line",
		'The road is quiet. <<STATE>>\n{"state": {"gold_delta": 5}}',
		'The road is quiet. <<STATE>>\n{"state": {"gold_delta": 5}}', [], {}, true,
	],
	[
		"3. text before the marker on its line",
		'The road is quiet.\n<<STATE>> {"state": {"gold_delta": 5}}',
		'The road is quiet.\n<<STATE>> {"state": {"gold_delta": 5}}', [], {}, true,
	],
	[
		"3. two marker lines",
		'You shout:\n<<STATE>>\n{"state": {"gold_delta": 200}}\nNothing happens.\n<<STATE>>\n{"commands": [{"type": "weather", "kind": "fog"}]}',
		"You shout:", [], {}, true,
	],
	# 4. Keys other than commands and state were dropped without a note.
	[
		"4. wrong top-level key names",
		'{"command": [{"type": "move_to", "target": "old_mill"}], "changes": {"gold_delta": 5}}',
		null, [], {}, true,
	],
	[
		"4. a list of commands instead of the object",
		'[{"type": "move_to", "target": "old_mill"}]',
		null, [], {}, true,
	],
	[
		"4. an unknown key next to good ones",
		'{"commands": [{"type": "weather", "kind": "rain"}], "state": {"gold_delta": 5}, "mood": "grim"}',
		null, [{"type": "weather", "kind": "rain"}], {"gold_delta": 5}, true,
	],
]

## Pieces of random replies, right and wrong. Numbers from 2^63 up are
## checked in FOUND.
const NUMBERS := [0, 1, -1, 4, 5, 12.5, 13, 30, 31, -30, -31, 200, 201, -200, -201, 1440, 1441, 9999, -9999, 0.5, -0.5, 1e15, -1e15]
const WORDS := [
	"move_to", "spawn", "despawn", "emote", "weather", "request_roll", "teleport", "type", "commands",
	"state", "gold_delta", "old_mill", "silver_tower", " old_mill", "OLD_MILL", "rust_wolf", "dragon",
	"brass_key", "excalibur", "oda_miller", "hero", "wizard", "angry", "dance", "fog", "hail",
	"Stealth", "Flying", "the_silent_mill", "",
]


func run() -> Array:
	var failures: Array = []
	failures.append_array(_crafted_replies())
	failures.append_array(_other_rules())
	failures.append_array(_found_by_tests())
	failures.append_array(_robustness())
	failures.append_array(_random_replies())
	return failures


## Each crafted reply with Unix and with Windows line breaks: a Git checkout
## on Windows can turn the fixtures into either.
func _crafted_replies() -> Array:
	var failures: Array = []
	for entry in CRAFTED:
		var path: String = BAD + entry["file"]
		if not FileAccess.file_exists(path):
			failures.append("missing fixture %s" % path)
			continue
		var unix := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
		for text in [unix, unix.replace("\n", "\r\n")]:
			var what := "%s (%s%s)" % [entry["file"], entry["result"], ", Windows line breaks" if text != unix else ""]
			var result: Variant = DmReplyParser.parse(text, ALLOWED)
			failures.append_array(_kept_problems(what, result, entry.get("commands", []), entry.get("state", {})))
			if not (result is Dictionary):
				continue
			if result["narration"] != _story(text):
				failures.append("%s: the narration should be the text before %s, or all of it without one" % [what, MARKER])
			failures.append_array(_note_problems(what, result, entry["result"] != "kept"))
	return failures


func _other_rules() -> Array:
	var failures: Array = []
	for rule in RULES:
		var result: Variant = DmReplyParser.parse(_reply(rule[1]), ALLOWED)
		failures.append_array(_kept_problems(rule[0], result, rule[2], rule[3]))
		if result is Dictionary:
			failures.append_array(_note_problems(rule[0], result, rule[4]))
	return failures


func _found_by_tests() -> Array:
	var failures: Array = []
	for case in FOUND:
		var texts: Array = [case[1]]
		if case[1].begins_with("{") or case[1].begins_with("["):
			texts = [_reply(case[1])]
		elif case[1].ends_with(".txt"):
			var path: String = BAD + case[1]
			if not FileAccess.file_exists(path):
				failures.append("missing fixture %s" % path)
				continue
			var unix := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
			texts = [unix, unix.replace("\n", "\r\n")]
		for text in texts:
			var what: String = case[0] + (", Windows line breaks" if text.contains("\r\n") else "")
			var result: Variant = DmReplyParser.parse(text, ALLOWED)
			failures.append_array(_kept_problems(what, result, case[3], case[4]))
			if not (result is Dictionary):
				continue
			var narration: String = "The road is quiet." if case[2] == null else case[2]
			if result["narration"] != narration:
				failures.append("%s: narration %s, expected %s" % [what, _short(str(result["narration"]).c_escape()), _short(narration.c_escape())])
			failures.append_array(_note_problems(what, result, case[5]))
	return failures


## The checker must never fail: any text gives a result that keeps the
## contract, and the valid parts of a huge reply are still found.
func _robustness() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261103
	var bytes := _byte_junk(rng, 64 * 1024)
	var unicode := _unicode_junk(rng, 64 * 1024)
	var prose := "The mill wheel creaks in the wind. ".repeat(MB / 35 + 1).left(MB)
	var fog := '{"type": "weather", "kind": "fog"}'
	var fog_kept: Array = [{"type": "weather", "kind": "fog"}]
	var five_fogs_kept: Array = []
	for i in MAX_COMMANDS:
		five_fogs_kept.append({"type": "weather", "kind": "fog"})
	var many_keys := PackedStringArray()
	for i in MB / 16:
		many_keys.append('"key_%d": 1' % i)

	# [what, reply, kept commands, kept state]
	var inputs := [
		["empty text", "", [], {}],
		["only spaces and line breaks", " \n\t\r\n ", [], {}],
		["only the marker", MARKER, [], {}],
		["nothing after the marker", _reply(""), [], {}],
		["a marker with spaces in it", "The road is quiet.\n<< STATE >>\n{\"commands\": [%s]}" % fog, [], {}],
		["null after the marker", _reply("null"), [], {}],
		["a number after the marker", _reply("42"), [], {}],
		["an empty object", _reply("{}"), [], {}],
		["64 KB of byte junk", bytes, [], {}],
		["64 KB of byte junk after the marker", _reply("{" + bytes + "}"), [], {}],
		["64 KB of Unicode junk", unicode, [], {}],
		["64 KB of Unicode junk after the marker", _reply("{" + unicode + "}"), [], {}],
		["1 MB of text", prose, [], {}],
		["1 MB of text, then a reply", prose + "\n%s\n{\"commands\": [%s]}" % [MARKER, fog], fog_kept, {}],
		["1 MB of nested lists", _reply("{\"commands\": " + "[".repeat(MB) + "}"), [], {}],
		["a 1 MB place id", _reply("{\"commands\": [{\"type\": \"move_to\", \"target\": \"%s\"}]}" % "a".repeat(MB)), [], {}],
		["1 MB of commands", _reply("{\"commands\": [%s%s]}" % [(fog + ", ").repeat(MB / (fog.length() + 2)), fog]), five_fogs_kept, {}],
		["1 MB of unknown items", _reply("{\"state\": {\"add_items\": [%s\"brass_key\"]}}" % "\"excalibur\", ".repeat(MB / 13)), [], {"add_items": ["brass_key"]}],
		["1 MB of unknown state keys", _reply("{\"state\": {%s, \"gold_delta\": 1}}" % ", ".join(many_keys)), [], {"gold_delta": 1}],
		["1 MB of markers", MARKER.repeat(MB / MARKER.length()), [], {}],
	]
	var failures: Array = []
	for input in inputs:
		var result: Variant = DmReplyParser.parse(input[1], ALLOWED)
		failures.append_array(_kept_problems(input[0], result, input[2], input[3]))
	return failures


## Seeded random replies built from right and wrong pieces. Whatever they
## hold, what the parser keeps must follow SPEC-dm.
func _random_replies() -> Array:
	var failures: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 18102026
	var kept_commands := 0
	var kept_changes := 0
	for i in RANDOM_REPLIES:
		var block := {"commands": _random_commands(rng), "state": _random_state(rng)}
		if rng.randf() < 0.1:
			block[_pick(rng, WORDS)] = _random_value(rng, 0)
		var result: Variant = DmReplyParser.parse(_reply(JSON.stringify(block)), ALLOWED)
		for problem in _contract_problems(result):
			failures.append("random reply %s: %s" % [_short(JSON.stringify(block)), problem])
		if result is Dictionary:
			kept_commands += result["commands"].size()
			kept_changes += result["state"].size()
	if kept_commands < 100 or kept_changes < 100:
		failures.append("random replies kept %d commands and %d changes: too few to test the checks" % [kept_commands, kept_changes])
	return failures


## The contract first, then what was kept against what should be.
static func _kept_problems(what: String, result: Variant, commands: Array, state: Dictionary) -> Array:
	var problems: Array = []
	for problem in _contract_problems(result):
		problems.append("%s: %s" % [what, problem])
	if not problems.is_empty():
		return problems
	if _json(result["commands"]) != _json(commands):
		problems.append("%s: kept commands %s, expected %s" % [what, _short(_json(result["commands"])), _short(_json(commands))])
	if _json(result["state"]) != _json(state):
		problems.append("%s: kept state %s, expected %s" % [what, _short(_json(result["state"])), _short(_json(state))])
	return problems


static func _note_problems(what: String, result: Dictionary, noted: bool) -> Array:
	if noted and result["errors"].is_empty():
		return ["%s: the fault should be noted in errors" % what]
	if not noted and not result["errors"].is_empty():
		return ["%s: nothing should be noted, got %s" % [what, _short(str(result["errors"]))]]
	return []


## Every way a parse result can break the SPEC-dm contract, whatever the
## input. Extra fields inside a kept command are allowed: core and the world
## only read the fields SPEC-dm lists.
static func _contract_problems(result: Variant) -> Array:
	if not (result is Dictionary):
		return ["the parser returned %s instead of a result" % type_string(typeof(result))]
	var problems: Array = []
	if not (result.get("narration") is String):
		problems.append("narration is not text")
	if not (result.get("errors") is Array):
		problems.append("errors is not a list")
	var commands: Variant = result.get("commands")
	if not (commands is Array):
		problems.append("commands is not a list")
	else:
		if commands.size() > MAX_COMMANDS:
			problems.append("%d commands kept, max %d" % [commands.size(), MAX_COMMANDS])
		for command in commands:
			if not _good_command(command):
				problems.append("kept a bad command %s" % _short(str(command)))
	var state: Variant = result.get("state")
	if not (state is Dictionary):
		problems.append("state is not an object")
	else:
		problems.append_array(_state_problems(state))
	return problems


static func _good_command(command: Variant) -> bool:
	if not (command is Dictionary) or not (command.get("type") is String) or not FIELDS.has(command["type"]):
		return false
	for field in FIELDS[command["type"]]:
		if not command.has(field):
			return false
	match command["type"]:
		"move_to":
			return _allowed("locations", command["target"])
		"spawn":
			return _allowed("creatures", command["creature"]) and _allowed("locations", command["near"])
		"despawn":
			return _allowed("creatures", command["creature"])
		"emote":
			return (_one_of(["hero"], command["who"]) or _allowed("npcs", command["who"])) and _one_of(EMOTES, command["emote"])
		"weather":
			return _one_of(WEATHER, command["kind"])
		"request_roll":
			return _allowed("skills", command["skill"]) and _whole(command["dc"], 5, 30)
	return false


static func _state_problems(state: Dictionary) -> Array:
	var problems: Array = []
	for key in state:
		if not key in STATE_KEYS:
			problems.append("kept the unknown key %s" % _short(str(key)))
	for key in RANGES:
		if state.has(key) and not _whole(state[key], RANGES[key][0], RANGES[key][1]):
			problems.append("kept %s = %s, outside SPEC-dm's range" % [key, str(state[key])])
	if state.has("add_items"):
		var items: Variant = state["add_items"]
		var good: bool = items is Array and items.size() <= MAX_ADD_ITEMS
		if good:
			for item in items:
				good = good and _allowed("items", item)
		if not good:
			problems.append("kept bad add_items %s" % _short(str(items)))
	if state.has("quest_updates"):
		var quests: Variant = state["quest_updates"]
		var good: bool = quests is Array
		if good:
			for quest in quests:
				good = good and quest is Dictionary and _allowed("quests", quest.get("id")) \
					and _whole(quest.get("stage"), 0, INF) and quest.get("done", false) is bool
		if not good:
			problems.append("kept bad quest_updates %s" % _short(str(quests)))
	return problems


static func _allowed(list: String, value: Variant) -> bool:
	return value is String and value in ALLOWED[list]


static func _one_of(values: Array, value: Variant) -> bool:
	return value is String and value in values


static func _whole(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and value == floorf(value) and value >= low and value <= high


## The reply after the marker, written the way the DM rules ask.
static func _reply(block: String) -> String:
	return "The road is quiet.\n%s\n%s" % [MARKER, block]


## The narration SPEC-dm expects: the text before the marker, or all of it
## when there is no marker.
static func _story(text: String) -> String:
	var at := text.find(MARKER)
	return (text if at == -1 else text.left(at)).strip_edges()


## JSON text with every number as a float and keys sorted. The parser keeps
## JSON numbers as floats (dc 13.0) but returns state values as ints, so
## 13 and 13.0 must compare equal.
static func _json(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


static func _short(text: String) -> String:
	return text if text.length() <= 200 else text.left(200) + "..."


## Characters 1 to 255 in random order: a binary file pasted as text. Godot
## strings can't hold character 0 (it becomes U+FFFD).
static func _byte_junk(rng: RandomNumberGenerator, length: int) -> String:
	var chars := PackedStringArray()
	chars.resize(length)
	for i in length:
		chars[i] = String.chr(rng.randi_range(1, 255))
	return "".join(chars)


## Random characters from the whole Unicode range, surrogates left out.
static func _unicode_junk(rng: RandomNumberGenerator, length: int) -> String:
	var chars := PackedStringArray()
	chars.resize(length)
	for i in length:
		var code := rng.randi_range(1, 0x10FFFF - 0x800)
		chars[i] = String.chr(code + 0x800 if code >= 0xD800 else code)
	return "".join(chars)


static func _random_commands(rng: RandomNumberGenerator) -> Variant:
	if rng.randf() < 0.1:
		return _random_value(rng, 0)
	var commands: Array = []
	for i in rng.randi_range(0, 8):
		commands.append(_random_command(rng))
	return commands


## Right type and fields most of the time, so that many commands are kept
## and checked.
static func _random_command(rng: RandomNumberGenerator) -> Variant:
	if rng.randf() < 0.1:
		return _random_value(rng, 0)
	var types: Array = FIELDS.keys() + ["teleport"]
	var type: String = _pick(rng, types)
	var command := {"type": type}
	for field in FIELDS.get(type, ["target"]):
		if rng.randf() < 0.1:
			continue
		command[field] = _good_field(rng, field) if rng.randf() < 0.75 else _random_value(rng, 0)
	if rng.randf() < 0.1:
		command[_pick(rng, WORDS)] = _random_value(rng, 0)
	return command


static func _good_field(rng: RandomNumberGenerator, field: String) -> Variant:
	match field:
		"target", "near":
			return _pick(rng, ALLOWED["locations"])
		"creature":
			return _pick(rng, ALLOWED["creatures"])
		"who":
			return _pick(rng, ALLOWED["npcs"] + ["hero"])
		"emote":
			return _pick(rng, EMOTES)
		"kind":
			return _pick(rng, WEATHER)
		"skill":
			return _pick(rng, ALLOWED["skills"])
	return rng.randi_range(1, 35)


static func _random_state(rng: RandomNumberGenerator) -> Variant:
	if rng.randf() < 0.1:
		return _random_value(rng, 0)
	var state := {}
	for key in RANGES:
		if rng.randf() < 0.5:
			var limits: Array = RANGES[key]
			state[key] = rng.randi_range(limits[0] - 100, limits[1] + 100) if rng.randf() < 0.8 else _random_value(rng, 0)
	if rng.randf() < 0.5:
		var items: Array = []
		for i in rng.randi_range(0, 6):
			items.append(_pick(rng, ALLOWED["items"]) if rng.randf() < 0.7 else _random_value(rng, 1))
		state["add_items"] = items
	if rng.randf() < 0.4:
		var quests: Array = []
		for i in rng.randi_range(0, 3):
			quests.append({
				"id": "the_silent_mill" if rng.randf() < 0.8 else _random_value(rng, 1),
				"stage": rng.randi_range(-2, 9) if rng.randf() < 0.8 else _random_value(rng, 1),
				"done": (rng.randf() < 0.5) if rng.randf() < 0.8 else _random_value(rng, 1),
			})
		state["quest_updates"] = quests
	if rng.randf() < 0.2:
		state[_pick(rng, WORDS)] = _random_value(rng, 0)
	return state


## Any JSON value: null, a bool, a number, a word, a list or an object.
static func _random_value(rng: RandomNumberGenerator, depth: int) -> Variant:
	match rng.randi_range(0, 5 if depth < 2 else 3):
		0:
			return null
		1:
			return rng.randf() < 0.5
		2:
			return _pick(rng, NUMBERS)
		3:
			return _pick(rng, WORDS)
		4:
			return [_random_value(rng, depth + 1), _random_value(rng, depth + 1)]
	return {_pick(rng, WORDS): _random_value(rng, depth + 1)}


static func _pick(rng: RandomNumberGenerator, values: Array) -> Variant:
	return values[rng.randi_range(0, values.size() - 1)]
