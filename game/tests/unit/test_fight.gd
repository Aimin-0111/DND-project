extends RefCounted
## Fights (core/fight.gd, SPEC-fight.md): the rules with seeded dice, so every
## run gives the same rolls.
## - begin: HP from monsters.csv, the boss flag, the hero's attack bonus and weapon;
## - attacking ends the fight; HP never go below 0; the same seed gives the same fight;
## - a potion heals (never above max) and leaves the pack; none left: refused, no round used;
## - guard: +2 AC for the creature's answer;
## - a boss can't be fled from; its special comes every `special_every`
##   rounds, halved by a guard; at half HP it is enraged;
## - finish: won (gold, the creature leaves the state), lost (half HP, back
##   at the start place, hours later), fled (nothing more).

const WOLF := {"id": "rust_wolf", "level": 1, "hp": 11, "ac": 13, "attack_bonus": 4, "damage": "2d4+2", "gold": 3, "boss": "false"}
const GOLEM := {"id": "mill_golem", "level": 3, "hp": 30, "ac": 14, "attack_bonus": 4, "damage": "1d8+2", "gold": 40,
		"boss": "true", "special": "steam_blast", "special_damage": "2d6", "special_every": 3}
const ITEMS := [
	{"id": "rusty_sword", "type": "weapon", "price": 8, "damage": "1d6", "heal": null},
	{"id": "healing_draught", "type": "potion", "price": 25, "damage": null, "heal": "2d4+2"},
]


func run() -> Array:
	var failures: Array = []
	failures.append_array(_begin_checks())
	failures.append_array(_attack_checks())
	failures.append_array(_potion_checks())
	failures.append_array(_guard_checks())
	failures.append_array(_boss_checks())
	failures.append_array(_finish_checks())
	failures.append_array(_content_checks())
	return failures


func _new_state() -> Dictionary:
	return GameState.new_game(7)


func _begin_checks() -> Array:
	var failures: Array = []
	var fight := Fight.begin(_new_state(), Dice.new(1), WOLF, ITEMS, 0)
	if fight.monster_hp != 11 or fight.monster_hp_max != 11 or fight.boss:
		failures.append("begin: wolf should have 11 HP and not be a boss")
	if fight.hero_attack_bonus() != 5:
		failures.append("begin: Kael (DEX 16) should attack at +5, got %d" % fight.hero_attack_bonus())
	if fight.weapon_damage() != "1d6":
		failures.append("begin: the rusty sword should deal 1d6, got %s" % fight.weapon_damage())
	if fight.potions() != 2 or not fight.can_flee():
		failures.append("begin: 2 potions and fleeing allowed against a wolf")
	if not Fight.begin(_new_state(), Dice.new(1), GOLEM, ITEMS).boss:
		failures.append("begin: the golem is a boss")
	var unarmed := _new_state()
	unarmed["pack"] = []
	if Fight.begin(unarmed, Dice.new(1), WOLF, ITEMS).weapon_damage() != Fight.UNARMED:
		failures.append("begin: without a weapon the hero fights unarmed")
	return failures


func _play(fight: Fight, action: String, limit: int = 60) -> int:
	var rounds := 0
	while not fight.is_over() and rounds < limit:
		fight.act(action)
		rounds += 1
		if fight.monster_hp < 0 or int(fight.hero()["hp"]) < 0:
			return -1
	return rounds


func _attack_checks() -> Array:
	var failures: Array = []
	var fight := Fight.begin(_new_state(), Dice.new(99), WOLF, ITEMS, 0)
	var rounds := _play(fight, "attack")
	if rounds == -1:
		failures.append("attack: HP went below 0")
	if not fight.is_over() or not fight.result in [Fight.WON, Fight.LOST]:
		failures.append("attack: an attack-only fight should end in a win or a loss, got %s after %d rounds" % [fight.result, rounds])
	if fight.result == Fight.WON and fight.monster_hp != 0:
		failures.append("attack: a won fight leaves the creature at 0 HP")
	if fight.result == Fight.LOST and int(fight.hero()["hp"]) != 0:
		failures.append("attack: a lost fight leaves the hero at 0 HP")
	# The same seed gives the same fight.
	var again := Fight.begin(_new_state(), Dice.new(99), WOLF, ITEMS, 0)
	_play(again, "attack")
	if again.result != fight.result or again.round_number != fight.round_number or int(again.hero()["hp"]) != int(fight.hero()["hp"]):
		failures.append("attack: the same seed should give the same fight")
	# Every hero attack event carries its roll.
	var probe := Fight.begin(_new_state(), Dice.new(3), WOLF, ITEMS)
	var events := probe.act("attack")
	if events.is_empty() or not events[0].has("d20") or not str(events[0]["kind"]) in ["hit", "miss", "critical"]:
		failures.append("attack: the first event should be the hero's roll, got %s" % str(events))
	# Acting after the end does nothing.
	if not fight.act("attack").is_empty():
		failures.append("attack: a finished fight ignores actions")
	return failures


func _potion_checks() -> Array:
	var failures: Array = []
	var state := _new_state()
	state["hero"]["hp"] = 3
	var fight := Fight.begin(state, Dice.new(5), WOLF, ITEMS)
	var events := fight.act("potion")
	if events.is_empty() or events[0]["kind"] != "heal":
		failures.append("potion: the first event should be a heal, got %s" % str(events))
	elif int(events[0]["amount"]) < 4:
		failures.append("potion: 2d4+2 heals at least 4, got %d" % int(events[0]["amount"]))
	if fight.potions() != 1:
		failures.append("potion: one potion should be left, got %d" % fight.potions())
	state["hero"]["hp"] = 12
	fight.act("potion")
	if int(state["hero"]["hp"]) > 12:
		failures.append("potion: healing never goes above max HP")
	if fight.potions() != 0 or GameState.remove_item(state, "healing_draught", 1):
		failures.append("potion: the last potion should leave the pack")
	var round_before := fight.round_number
	events = fight.act("potion")
	if events.size() != 1 or events[0]["kind"] != "refused" or fight.round_number != round_before:
		failures.append("potion: with none left, the action is refused and no round passes")
	return failures


func _guard_checks() -> Array:
	var failures: Array = []
	var fight := Fight.begin(_new_state(), Dice.new(11), WOLF, ITEMS)
	var events := fight.act("guard")
	var answer: Dictionary = events[-1] if events.size() > 1 else {}
	if events.is_empty() or events[0]["kind"] != "guard":
		failures.append("guard: the first event should be the guard")
	if int(answer.get("ac", 0)) != 14 + Fight.GUARD_AC:
		failures.append("guard: the wolf should roll against AC %d, got %s" % [14 + Fight.GUARD_AC, str(answer)])
	var next := fight.act("attack")
	for event in next:
		if event.get("who") == "monster" and event.has("ac") and int(event["ac"]) != 14:
			failures.append("guard: the guard lasts one round only")
	return failures


func _boss_checks() -> Array:
	var failures: Array = []
	var state := _new_state()
	state["hero"]["hp_max"] = 500
	state["hero"]["hp"] = 500
	var fight := Fight.begin(state, Dice.new(21), GOLEM, ITEMS)
	var round_before := fight.round_number
	var refused := fight.act("flee")
	if refused.size() != 1 or refused[0]["kind"] != "refused" or fight.round_number != round_before or fight.is_over():
		failures.append("boss: fleeing a boss is refused and uses no round")
	var specials: Array = []
	var charges: Array = []
	var guarded_special := {}
	var enraged_at := -1
	for i in 12:
		if fight.is_over():
			break
		var action := "guard" if fight.round_number % 3 == 0 else "attack"
		for event in fight.act(action):
			if event["kind"] == "special":
				specials.append(fight.round_number - 1)
				if bool(event.get("guarded", false)):
					guarded_special = event
			if event["kind"] == "enraged":
				enraged_at = fight.monster_hp
			if event["kind"] == "charging":
				charges.append(fight.round_number - 1)
	if charges.is_empty() or charges[0] != 2:
		failures.append("boss: the golem warns of its steam blast the round before (round 2), got rounds %s" % str(charges))

	if specials.is_empty() or specials[0] != 3:
		failures.append("boss: the first steam blast should come in round 3, got rounds %s" % str(specials))
	if not guarded_special.is_empty() and int(guarded_special["damage"]) > 6:
		failures.append("boss: a guarded 2d6 steam blast is halved (6 at most), got %d" % int(guarded_special["damage"]))
	if fight.enraged and (enraged_at == -1 or enraged_at * 2 > fight.monster_hp_max):
		failures.append("boss: the golem gets enraged at half HP or less, not at %d" % enraged_at)
	if fight.monster_hp * 2 <= fight.monster_hp_max and not fight.enraged and not fight.is_over():
		failures.append("boss: under half HP the golem should be enraged")
	return failures


func _finish_checks() -> Array:
	var failures: Array = []
	var world := MapLoader.load_world(MapLoader.MAPS_DIR, ContentLoader.load_csv("res://content/data/locations.csv"))
	# Won: gold and the creature leaves.
	var state := _new_state()
	WorldState.settle(state, world)
	state["creatures"] = [{"id": "rust_wolf", "near": "", "square": state["square"], "cell": [3, 3]}]
	var fight := Fight.begin(state, Dice.new(2), WOLF, ITEMS, 0)
	fight.monster_hp = 1
	var guard := 0
	while not fight.is_over() and guard < 40:
		fight.act("attack")
		guard += 1
	if fight.result == Fight.WON:
		var gold_before := int(state["gold"])
		var summary := fight.finish(world)
		if int(state["gold"]) != gold_before + 3 or summary["gold"] != 3:
			failures.append("finish: a won fight gives the wolf's 3 gold")
		if not state["creatures"].is_empty():
			failures.append("finish: the defeated wolf should leave the state")
	else:
		failures.append("finish: a wolf at 1 HP should lose this seeded fight, got %s" % fight.result)
	# Lost: half HP, back at the start, hours later.
	state = _new_state()
	WorldState.settle(state, world)
	state["square"] = "mill_inside"
	state["hero_cell"] = [8, 10]
	state["hero"]["hp"] = 1
	var time_before := int(state["time_minutes"])
	var golem := Fight.begin(state, Dice.new(4), GOLEM, ITEMS)
	guard = 0
	while not golem.is_over() and guard < 40:
		golem.act("guard")
		guard += 1
	if golem.result != Fight.LOST:
		failures.append("finish: a 1 HP hero who only guards should lose to the golem, got %s" % golem.result)
	else:
		golem.finish(world)
		if int(state["hero"]["hp"]) != 6:
			failures.append("finish: after a loss the hero wakes with half HP (6), got %d" % int(state["hero"]["hp"]))
		if state["square"] != world.place_square(WorldState.START_PLACE):
			failures.append("finish: after a loss the hero wakes at the start place, got %s" % state["square"])
		if int(state["time_minutes"]) < time_before + Fight.KNOCKED_OUT_MINUTES:
			failures.append("finish: a loss costs hours")
	return failures


func _content_checks() -> Array:
	var failures: Array = []
	var monsters := ContentLoader.by_id(ContentLoader.load_csv("res://content/data/monsters.csv"))
	for id in ["rust_wolf", "brass_beetle", "mill_golem"]:
		if not monsters.has(id):
			failures.append("content: monsters.csv should have %s" % id)
	if MapLoader.parse_bool(monsters.get("mill_golem", {}).get("boss")) != 1:
		failures.append("content: the mill golem is the boss")
	var dice := Dice.new(1)
	for id in monsters:
		for column in ["damage", "special_damage"]:
			var value: Variant = monsters[id].get(column)
			if value != null and not str(value).is_empty() and dice.roll_notation(str(value)).is_empty():
				failures.append("content: %s.%s is not dice notation" % [id, column])
	return failures
