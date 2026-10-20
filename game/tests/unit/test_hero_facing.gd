extends RefCounted
## Direction -> walk animation in 8 directions, with the art guide's fallbacks.

const PLACEHOLDER := ["idle_down", "walk_down", "walk_up", "walk_left", "walk_right", "attack_down"]
const RIGHT_ONLY := ["idle_down", "walk_down", "walk_up", "walk_right", "walk_down_right", "walk_up_right"]
const FULL := [
	"idle_down", "walk_down", "walk_up", "walk_right", "walk_left",
	"walk_down_right", "walk_up_right", "walk_down_left", "walk_up_left",
]


func run() -> Array:
	var failures: Array = []
	# direction, available animations, expected animation, expected mirror
	var cases := [
		[Vector2.RIGHT, PLACEHOLDER, "walk_right", false],
		[Vector2.LEFT, PLACEHOLDER, "walk_left", false],
		[Vector2.UP, PLACEHOLDER, "walk_up", false],
		[Vector2.DOWN, PLACEHOLDER, "walk_down", false],
		[Vector2(1, 1), PLACEHOLDER, "walk_right", false],
		[Vector2(-1, 1), PLACEHOLDER, "walk_left", false],
		[Vector2(1, -1), PLACEHOLDER, "walk_right", false],
		[Vector2(-1, -1), PLACEHOLDER, "walk_left", false],
		[Vector2.LEFT, RIGHT_ONLY, "walk_right", true],
		[Vector2(-1, 1), RIGHT_ONLY, "walk_down_right", true],
		[Vector2(-1, -1), RIGHT_ONLY, "walk_up_right", true],
		[Vector2(1, 1), FULL, "walk_down_right", false],
		[Vector2(-1, -1), FULL, "walk_up_left", false],
		[Vector2(-1, 1), FULL, "walk_down_left", false],
		[Vector2(1, 0.2), FULL, "walk_right", false],
	]
	for case in cases:
		var choice := HeroFacing.pick(case[0], "down", PackedStringArray(case[1]))
		if choice["animation"] != case[2] or choice["flip_h"] != case[3]:
			failures.append("%s: expected %s (mirror %s), got %s" % [case[0], case[2], case[3], str(choice)])

	var idle := HeroFacing.pick(Vector2.ZERO, "up_left", PackedStringArray(PLACEHOLDER))
	if idle["animation"] != "idle_down" or idle["facing"] != "up_left":
		failures.append("a missing idle should fall back to idle_down: %s" % str(idle))
	return failures
