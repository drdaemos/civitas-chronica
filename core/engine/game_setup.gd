class_name GameSetup
extends RefCounted

## Builds a fresh GameState for an age. Does NOT start the first turn —
## the caller drives TurnEngine.start_turn() when ready.


static func new_game(db: ContentDB, age_id: String, seed_value: int = 0) -> GameState:
	var age: AgeDef = db.get_age(age_id)
	var state := GameState.new()
	state.rng = RngService.new(seed_value)
	state.age_id = age.id
	state.turn_number = 0
	state.year = age.year_start
	state.population = age.start_population
	state.approval = age.start_approval
	state.migration_appeal = age.start_migration
	state.base_budget = age.base_budget
	state.policy_slots = age.policy_slots
	var seen: Dictionary = {}
	for card_id: String in age.base_deck:
		if seen.has(card_id):
			push_error("GameSetup: duplicate base_deck card \"%s\" in age \"%s\"" % [card_id, age.id])
		seen[card_id] = true
	state.main_deck = age.base_deck.duplicate()
	state.rng.shuffle("deck", state.main_deck)
	state.event_deck.assign(age.base_events)
	state.rng.shuffle("events", state.event_deck)
	for policy_id: String in db.policies:
		var policy: PolicyDef = db.policies[policy_id]
		if policy.is_unlocked_from_start():
			state.unlocked_policies.append(policy_id)
	return state
