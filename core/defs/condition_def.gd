class_name ConditionDef
extends RefCounted

## Composable condition over GameState. See docs/content-schema.md.

var type: String = "always"
var tag: String = ""
var resource: String = ""
var op: String = ">="
var value: int = 0
var id: String = ""
var conditions: Array[ConditionDef] = []
var condition: ConditionDef = null  # operand of "not"


static func from_dict(d: Dictionary) -> ConditionDef:
	var c := ConditionDef.new()
	c.type = String(d.get("type", "always"))
	c.tag = String(d.get("tag", ""))
	c.resource = String(d.get("resource", ""))
	c.op = String(d.get("op", ">="))
	c.value = int(d.get("value", 0))
	c.id = String(d.get("id", ""))
	for sub: Variant in d.get("conditions", []):
		c.conditions.append(ConditionDef.from_dict(sub))
	if d.has("condition"):
		c.condition = ConditionDef.from_dict(d.get("condition"))
	return c


func evaluate(state: GameState) -> bool:
	match type:
		"always":
			return true
		"tag_count":
			return _compare(state.tag_count(tag), value)
		"resource":
			return _compare(state.get_resource(resource), value)
		"interaction_active":
			return id in state.active_interactions
		"policy_active":
			return id in state.active_policies
		"has_development":
			return state.has_development(id)
		"all_of":
			for c: ConditionDef in conditions:
				if not c.evaluate(state):
					return false
			return true
		"any_of":
			for c: ConditionDef in conditions:
				if c.evaluate(state):
					return true
			return false
		"not":
			return condition == null or not condition.evaluate(state)
		_:
			push_error("Unknown condition type: " + type)
			return false


## Collects referenced content IDs into refs = {"interactions": [], "policies": [], "cards": []}.
## Used by ContentDB.validate().
func collect_refs(refs: Dictionary) -> void:
	match type:
		"interaction_active":
			(refs["interactions"] as Array).append(id)
		"policy_active":
			(refs["policies"] as Array).append(id)
		"has_development":
			(refs["cards"] as Array).append(id)
		"all_of", "any_of":
			for c: ConditionDef in conditions:
				c.collect_refs(refs)
		"not":
			if condition != null:
				condition.collect_refs(refs)


func _compare(actual: int, expected: int) -> bool:
	match op:
		"<":
			return actual < expected
		"<=":
			return actual <= expected
		">":
			return actual > expected
		">=":
			return actual >= expected
		"==":
			return actual == expected
		_:
			push_error("Unknown comparison op: " + op)
			return false
