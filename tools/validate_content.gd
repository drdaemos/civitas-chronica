extends SceneTree

## Headless content validator. Run from the project root:
##   godot --headless --path . --script res://tools/validate_content.gd
## Exits 0 when content is consistent, 1 when any error is found.


func _initialize() -> void:
	var db: ContentDB = ContentDB.load_from_dir("res://content")
	var errors: Array[String] = db.validate()
	for error: String in errors:
		print(error)
	var loaded: int = db.cards.size() + db.events.size() + db.interactions.size() \
			+ db.policies.size() + db.ages.size()
	print("validate_content: %d definitions loaded, %d errors" % [loaded, errors.size()])
	quit(1 if not errors.is_empty() else 0)
