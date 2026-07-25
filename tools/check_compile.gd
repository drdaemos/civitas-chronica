extends SceneTree

## Headless compile check: loads every .gd under the source roots and fails
## (exit code 1) if any script has parse errors.
## Run: godot --headless --path . --script res://tools/check_compile.gd

const ROOTS: Array[String] = ["res://core", "res://game", "res://ui", "res://tools", "res://tests"]


func _initialize() -> void:
	var failures: int = 0
	var checked: int = 0
	var autoload_paths: Array[String] = _autoload_script_paths()
	for root_path: String in ROOTS:
		for script_path: String in _scan_gd(root_path):
			if script_path == (get_script() as GDScript).resource_path:
				continue  # cannot reload the running script
			checked += 1
			if script_path in autoload_paths:
				# Autoload singletons have live instances and cannot be
				# reloaded; the fact that they instantiated at startup
				# means they compiled.
				continue
			var script: Variant = ResourceLoader.load(script_path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
			if script == null:
				printerr("COMPILE FAIL: " + script_path)
				failures += 1
			else:
				var gd: GDScript = script
				var err: int = gd.reload()
				if err != OK:
					printerr("COMPILE FAIL: %s (error %d)" % [script_path, err])
					failures += 1
	print("check_compile: %d scripts checked, %d failures" % [checked, failures])
	quit(1 if failures > 0 else 0)


## Script paths registered as autoload singletons in project.godot.
func _autoload_script_paths() -> Array[String]:
	var result: Array[String] = []
	for prop: Dictionary in ProjectSettings.get_property_list():
		var prop_name: String = String(prop.get("name", ""))
		if not prop_name.begins_with("autoload/"):
			continue
		var value: String = String(ProjectSettings.get_setting(prop_name))
		result.append(value.trim_prefix("*"))
	return result


func _scan_gd(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				result.append_array(_scan_gd(full))
		elif entry.ends_with(".gd"):
			result.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
