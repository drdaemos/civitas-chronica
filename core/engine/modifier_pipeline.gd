class_name ModifierPipeline
extends RefCounted

## Aggregates all PASSIVE effects currently live in a GameState: passive
## effects on developments in play, on active interactions, and on active
## policies. Rebuilt on demand (never cached across mutations) — see GDD 4.2.
##
## Also the single place that answers "what is this demand's growth step"
## (TDD 4.5), so the engine, the validator and the UI all read one calculation.

var _passives: Array[EffectDef] = []
var _state: GameState = null


## Gathers every passive effect from the state's live sources. Development
## passives come from DevelopmentState.effects, NOT the printed CardDef of the
## card originally played — supersession (GDD 4.6) can replace them.
static func collect(state: GameState, db: ContentDB) -> ModifierPipeline:
	var pipeline := ModifierPipeline.new()
	pipeline._state = state
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


func pop_growth_mult() -> float:
	var total: float = 0.0
	for effect: EffectDef in _passives:
		if effect.type == "pop_growth_mult":
			total += effect.amount
	return total


## The per-turn growth step of one demand (GDD 4.0):
##
##     population level + aggravators − mitigators + modifiers   (minimum 0)
##
## Aggravators/mitigators are the printed values of standing developments;
## modifiers come from active interactions and policies. Every term is a count
## of something the player can see on the table. Inactive demands report 0 —
## their printed values are inert until the age activates them.
func demand_growth_step(demand_id: String) -> int:
	if _state == null or not _state.is_demand_active(demand_id):
		return 0
	var step: int = _state.population_level
	step += _state.printed_demand_total(demand_id)
	step += demand_modifier_total(demand_id)
	return maxi(step, 0)


## Growth-step contribution from interactions and policies alone, unfloored —
## the part of the step that is not printed on a development.
func demand_modifier_total(demand_id: String) -> int:
	var total: int = 0
	for effect: EffectDef in _passives:
		if effect.demand != demand_id:
			continue
		match effect.type:
			"demand_modifier":
				total += effect.amount_int()
			"demand_modifier_per_tag":
				total += effect.amount_int() * _state.tag_count(effect.tag)
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
