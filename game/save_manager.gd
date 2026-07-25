class_name SaveManager
extends Node

## Autoload "Saves". Persists the run snapshot as versioned JSON under
## user://saves/slot1/. Writes are atomic: the envelope is written to a
## .tmp file first, then renamed over the real save.

const SAVE_DIR: String = "user://saves/slot1"
const SAVE_PATH: String = SAVE_DIR + "/save.json"
const TMP_PATH: String = SAVE_PATH + ".tmp"
const SCHEMA_VERSION: int = 1


func save(state: GameState) -> bool:
	var err: int = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("SaveManager: cannot create %s (error %d)" % [SAVE_DIR, err])
		return false
	var envelope: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"state": state.to_dict(),
	}
	var file: FileAccess = FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open %s for writing (error %d)" % [TMP_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(envelope, "\t"))
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	err = DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("SaveManager: cannot move %s into place (error %d)" % [TMP_PATH, err])
		return false
	return true


func load_game() -> GameState:
	if not has_save():
		return null
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		push_error("SaveManager: save file is empty or unreadable")
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("SaveManager: save file is not valid JSON")
		return null
	var envelope: Dictionary = parsed
	if int(envelope.get("schema_version", 0)) != SCHEMA_VERSION:
		push_error("SaveManager: unsupported save schema version")
		return null
	var state_dict: Variant = envelope.get("state", {})
	if not (state_dict is Dictionary):
		push_error("SaveManager: save envelope has no state")
		return null
	return GameState.from_dict(state_dict as Dictionary)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)
