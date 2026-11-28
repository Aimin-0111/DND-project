extends RefCounted
## Controls settings (ui/controls_store.gd): the [controls] section of the
## device settings file, and which way the held keys point.

const TEST_PATH := "user://__test_controls.cfg"


func run() -> Array:
	var failures: Array = []
	DirAccess.remove_absolute(TEST_PATH)
	var store := ControlsStore.read(TEST_PATH)
	if store.layout != "wasd" or not store.click_to_move:
		failures.append("defaults: W A S D and click to move")

	store.layout = "zqsd"
	store.click_to_move = false
	if store.write() != OK:
		failures.append("write: the file should save")
	var file := ConfigFile.new()
	file.load(TEST_PATH)
	file.set_value("ai", "mode", "copy_paste")
	file.save(TEST_PATH)
	store.write()
	file = ConfigFile.new()
	file.load(TEST_PATH)
	if str(file.get_value("ai", "mode", "")) != "copy_paste":
		failures.append("write: other sections of the settings file are kept")
	var again := ControlsStore.read(TEST_PATH)
	if again.layout != "zqsd" or again.click_to_move:
		failures.append("read: the saved layout and click setting come back")
	file.set_value("controls", "layout", "dvorak")
	file.save(TEST_PATH)
	if ControlsStore.read(TEST_PATH).layout != "wasd":
		failures.append("read: an unknown layout falls back to W A S D")

	var keys := {}
	var pressed := func(keycode: int) -> bool: return keys.has(keycode)
	var wasd := ControlsStore.new()
	_hold(keys, {KEY_W: true, KEY_D: true})
	if wasd.direction(pressed) != Vector2i(1, -1):
		failures.append("direction: W + D is up-right, got %s" % wasd.direction(pressed))
	_hold(keys, {KEY_A: true, KEY_D: true})
	if wasd.direction(pressed) != Vector2i.ZERO:
		failures.append("direction: A + D cancel out")
	_hold(keys, {KEY_DOWN: true})
	if wasd.direction(pressed) != Vector2i(0, 1):
		failures.append("direction: the arrow keys always work")
	_hold(keys, {KEY_DOWN: true, KEY_S: true})
	if wasd.direction(pressed) != Vector2i(0, 1):
		failures.append("direction: S and Down together still make one step")
	var azerty := ControlsStore.new()
	azerty.layout = "zqsd"
	_hold(keys, {KEY_Z: true, KEY_Q: true})
	if azerty.direction(pressed) != Vector2i(-1, -1):
		failures.append("direction: Z + Q is up-left on AZERTY, got %s" % azerty.direction(pressed))
	_hold(keys, {KEY_W: true})
	if azerty.direction(pressed) != Vector2i.ZERO:
		failures.append("direction: W doesn't move on the Z Q S D layout")
	var arrows := ControlsStore.new()
	arrows.layout = "arrows"
	_hold(keys, {KEY_W: true, KEY_LEFT: true})
	if arrows.direction(pressed) != Vector2i(-1, 0):
		failures.append("direction: arrows only ignores W, got %s" % arrows.direction(pressed))
	if not wasd.is_move_key(KEY_S) or wasd.is_move_key(KEY_B) or not arrows.is_move_key(KEY_UP):
		failures.append("is_move_key: S and Up move, B doesn't")
	DirAccess.remove_absolute(TEST_PATH)
	return failures


## Lambdas keep the dictionary they saw: change it in place.
func _hold(keys: Dictionary, held: Dictionary) -> void:
	keys.clear()
	keys.merge(held)
