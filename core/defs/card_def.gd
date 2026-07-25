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
var prerequisites: Array[String] = []
var effects: Array[EffectDef] = []
var inject_main: Array[String] = []
var inject_events: Array[String] = []
var flavor: String = ""
var age_variants: Dictionary = {}  # age_id String -> AgeVariantDef (GDD 4.6)


static func from_dict(d: Dictionary) -> CardDef:
	var card := CardDef.new()
	card.id = String(d.get("id", ""))
	card.display_name = String(d.get("name", card.id))
	card.category = String(d.get("category", CATEGORY_DEVELOPMENT))
	card.cost = int(d.get("cost", 0))
	card.tags.assign(d.get("tags", []))
	card.prerequisites.assign(d.get("prerequisites", []))
	for effect_dict: Variant in d.get("effects", []):
		card.effects.append(EffectDef.from_dict(effect_dict))
	card.inject_main.assign(d.get("inject_main", []))
	card.inject_events.assign(d.get("inject_events", []))
	card.flavor = String(d.get("flavor", ""))
	var variants: Dictionary = d.get("age_variants", {})
	for variant_age_id: String in variants:
		card.age_variants[variant_age_id] = AgeVariantDef.from_dict(variants[variant_age_id])
	return card


func is_development() -> bool:
	return category == CATEGORY_DEVELOPMENT


## Shown to the player as the "opens new paths" hint (GDD 4.1).
func opens_paths() -> bool:
	return not inject_main.is_empty() or not inject_events.is_empty()
