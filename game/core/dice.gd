class_name Dice
extends RefCounted
## Seeded dice. The same seed always gives the same rolls, which makes tests and
## replays exact. Save `state()` in the save file and restore it on load.

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


func state() -> int:
	return int(rng.state)


func restore_state(value: int) -> void:
	rng.state = value


## Roll `count` dice with `sides` faces. Returns the individual rolls and total.
func roll(sides: int, count: int = 1, bonus: int = 0) -> Dictionary:
	var rolls: Array[int] = []
	var total := bonus
	for _i in count:
		var value := rng.randi_range(1, sides)
		rolls.append(value)
		total += value
	return {"rolls": rolls, "bonus": bonus, "total": total}


## Reads dice notation like "d20", "2d6+3" or "1d8-1".
func roll_notation(notation: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("^(\\d*)d(\\d+)([+-]\\d+)?$")
	var match := re.search(notation.strip_edges().to_lower())
	if match == null:
		push_error("Dice: bad notation '%s'" % notation)
		return {}
	var count := 1
	if match.get_string(1) != "":
		count = int(match.get_string(1))
	var bonus := 0
	if match.get_string(3) != "":
		bonus = int(match.get_string(3))
	return roll(int(match.get_string(2)), count, bonus)


## d20 check. Advantage > 0 keeps the higher of two rolls, < 0 the lower.
## Both dice are always rolled so the random sequence stays identical.
func check(modifier: int, dc: int, advantage: int = 0) -> Dictionary:
	var first := rng.randi_range(1, 20)
	var second := rng.randi_range(1, 20)
	var d20 := first
	if advantage > 0:
		d20 = maxi(first, second)
	elif advantage < 0:
		d20 = mini(first, second)
	var total := d20 + modifier
	return {
		"d20": d20,
		"modifier": modifier,
		"total": total,
		"dc": dc,
		"success": total >= dc,
		"critical": d20 == 20,
		"fumble": d20 == 1,
	}
