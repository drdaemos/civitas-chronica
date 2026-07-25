class_name TestContext
extends RefCounted

## Minimal assertion context passed to every test suite's run(t).

var assertions: int = 0
var failures: int = 0
var suite_name: String = ""
var test_name: String = ""


## Labels the current test within a suite (shown in failure output).
func label(name: String) -> void:
	test_name = name


func is_true(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures += 1
		printerr("FAIL [%s / %s]: %s" % [suite_name, test_name, msg])


func eq(a: Variant, b: Variant, msg: String) -> void:
	assertions += 1
	if a != b:
		failures += 1
		printerr("FAIL [%s / %s]: %s (got %s, expected %s)" % [suite_name, test_name, msg, str(a), str(b)])
