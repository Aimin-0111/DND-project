extends RefCounted
## Smoke test: proves the headless runner loads, runs and reports.


func run() -> Array:
	var failures: Array = []
	var version := Engine.get_version_info()
	if int(version.get("major", 0)) < 4:
		failures.append("Godot 4 is required, found %s" % str(version))
	return failures
