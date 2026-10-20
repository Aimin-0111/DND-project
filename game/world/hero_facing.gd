class_name HeroFacing
extends RefCounted
## Picks the walk animation for a move direction, in 8 directions, with the
## fallbacks from GUIDE-ARTISTE.md: a left-facing walk can be the right one
## mirrored, a missing diagonal uses the left/right walk, any idle falls back
## to idle_down. Placeholder art usually has only 4 directions.

## Sectors of 45 degrees, clockwise from right (screen y points down).
const DIRECTIONS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]


## Returns {"facing": String, "animation": String, "flip_h": bool}.
## `available` lists the animation names the sprite sheet has.
static func pick(direction: Vector2, facing: String, available: PackedStringArray) -> Dictionary:
	if direction == Vector2.ZERO:
		var idle := "idle_" + facing
		if not idle in available:
			idle = "idle_down"
		return {"facing": facing, "animation": idle, "flip_h": false}
	var sector := posmod(roundi(direction.angle() / (PI / 4.0)), 8)
	var new_facing: String = DIRECTIONS[sector]
	for candidate in _candidates(new_facing):
		if candidate[0] in available:
			return {"facing": new_facing, "animation": candidate[0], "flip_h": candidate[1]}
	return {"facing": new_facing, "animation": "idle_down", "flip_h": false}


## [animation, mirrored] pairs, best first.
static func _candidates(facing: String) -> Array:
	var out := [["walk_" + facing, false]]
	if facing.ends_with("left"):
		out.append(["walk_" + facing.replace("left", "right"), true])
	if facing.begins_with("down_") or facing.begins_with("up_"):
		var side := facing.get_slice("_", 1)
		out.append(["walk_" + side, false])
		if side == "left":
			out.append(["walk_right", true])
	return out
