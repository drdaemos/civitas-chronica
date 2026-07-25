class_name EventDef
extends RefCounted

## Static definition of an event, loaded from content/events/<age>/<id>.json.
## Forced events are scheduled in the AgeDef and bypass trigger matching.

var id: String = ""
var title: String = ""
var text: String = ""
var age_id: String = ""  # derived from folder, set by ContentDB
var trigger: ConditionDef = null  # null = always matches
var options: Array[EventOptionDef] = []


static func from_dict(d: Dictionary) -> EventDef:
	var event := EventDef.new()
	event.id = String(d.get("id", ""))
	event.title = String(d.get("title", event.id))
	event.text = String(d.get("text", ""))
	if d.has("trigger"):
		event.trigger = ConditionDef.from_dict(d.get("trigger"))
	for option_dict: Variant in d.get("options", []):
		event.options.append(EventOptionDef.from_dict(option_dict))
	return event


func matches(state: GameState) -> bool:
	return trigger == null or trigger.evaluate(state)
