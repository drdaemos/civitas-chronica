class_name ModifierPipeline
extends RefCounted

## Aggregates all PASSIVE effects currently live in a GameState: passive
## effects on developments in play, on active interactions, and on active
## policies. Rebuilt on demand (never cached across mutations) — see GDD 4.2.

var _passives: Array[EffectDef] = []


## Gathers every passive effect from the state's live sources. Development
## passives come from DevelopmentState.effects, NOT the CardDef — era
## reinterpretation (GDD 4.6) can change what a development does.
static func collect(state: GameState, db: ContentDB) -> ModifierPipeline:
	var pipeline := ModifierPipeline.new()
	for dev: DevelopmentState in state.developments:
		pipeline._add_passives(dev.effects)
	for interaction_id: String in state.active_interactions:
		var interaction: InteractionDef = db.get_interaction(interaction_id)
		if interaction != null:
			pipeline._add_passives(interaction.effects)
	for policy_id: String in state.active_policies:
		var policy: PolicyDef = db.get_policy(policy_id)
		if policy != null:
			pipeline._add_passives(policy.effects)
	return pipeline


## Effective cost of a card: base cost plus all matching cost_modifier
## amounts (tag "" matches all cards; a named tag matches developments with
## that tag), then the LARGEST min_cost floor among matching modifiers that
## declare one, then floored at 0.
func cost_of(card: CardDef) -> int:
	var cost: int = card.cost
	var min_floor: int = -1
	for effect: EffectDef in _passives:
		if effect.type != "cost_modifier":
			continue
		if effect.tag != "" and effect.tag not in card.tags:
			continue
		cost += effect.amount_int()
		if effect.min_cost >= 0 and effect.min_cost > min_floor:
			min_floor = effect.min_cost
	if min_floor >= 0:
		cost = maxi(cost, min_floor)
	return maxi(cost, 0)


func income_total() -> int:
	return _sum_int("income")


func approval_per_turn() -> int:
	return _sum_int("approval_per_turn")


func migration_per_turn() -> int:
	return _sum_int("migration_per_turn")


func draw_bonus() -> int:
	return _sum_int("draw_bonus")


func pop_growth_mult() -> float:
	var total: float = 0.0
	for effect: EffectDef in _passives:
		if effect.type == "pop_growth_mult":
			total += effect.amount
	return total


func _add_passives(effects: Array[EffectDef]) -> void:
	for effect: EffectDef in effects:
		if effect.is_passive():
			_passives.append(effect)


func _sum_int(effect_type: String) -> int:
	var total: int = 0
	for effect: EffectDef in _passives:
		if effect.type == effect_type:
			total += effect.amount_int()
	return total
