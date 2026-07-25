extends SceneTree

## Headless test runner: scans res://tests for test_*.gd suites, instantiates
## each and calls run(t) with a shared TestContext (tests/test_context.gd).
## Run: godot --headless --path . --script res://tools/run_tests.gd


func _initialize() -> void:
	var ctx := TestContext.new()
	var files: Array[String] = _scan_suites("res://tests")
	if files.is_empty():
		printerr("run_tests: no test suites found under res://tests")
		quit(1)
		return
	for file_name: String in files:
		var script: GDScript = load("res://tests/" + file_name)
		if script == null:
			printerr("run_tests: failed to load " + file_name)
			ctx.failures += 1
			continue
		var suite: RefCounted = script.new()
		if suite == null or not suite.has_method("run"):
			continue  # e.g. test_context.gd itself
		ctx.suite_name = file_name
		ctx.test_name = ""
		suite.call("run", ctx)
	print("tests: %d assertions, %d failures" % [ctx.assertions, ctx.failures])
	quit(1 if ctx.failures > 0 else 0)


func _scan_suites(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.begins_with("test_") and entry.ends_with(".gd"):
			result.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
