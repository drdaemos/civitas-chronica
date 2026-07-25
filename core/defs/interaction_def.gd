class_name InteractionDef
extends RefCounted

## Static definition of an interaction effect (GDD 4.2), loaded from
## content/interactions/<id>.json. Once activated it stays active for the
## save (MVP simplification). Instant effects fire once at activation;
## passive effects persist while active.

var id: String = ""
var display_name: String = ""
var description: String = ""
var threshold: ConditionDef = null
var effects: Array[EffectDef] = []


static func from_dict(d: Dictionary) -> InteractionDef:
	var interaction := InteractionDef.new()
	interaction.id = String(d.get("id", ""))
	interaction.display_name = String(d.get("name", interaction.id))
	interaction.description = String(d.get("description", ""))
	if d.has("threshold"):
		interaction.threshold = ConditionDef.from_dict(d.get("threshold"))
	for effect_dict: Variant in d.get("effects", []):
		interaction.effects.append(EffectDef.from_dict(effect_dict))
	return interaction
