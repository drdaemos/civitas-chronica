class_name ProfileManager
extends Node

## Autoload "Profile". Account-level discovery memory (GDD 4.2 unified
## learning contract): interactions and events, once discovered in ANY save,
## stay known forever. Saved immediately on every new discovery, so a lost
## run still keeps its discoveries.

const PROFILE_PATH: String = "user://profile.json"
const SCHEMA_VERSION: int = 1

var discovered_interactions: Array[String] = []
var discovered_events: Array[String] = []


func _ready() -> void:
	load_profile()


func knows_interaction(interaction_id: String) -> bool:
	return interaction_id in discovered_interactions


func knows_event(event_id: String) -> bool:
	return event_id in discovered_events


func record_interaction(interaction_id: String) -> void:
	if interaction_id == "" or interaction_id in discovered_interactions:
		return
	discovered_interactions.append(interaction_id)
	save_profile()


func record_event(event_id: String) -> void:
	if event_id == "" or event_id in discovered_events:
		return
	discovered_events.append(event_id)
	save_profile()


func load_profile() -> void:
	discovered_interactions.clear()
	discovered_events.clear()
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var text: String = FileAccess.get_file_as_string(PROFILE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("ProfileManager: profile.json is not valid JSON; starting fresh")
		return
	var data: Dictionary = parsed
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		push_error("ProfileManager: unsupported profile schema version; starting fresh")
		return
	discovered_interactions.assign(data.get("discovered_interactions", []))
	discovered_events.assign(data.get("discovered_events", []))


func save_profile() -> void:
	var data: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"discovered_interactions": Array(discovered_interactions),
		"discovered_events": Array(discovered_events),
	}
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ProfileManager: cannot write %s (error %d)" % [PROFILE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
