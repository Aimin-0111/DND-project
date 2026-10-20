extends SceneTree
## Minimal headless test runner. Test files extend RefCounted and expose
## run() -> Array, where every entry is a human-readable failure.
##
## Usage:
##   godot --headless --path game --script res://tests/run_tests.gd

const TEST_PATHS := [
	"res://tests/unit/test_smoke.gd",
	"res://tests/unit/test_content_loader.gd",
	"res://tests/unit/test_localization.gd",
	"res://tests/unit/test_dice.gd",
	"res://tests/unit/test_game_state.gd",
	"res://tests/unit/test_save_system.gd",
	"res://tests/unit/test_walk_grid.gd",
	"res://tests/unit/test_hero_facing.gd",
	"res://tests/unit/test_keyword_tagger.gd",
	"res://tests/unit/test_prompt_builder.gd",
	"res://tests/unit/test_dm_reply_parser.gd",
	"res://tests/unit/test_archived_replies.gd",
	"res://tests/integration/test_scene_layout.gd",
	"res://tests/integration/test_ui_actions.gd",
]


func _initialize() -> void:
	# Let the scene tree settle once so _ready() has run on test scenes.
	await process_frame
	_run_all()


func _run_all() -> void:
	var failures: Array[String] = []
	var files := 0
	for path in TEST_PATHS:
		var script = load(path)
		if script == null or not (script is GDScript) or not script.can_instantiate():
			failures.append("%s: failed to load or parse" % path)
			continue
		var test_case = script.new()
		if test_case == null:
			failures.append("%s: failed to instantiate" % path)
			continue
		if not test_case.has_method("run"):
			failures.append("%s: missing run()" % path)
			continue
		var result = test_case.run()
		files += 1
		if not (result is Array):
			failures.append("%s: run() must return Array" % path)
			continue
		for error in result:
			failures.append("%s: %s" % [path, str(error)])
	if failures.is_empty():
		print("PASS: %d test file(s)" % files)
		quit(0)
		return
	printerr("FAIL: %d error(s) in %d test file(s)" % [failures.size(), files])
	for failure in failures:
		printerr("  - %s" % failure)
	quit(1)
