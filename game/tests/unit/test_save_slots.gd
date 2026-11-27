extends RefCounted
## SaveSystem.slots_newest_first (bug B7, SPEC-core): the slots that have a
## file, the last written first; on a tie the earlier slot in the list.

const OLD := "__test_slot_old"
const NEW := "__test_slot_new"
const NONE := "__test_slot_none"


func run() -> Array:
	var failures: Array = []
	if not _has_static(SaveSystem, "slots_newest_first"):
		return ["SaveSystem.slots_newest_first is missing"]
	for slot in [OLD, NEW, NONE]:
		SaveSystem.delete_save(slot)
	var state := GameState.new_game(1)

	if _newest([OLD, NEW]) != []:
		failures.append("no files: no slots")
	SaveSystem.save_game(state, OLD)
	if _newest([NONE, OLD]) != [OLD]:
		failures.append("a slot without a file is left out")
	# File times have one-second steps.
	OS.delay_msec(1100)
	SaveSystem.save_game(state, NEW)
	if _newest([OLD, NEW]) != [NEW, OLD]:
		failures.append("the newer file comes first: %s" % str(_newest([OLD, NEW])))
	if _newest([NEW, OLD]) != [NEW, OLD]:
		failures.append("the order of the list doesn't matter when the times differ")
	if _newest(["../evil", OLD]) != [OLD]:
		failures.append("an invalid slot name is left out")

	# A tie (same second): the earlier slot in the list wins.
	SaveSystem.save_game(state, OLD)
	SaveSystem.save_game(state, NEW)
	var old_time := FileAccess.get_modified_time(SaveSystem._path(OLD))
	var new_time := FileAccess.get_modified_time(SaveSystem._path(NEW))
	if old_time == new_time:
		if _newest([OLD, NEW]) != [OLD, NEW]:
			failures.append("on a tie the earlier slot in the list comes first")
		if _newest([NEW, OLD]) != [NEW, OLD]:
			failures.append("on a tie the earlier slot in the list comes first (reversed)")

	for slot in [OLD, NEW, NONE]:
		SaveSystem.delete_save(slot)
	return failures


## Called by name, so this file still loads (and fails) before the function exists.
func _newest(slots: Array) -> Array:
	return (SaveSystem as Script).call("slots_newest_first", slots)


static func _has_static(script: Script, method: String) -> bool:
	for info in script.get_script_method_list():
		if info["name"] == method:
			return true
	return false
