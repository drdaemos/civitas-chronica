class_name AgeDef
extends RefCounted

## Static definition of an age, loaded from content/ages/<id>.json.

var id: String = ""
var display_name: String = ""
var year_start: int = 0
var year_end: int = 0
var years_per_turn: int = 8
var base_draw: int = 3
var base_budget: int = 10
var policy_slots: int = 1
var activates_demand: String = ""       # demand that becomes active with this age (GDD 4.0)
var population_growth_base: int = 0     # per-turn count delta before multiplier and variance
var start_population_count: int = 0     # first age of a save only
var base_deck: Array[String] = []          # flat unique card IDs (uniqueness rule)
var base_events: Array[String] = []
var forced_events: Array[Dictionary] = []  # [{"event": String, "turn": int}]
var next_age: String = ""                  # "" = final age; completing it wins


static func from_dict(d: Dictionary) -> AgeDef:
	var age := AgeDef.new()
	age.id = String(d.get("id", ""))
	age.display_name = String(d.get("name", age.id))
	age.year_start = int(d.get("year_start", 0))
	age.year_end = int(d.get("year_end", 0))
	age.years_per_turn = int(d.get("years_per_turn", 8))
	age.base_draw = int(d.get("base_draw", 3))
	age.base_budget = int(d.get("base_budget", 10))
	age.policy_slots = int(d.get("policy_slots", 1))
	age.activates_demand = String(d.get("activates_demand", ""))
	age.population_growth_base = int(d.get("population_growth_base", 0))
	var start: Dictionary = d.get("start", {})
	age.start_population_count = int(start.get("population_count", 0))
	age.base_deck.assign(d.get("base_deck", []))
	age.base_events.assign(d.get("base_events", []))
	for entry: Variant in d.get("forced_events", []):
		age.forced_events.append(entry as Dictionary)
	age.next_age = String(d.get("next_age", ""))
	return age


func total_turns() -> int:
	@warning_ignore("integer_division")
	return (year_end - year_start) / years_per_turn


## Forced event scheduled for the given turn, or "" if none.
func forced_event_for_turn(turn: int) -> String:
	for entry: Dictionary in forced_events:
		if int(entry.get("turn", -1)) == turn:
			return String(entry.get("event", ""))
	return ""
