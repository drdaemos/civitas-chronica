class_name PolicySystem
extends RefCounted

## Single feature gate for the temporarily disabled policy system. Content and
## save fields remain intact for future work, but policies cannot be adopted
## and do not contribute passive effects while this flag is false.

const ENABLED: bool = false


static func passive_effects(state: GameState, db: ContentDB) -> Array[EffectDef]:
	var effects: Array[EffectDef] = []
	if not ENABLED:
		return effects
	for policy_id: String in state.active_policies:
		var policy: PolicyDef = db.get_policy(policy_id)
		if policy == null:
			continue
		for effect: EffectDef in policy.effects:
			if effect.is_passive():
				effects.append(effect)
	return effects
