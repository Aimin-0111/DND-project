class_name Dice
extends RefCounted
## Seeded dice. The same seed always gives the same rolls, which makes
## Rewind, replays and tests exact. Save `rng.state` in the save file.
##
## Usage:
##   var dice := Dice.new(12345)
##   dice.roll_notation("2d6+3")        # {"rolls": [4, 2], "bonus": 3, "total": 9}
##   dice.check(5, 13)                  # d20 + 5 against difficulty 13
##   dice.check(5, 13, 1)               # with advantage (roll twice, keep the best)

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


func roll(sides: int, count: int = 1, bonus: int = 0) -> Dictionary:
	var rolls: Array[int] = []
	var total := bonus
	for i in count:
		var r := rng.randi_range(1, sides)
		rolls.append(r)
		total += r
	return {"rolls": rolls, "bonus": bonus, "total": total}


## Reads dice notation like "d20", "2d6+3" or "1d8-1".
func roll_notation(notation: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("^(\\d*)d(\\d+)([+-]\\d+)?$")
	var m := re.search(notation.strip_edges().to_lower())
	if m == null:
		push_error("Bad dice notation: %s" % notation)
		return {}
	var count := 1
	if m.get_string(1) != "":
		count = int(m.get_string(1))
	var bonus := 0
	if m.get_string(3) != "":
		bonus = int(m.get_string(3))
	return roll(int(m.get_string(2)), count, bonus)


## A d20 check: advantage > 0 keeps the higher of two rolls, < 0 the lower.
## Both dice are always rolled so the random sequence stays the same
## whatever the advantage (important for replays).
func check(modifier: int, dc: int, advantage: int = 0) -> Dictionary:
	var a := rng.randi_range(1, 20)
	var b := rng.randi_range(1, 20)
	var d20 := a
	if advantage > 0:
		d20 = maxi(a, b)
	elif advantage < 0:
		d20 = mini(a, b)
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
