class_name PolicyDef
extends RefCounted

## Static definition of a policy (GDD 4.3), loaded from content/policies/<id>.json.

var id: String = ""
var display_name: String = ""
var description: String = ""
var unlock: ConditionDef = null  # null or "always" = available from age start
var swap_cost_budget: int = 0
var swap_cost_approval: int = 0
var effects: Array[EffectDef] = []


static func from_dict(d: Dictionary) -> PolicyDef:
	var policy := PolicyDef.new()
	policy.id = String(d.get("id", ""))
	policy.display_name = String(d.get("name", policy.id))
	policy.description = String(d.get("description", ""))
	if d.has("unlock"):
		policy.unlock = ConditionDef.from_dict(d.get("unlock"))
	policy.swap_cost_budget = int(d.get("swap_cost_budget", 0))
	policy.swap_cost_approval = int(d.get("swap_cost_approval", 0))
	for effect_dict: Variant in d.get("effects", []):
		policy.effects.append(EffectDef.from_dict(effect_dict))
	return policy


func is_unlocked_from_start() -> bool:
	return unlock == null or unlock.type == "always"
