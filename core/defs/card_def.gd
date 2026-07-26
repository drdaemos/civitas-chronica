class_name CardDef
extends RefCounted

## Static definition of a card, loaded from content/cards/<age>/<id>.json.

const CATEGORY_DEVELOPMENT: String = "development"
const CATEGORY_ACTION: String = "action"

var id: String = ""
var display_name: String = ""
var category: String = CATEGORY_DEVELOPMENT
var cost: int = 0
var age_id: String = ""  # derived from folder, set by ContentDB
var tags: Array[String] = []
## Printed demand values (developments only, GDD 4.0). Each value does two
## things with the same number: it moves the meter once on play (clamped at 0)
## and it feeds that demand's growth step while the development stands. Kept
## off the Effect hierarchy deliberately — it has to be reversible on removal
## and re-readable when a demand activates ages later.
var demands: Dictionary = {}  # demand id String -> int
var prerequisites: Array[String] = []
var cancels: Array[String] = []        # hazard types negated while standing (GDD 4.4)
var hand_limit_bonus: int = 0          # rare developments raise the hand limit (GDD 4.1)
var effects: Array[EffectDef] = []
var inject_main: Array[String] = []
var inject_events: Array[String] = []
var flavor: String = ""
var superseded_by: Dictionary = {}  # age_id String -> successor card id (GDD 4.6)


static func from_dict(d: Dictionary) -> CardDef:
	var card := CardDef.new()
	card.id = String(d.get("id", ""))
	card.display_name = String(d.get("name", card.id))
	card.category = String(d.get("category", CATEGORY_DEVELOPMENT))
	card.cost = int(d.get("cost", 0))
	card.tags.assign(d.get("tags", []))
	var printed: Dictionary = d.get("demands", {})
	for demand_id: String in printed:
		card.demands[demand_id] = int(printed[demand_id])
	card.prerequisites.assign(d.get("prerequisites", []))
	card.cancels.assign(d.get("cancels", []))
	card.hand_limit_bonus = int(d.get("hand_limit_bonus", 0))
	for effect_dict: Variant in d.get("effects", []):
		card.effects.append(EffectDef.from_dict(effect_dict))
	card.inject_main.assign(d.get("inject_main", []))
	card.inject_events.assign(d.get("inject_events", []))
	card.flavor = String(d.get("flavor", ""))
	var successors: Dictionary = d.get("superseded_by", {})
	for successor_age_id: String in successors:
		card.superseded_by[successor_age_id] = String(successors[successor_age_id])
	return card


func is_development() -> bool:
	return category == CATEGORY_DEVELOPMENT


## The card that replaces this one when the given age begins, or "" if this
## card carries forward unchanged (GDD 4.6).
func successor_for(target_age_id: String) -> String:
	return String(superseded_by.get(target_age_id, ""))


## Shown to the player as the "opens new paths" hint (GDD 4.1).
func opens_paths() -> bool:
	return not inject_main.is_empty() or not inject_events.is_empty()
