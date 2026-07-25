class_name AgeVariantDef
extends RefCounted

## Era reinterpretation of a development for one target age (GDD 4.6, 4.8).
## Parsed from a card's "age_variants" entry — see docs/content-schema.md.
## Absent "preserved"/"adapted" blocks leave has_preserved/has_adapted false.

var has_preserved: bool = false
var preserved_tags: Array[String] = []
var preserved_effects: Array[EffectDef] = []
var has_adapted: bool = false
var adapt_cost: int = 0
var adapted_tags: Array[String] = []
var adapted_effects: Array[EffectDef] = []
var demolish_approval: int = -3


static func from_dict(d: Dictionary) -> AgeVariantDef:
	var variant := AgeVariantDef.new()
	if d.has("preserved"):
		variant.has_preserved = true
		var preserved: Dictionary = d.get("preserved")
		variant.preserved_tags.assign(preserved.get("tags", []))
		for effect_dict: Variant in preserved.get("effects", []):
			variant.preserved_effects.append(EffectDef.from_dict(effect_dict))
	if d.has("adapted"):
		variant.has_adapted = true
		var adapted: Dictionary = d.get("adapted")
		variant.adapt_cost = int(adapted.get("cost", 0))
		variant.adapted_tags.assign(adapted.get("tags", []))
		for effect_dict: Variant in adapted.get("effects", []):
			variant.adapted_effects.append(EffectDef.from_dict(effect_dict))
	variant.demolish_approval = int(d.get("demolish_approval", -3))
	return variant
