class_name ControlsStore
extends RefCounted
## The [controls] section of the device settings file (user://settings.cfg):
## which keys move the hero and whether a click walks. It is a device
## setting, like the language: never in a save. Other sections are kept.
##
## Layouts: "wasd" (QWERTY keyboards), "zqsd" (AZERTY keyboards, common in
## France), "arrows" (arrow keys only). The arrow keys always move the hero,
## whatever the layout.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "controls"
const LAYOUTS := ["wasd", "zqsd", "arrows"]
## Up, left, down, right for each layout.
const KEYS := {
	"wasd": [KEY_W, KEY_A, KEY_S, KEY_D],
	"zqsd": [KEY_Z, KEY_Q, KEY_S, KEY_D],
	"arrows": [],
}
const ARROWS := [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]

## Where the file lives. Tests use their own file, never the real one.
var path := DEFAULT_PATH
var layout := "wasd"
var click_to_move := true


## Reads [controls]; a missing file or an unknown value gives the defaults.
static func read(settings_path: String = DEFAULT_PATH) -> ControlsStore:
	var store := ControlsStore.new()
	store.path = settings_path
	var file := ConfigFile.new()
	if file.load(settings_path) != OK:
		return store
	var saved := str(file.get_value(SECTION, "layout", "wasd"))
	store.layout = saved if saved in LAYOUTS else "wasd"
	store.click_to_move = file.get_value(SECTION, "click_to_move", true) == true
	return store


## Writes [controls] and keeps every other section of the file.
func write() -> Error:
	var file := ConfigFile.new()
	file.load(path)  # Keeps the other sections; fails harmlessly the first time.
	file.set_value(SECTION, "layout", layout if layout in LAYOUTS else "wasd")
	file.set_value(SECTION, "click_to_move", click_to_move)
	return file.save(path)


## The keys of the layout: up, left, down, right (keycodes).
func move_keys() -> Array:
	return KEYS.get(layout, [])


## Which way the held keys point: x and y each -1, 0 or 1. `pressed` tells
## whether a keycode is held (Input.is_key_pressed in the game; tests pass
## their own).
func direction(pressed: Callable = Callable(Input, "is_key_pressed")) -> Vector2i:
	var out := Vector2i.ZERO
	for keys in [move_keys(), ARROWS]:
		if keys.size() != 4:
			continue
		if pressed.call(keys[0]):
			out.y -= 1
		if pressed.call(keys[2]):
			out.y += 1
		if pressed.call(keys[1]):
			out.x -= 1
		if pressed.call(keys[3]):
			out.x += 1
	return Vector2i(clampi(out.x, -1, 1), clampi(out.y, -1, 1))


## Does this key belong to the movement keys (so other shortcuts skip it)?
func is_move_key(keycode: int) -> bool:
	return keycode in move_keys() or keycode in ARROWS
