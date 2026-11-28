class_name Fight
extends RefCounted
## One turn-based fight: the hero against one creature (SPEC-fight.md). The
## game owns every rule and rolls every die with the seeded Dice; the AI
## never takes part, it only hears about the fight in the next prompt (the
## fight's summary goes into the story so far).
##
## Each round the hero picks an action (attack, guard, potion, flee), then
## the creature answers. A boss can't be fled from, uses its special attack
## every `special_every` rounds, and gets angry at half HP: +2 to hit and the
## special one round sooner. The round before a special, the creature
## "charges" it (a warning event), so the player can guard to halve it. The numbers live in data/monsters.csv and
## data/items.csv, so the lead can balance them without code.
##
## act() returns events, plain Dictionaries the fight window turns into text:
## {"who": "hero"/"monster", "kind": ..., and the dice and numbers}.

const ONGOING := "ongoing"
const WON := "won"
const LOST := "lost"
const FLED := "fled"
const ACTIONS := ["attack", "guard", "potion", "flee"]
## Proficiency of a level 1 hero.
const PROFICIENCY := 2
## Damage without a weapon.
const UNARMED := "1d2"
## Guarding adds this to the hero's AC and halves the special attack.
const GUARD_AC := 2
## Fleeing: a Dexterity (Acrobatics) check against this + the creature's level.
const FLEE_DC := 10
## The extra to-hit of an angry boss.
const ENRAGED_BONUS := 2
## Minutes a fight takes, and the minutes lost when the hero is knocked out.
const FIGHT_MINUTES := 5
const KNOCKED_OUT_MINUTES := 8 * 60

var state: Dictionary
var dice: Dice
var monster_id := ""
## The monsters.csv row (ints already parsed by the content loader).
var monster: Dictionary
var monster_hp := 0
var monster_hp_max := 0
var boss := false
var enraged := false
var round_number := 1
var result := ONGOING
## Index of the fought creature in state.creatures (-1 when not from the state).
var creature_index := -1
var _guarding := false
var _items: Array = []


## A fight against a monsters.csv row. `items` is the items.csv table, for
## the hero's weapon damage and the potions' healing.
static func begin(game_state: Dictionary, game_dice: Dice, row: Dictionary, items: Array, index: int = -1) -> Fight:
	var fight := Fight.new()
	fight.state = game_state
	fight.dice = game_dice
	fight.monster = row
	fight.monster_id = str(row.get("id", ""))
	fight.monster_hp_max = maxi(1, int(row.get("hp", 1)))
	fight.monster_hp = fight.monster_hp_max
	fight.boss = MapLoader.parse_bool(row.get("boss")) == 1
	fight.creature_index = index
	fight._items = items
	return fight


static func ability_modifier(score: int) -> int:
	return floori((score - 10) / 2.0)


func hero() -> Dictionary:
	return state["hero"]


func hero_attack_bonus() -> int:
	var abilities: Dictionary = hero()["abilities"]
	return PROFICIENCY + maxi(ability_modifier(int(abilities.get("str", 10))), ability_modifier(int(abilities.get("dex", 10))))


## The weapon's damage dice (the first weapon in the pack with a damage), or unarmed.
func weapon_damage() -> String:
	for entry in state.get("pack", []):
		var row := _item(str(entry.get("id", "")))
		if str(row.get("type", "")) == "weapon" and not _text(row.get("damage")).is_empty() and int(entry.get("qty", 0)) > 0:
			return _text(row.get("damage"))
	return UNARMED


## The first potion in the pack that heals: its id, or "".
func potion_id() -> String:
	for entry in state.get("pack", []):
		var row := _item(str(entry.get("id", "")))
		if not _text(row.get("heal")).is_empty() and int(entry.get("qty", 0)) > 0:
			return str(row["id"])
	return ""


func potions() -> int:
	var id := potion_id()
	for entry in state.get("pack", []):
		if str(entry.get("id", "")) == id:
			return int(entry.get("qty", 0))
	return 0


func can_flee() -> bool:
	return not boss


func is_over() -> bool:
	return result != ONGOING


## One round: the hero's action, then the creature's answer (unless the
## fight ended). An action that can't be done (no potion, fleeing a boss)
## gives one "refused" event and doesn't use the round.
func act(action: String) -> Array:
	var events: Array = []
	if is_over() or not action in ACTIONS:
		return events
	match action:
		"attack":
			events.append(_hero_attack())
		"guard":
			_guarding = true
			events.append({"who": "hero", "kind": "guard"})
		"potion":
			var id := potion_id()
			if id.is_empty():
				return [{"who": "hero", "kind": "refused", "reason": "no_potion"}]
			var heal := _roll(_text(_item(id).get("heal")))
			var before := int(hero()["hp"])
			hero()["hp"] = mini(int(hero()["hp_max"]), before + heal)
			GameState.remove_item(state, id, 1)
			events.append({"who": "hero", "kind": "heal", "amount": int(hero()["hp"]) - before, "item": id})
		"flee":
			if not can_flee():
				return [{"who": "hero", "kind": "refused", "reason": "boss"}]
			var dc := FLEE_DC + int(monster.get("level", 1))
			var check := dice.check(GameState.skill_modifier(hero(), "Acrobatics"), dc)
			if check["success"]:
				result = FLED
				events.append({"who": "hero", "kind": "fled", "d20": check["d20"], "total": check["total"], "dc": dc})
				_end_round()
				return events
			events.append({"who": "hero", "kind": "flee_failed", "d20": check["d20"], "total": check["total"], "dc": dc})
	if monster_hp <= 0:
		result = WON
		events.append({"who": "monster", "kind": "down"})
		_end_round()
		return events
	events.append_array(_monster_turn())
	_end_round()
	return events


## Writes the end of the fight into the state and returns its summary:
## won: the creature leaves the state, its gold is the hero's; lost: the hero
## wakes up at the start place with half HP, hours later; fled: nothing more.
## Every fight takes a few minutes.
func finish(world: WorldMap = null) -> Dictionary:
	state["time_minutes"] = int(state.get("time_minutes", 0)) + FIGHT_MINUTES
	var gold := 0
	match result:
		WON:
			gold = maxi(0, int(monster.get("gold", 0)))
			state["gold"] = int(state.get("gold", 0)) + gold
			var creatures: Array = state.get("creatures", [])
			if creature_index >= 0 and creature_index < creatures.size() \
					and str(creatures[creature_index].get("id", "")) == monster_id:
				creatures.remove_at(creature_index)
		LOST:
			hero()["hp"] = maxi(1, ceili(int(hero()["hp_max"]) / 2.0))
			state["time_minutes"] = int(state["time_minutes"]) + KNOCKED_OUT_MINUTES
			if world != null:
				WorldState.wake_at_start(state, world)
	return {"result": result, "monster": monster_id, "boss": boss, "gold": gold, "rounds": round_number - 1}


func _hero_attack() -> Dictionary:
	var ac := int(monster.get("ac", 10))
	var check := dice.check(hero_attack_bonus(), ac)
	var event := {"who": "hero", "kind": "miss", "d20": check["d20"], "total": check["total"], "ac": ac}
	if check["fumble"] or (not check["success"] and not check["critical"]):
		return event
	var weapon := weapon_damage()
	var damage := _roll(weapon) + maxi(0, hero_attack_bonus() - PROFICIENCY)
	if check["critical"]:
		damage += _roll(weapon)  # a natural 20 rolls the weapon dice twice
		event["kind"] = "critical"
	else:
		event["kind"] = "hit"
	damage = maxi(1, damage)
	monster_hp = maxi(0, monster_hp - damage)
	event["damage"] = damage
	return event


func _monster_turn() -> Array:
	var events: Array = []
	if boss and not enraged and monster_hp * 2 <= monster_hp_max:
		enraged = true
		events.append({"who": "monster", "kind": "enraged"})
	var special := _text(monster.get("special"))
	var every := _special_every()
	if not special.is_empty() and every > 0 and round_number % every == 0:
		var damage := _roll(_text(monster.get("special_damage")))
		if _guarding:
			damage = damage / 2
		damage = maxi(0, damage)
		_hurt_hero(damage)
		events.append({"who": "monster", "kind": "special", "special": special, "damage": damage, "guarded": _guarding})
	else:
		var ac := int(hero().get("ac", 10)) + (GUARD_AC if _guarding else 0)
		var bonus := int(monster.get("attack_bonus", 0)) + (ENRAGED_BONUS if enraged else 0)
		var check := dice.check(bonus, ac)
		var event := {"who": "monster", "kind": "miss", "d20": check["d20"], "total": check["total"], "ac": ac}
		if not check["fumble"] and (check["success"] or check["critical"]):
			var damage := _roll(_text(monster.get("damage")))
			if check["critical"]:
				damage += _roll(_text(monster.get("damage"))) - _bonus_of(_text(monster.get("damage")))
			damage = maxi(1, damage)
			_hurt_hero(damage)
			event["kind"] = "critical" if check["critical"] else "hit"
			event["damage"] = damage
		events.append(event)
	if int(hero()["hp"]) <= 0:
		result = LOST
		events.append({"who": "hero", "kind": "down"})
	elif not special.is_empty() and _special_every() > 0 and (round_number + 1) % _special_every() == 0:
		events.append({"who": "monster", "kind": "charging", "special": special})
	return events


## Rounds between specials (0: none); an angry boss is one round quicker.
func _special_every() -> int:
	var value: Variant = monster.get("special_every")
	var every := int(value) if typeof(value) == TYPE_INT else 0
	if enraged and every > 1:
		every -= 1
	return every



func _hurt_hero(damage: int) -> void:
	hero()["hp"] = maxi(0, int(hero()["hp"]) - damage)


func _end_round() -> void:
	round_number += 1
	_guarding = false
	state["rng_state"] = dice.state()


## Total of a dice notation; 0 for an empty or bad one.
func _roll(notation: String) -> int:
	if notation.is_empty():
		return 0
	var rolled := dice.roll_notation(notation)
	return int(rolled.get("total", 0))


static func _bonus_of(notation: String) -> int:
	var at := maxi(notation.rfind("+"), notation.rfind("-"))
	return notation.substr(at).to_int() if at > 0 else 0


func _item(id: String) -> Dictionary:
	for row in _items:
		if str(row.get("id", "")) == id:
			return row
	return {}


static func _text(value: Variant) -> String:
	return "" if value == null else str(value).strip_edges()
