class_name EventOptionDef
extends RefCounted

## One choice on an event card. `cost` is billed at the start of the NEXT
## turn (event billing, GDD 3) and may push the budget negative.
##
## An option with `requires_development` is hidden unless that card is
## standing in the city (GDD 4.4). It is strictly ADDITIONAL — the
## unconditional options are always available.

var text: String = ""
var cost: int = 0
var requires_development: String = ""  # "" = always available
var effects: Array[EffectDef] = []


static func from_dict(d: Dictionary) -> EventOptionDef:
	var option := EventOptionDef.new()
	option.text = String(d.get("text", ""))
	option.cost = int(d.get("cost", 0))
	option.requires_development = String(d.get("requires_development", ""))
	for effect_dict: Variant in d.get("effects", []):
		option.effects.append(EffectDef.from_dict(effect_dict))
	return option


func is_available(state: GameState) -> bool:
	return requires_development == "" or state.has_development(requires_development)
