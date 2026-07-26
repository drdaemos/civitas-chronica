class_name EventDef
extends RefCounted

## Static definition of an event, loaded from content/events/<age>/<id>.json.
## Forced events are scheduled in the AgeDef and bypass trigger matching.
##
## Triggers are deliberately permissive (GDD 4.4): they exist to stop
## narratively impossible situations, not to gate content. What varies between
## cities is how an event resolves — see `hazard` (cancellation by a standing
## development) and EventOptionDef.requires_development (extra options).

var id: String = ""
var title: String = ""
var text: String = ""
var age_id: String = ""  # derived from folder, set by ContentDB
var trigger: ConditionDef = null  # null = always matches
var hazard: String = ""  # "" = no hazard type; see ContentDB.CANONICAL_HAZARDS
## Demand-pressure events (GDD 4.0): shuffled into the deck during upkeep by
## the demand they belong to, not listed in any base pool.
var demand: String = ""    # "" = an ordinary event
var severity: String = ""  # SEVERITY_EMERGENCY | SEVERITY_CATASTROPHE | ""
var options: Array[EventOptionDef] = []

const SEVERITY_EMERGENCY: String = "emergency"
const SEVERITY_CATASTROPHE: String = "catastrophe"


static func from_dict(d: Dictionary) -> EventDef:
	var event := EventDef.new()
	event.id = String(d.get("id", ""))
	event.title = String(d.get("title", event.id))
	event.text = String(d.get("text", ""))
	if d.has("trigger"):
		event.trigger = ConditionDef.from_dict(d.get("trigger"))
	event.hazard = String(d.get("hazard", ""))
	event.demand = String(d.get("demand", ""))
	event.severity = String(d.get("severity", ""))
	for option_dict: Variant in d.get("options", []):
		event.options.append(EventOptionDef.from_dict(option_dict))
	return event


func matches(state: GameState, db: ContentDB) -> bool:
	return trigger == null or trigger.evaluate(state, db)


func is_emergency() -> bool:
	return severity == SEVERITY_EMERGENCY


func is_catastrophe() -> bool:
	return severity == SEVERITY_CATASTROPHE
