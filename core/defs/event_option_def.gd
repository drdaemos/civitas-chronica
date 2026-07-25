class_name EventOptionDef
extends RefCounted

## One choice on an event card. `cost` is billed at the start of the NEXT
## turn (event billing, GDD 3) and may push the budget negative.

var text: String = ""
var cost: int = 0
var effects: Array[EffectDef] = []


static func from_dict(d: Dictionary) -> EventOptionDef:
	var option := EventOptionDef.new()
	option.text = String(d.get("text", ""))
	option.cost = int(d.get("cost", 0))
	for effect_dict: Variant in d.get("effects", []):
		option.effects.append(EffectDef.from_dict(effect_dict))
	return option
