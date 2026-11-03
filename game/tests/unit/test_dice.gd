extends RefCounted
## Seeded dice, notation and save/restore of the RNG state.


func run() -> Array:
	var failures: Array = []

	var first := Dice.new(12345)
	var second := Dice.new(12345)
	for i in 10:
		var a := first.roll(6)
		var b := second.roll(6)
		if int(a["total"]) != int(b["total"]):
			failures.append("same seed diverged at roll %d: %d vs %d" % [i, a["total"], b["total"]])
			break

	var notation := Dice.new(7).roll_notation("2d6+3")
	if int(notation.get("rolls", []).size()) != 2:
		failures.append("2d6+3 should roll two dice")
	if int(notation.get("bonus", 0)) != 3:
		failures.append("2d6+3 should keep bonus 3")
	if int(notation.get("total", 0)) < 5 or int(notation.get("total", 0)) > 15:
		failures.append("2d6+3 total out of range: %s" % str(notation.get("total")))

	var dice := Dice.new(99)
	var before := dice.state()
	var expected: int = int(dice.roll(20)["total"])
	dice.restore_state(before)
	var actual: int = int(dice.roll(20)["total"])
	if expected != actual:
		failures.append("restore_state did not reproduce the roll")

	var check := Dice.new(3).check(5, 13)
	if not check.has("success") or not check.has("d20"):
		failures.append("check() result is missing fields")

	return failures
