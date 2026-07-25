extends RefCounted

## Age transitions (GDD 4.8): boundary suspension, decisions() shape,
## preserve/adapt/demolish semantics, interaction recalc + instant-effect
## gating, deck rebuild under uniqueness, win only at the final age,
## heritage scoring, and a mid-transition save roundtrip.


func run(t: TestContext) -> void:
	var db: ContentDB = Fixtures.build_db()

	t.label("end of a non-final age suspends into transition, not game_over")
	var state: GameState = _city_at_boundary(db, 42)
	var engine := TurnEngine.new(db, state)
	var end_events: Array[Dictionary] = engine.end_turn()
	t.eq(state.transition_pending, true, "transition_pending set")
	t.eq(state.pending_transition_to, "test_age2", "target age recorded")
	t.is_true(not state.game_over, "game is NOT over")
	var ended: Dictionary = _first_of(end_events, "age_ended")
	t.eq(ended.get("from"), "test_age_chained", "age_ended carries from")
	t.eq(ended.get("to"), "test_age2", "age_ended carries to")
	t.is_true(_first_of(end_events, "game_over").is_empty(), "no game_over event")
	t.is_true(_first_of(end_events, "age_completed").is_empty(), "no age_completed event")

	t.label("all turn actions are blocked while the transition is pending")
	var turn_before: int = state.turn_number
	t.eq(engine.start_turn().size(), 0, "start_turn returns []")
	t.eq(state.turn_number, turn_before, "turn counter untouched")
	t.eq(engine.end_turn().size(), 0, "end_turn returns []")
	t.eq(engine.resolve_event(0).size(), 0, "resolve_event returns []")
	state.hand.append("cobblestone_roads")
	var refused: Dictionary = engine.play_card("cobblestone_roads")
	t.eq(refused.get("ok"), false, "play_card refused")
	t.is_true(String(refused.get("reason", "")).contains("transition"),
		"refusal names the transition")
	t.eq(engine.adopt_policy("civic_charter").get("ok"), false, "adopt_policy refused")

	t.label("decisions() shape per development")
	var decision_list: Array[Dictionary] = AgeTransition.decisions(state, db)
	t.eq(decision_list.size(), 5, "one entry per development, in play order")
	t.eq(decision_list[0].get("card_id"), "town_market", "play order preserved")
	var market: Dictionary = _entry(decision_list, "town_market")
	t.eq(market.get("name"), "Town Market", "display name carried")
	t.eq(market.get("current_tags"), ["trade"], "current tags reported")
	t.eq((market.get("preserve") as Dictionary).get("tags"), ["trade"],
		"no preserved variant: preserve keeps current tags")
	var market_adapt: Dictionary = market.get("adapt")
	t.eq(market_adapt.get("cost"), 3, "adapt cost from the variant")
	t.eq(market_adapt.get("tags"), ["trade", "cultural"], "adapt tags from the variant")
	t.eq((market.get("demolish") as Dictionary).get("approval"), -3, "default demolish approval")
	var harbor: Dictionary = _entry(decision_list, "harbor_expansion")
	t.eq((harbor.get("preserve") as Dictionary).get("tags"), ["cultural"],
		"preserved variant replaces tags")
	t.eq(harbor.get("adapt"), null, "adapt is null when the variant defines none")
	t.eq((harbor.get("demolish") as Dictionary).get("approval"), -5,
		"variant demolish_approval used")
	var foundry: Dictionary = _entry(decision_list, "iron_foundry")
	t.eq((foundry.get("preserve") as Dictionary).get("tags"), ["industrial"],
		"no variants at all: preserve keeps current tags")
	t.eq(foundry.get("adapt"), null, "no variants at all: adapt null")
	var church: Dictionary = _entry(decision_list, "stone_church")
	t.eq((church.get("preserve") as Dictionary).get("tags"), ["religious", "cultural"],
		"defaults-only variant: preserve keeps current tags")
	t.eq(church.get("adapt"), null, "defaults-only variant: adapt null")
	t.eq((church.get("demolish") as Dictionary).get("approval"), -3,
		"defaults-only variant: default demolish approval")

	t.label("apply(): preserve / adapt / demolish semantics")
	state.hand.append("festival_of_saints")  # discarded to consumed with the hand
	var approval_before: int = state.approval
	var choices: Dictionary = {
		"town_market": "adapt",
		"harbor_expansion": "preserve",
		"stone_church": "demolish",
		"iron_foundry": "adapt",  # invalid (no variant) -> treated as preserve
		# river_docks omitted -> preserve
	}
	var apply_events: Array[Dictionary] = AgeTransition.apply(state, db, choices)
	t.eq(state.hand.size(), 0, "hand discarded")
	t.is_true("cobblestone_roads" in state.consumed_cards, "hand card consumed")
	t.is_true("festival_of_saints" in state.consumed_cards, "hand action consumed")
	t.eq(state.developments.size(), 4, "demolished development removed")
	t.is_true(not state.has_development("stone_church"), "stone_church gone")
	t.is_true("stone_church" in state.consumed_cards, "demolished card consumed")
	t.eq(state.approval, approval_before - 3, "demolish_approval applied")
	var market_dev: DevelopmentState = _dev(state, "town_market")
	t.eq(market_dev.tags, ["trade", "cultural"], "adapt swaps tags")
	t.eq(market_dev.effects.size(), 1, "adapt swaps effects")
	t.eq(market_dev.effects[0].type, "income", "adapted effect type")
	t.eq(market_dev.effects[0].amount_int(), 2, "adapted effect amount")
	t.eq(market_dev.adapted, true, "adapt marks the development")
	t.eq(state.pending_bill, 3, "adapt cost billed to the new age's first turn")
	var harbor_dev: DevelopmentState = _dev(state, "harbor_expansion")
	t.eq(harbor_dev.tags, ["cultural"], "preserved variant swaps tags")
	t.eq(harbor_dev.effects.size(), 1, "preserved variant swaps effects")
	t.eq(harbor_dev.effects[0].type, "approval_per_turn", "preserved effect type")
	t.eq(harbor_dev.adapted, false, "preserve does not mark adapted")
	var docks_dev: DevelopmentState = _dev(state, "river_docks")
	t.eq(docks_dev.tags, ["trade"], "no variant: preserve keeps tags")
	t.eq(docks_dev.effects[0].type, "income", "no variant: preserve keeps effects")
	var foundry_dev: DevelopmentState = _dev(state, "iron_foundry")
	t.eq(foundry_dev.adapted, false, "invalid adapt fell back to preserve")
	t.eq(foundry_dev.tags, ["industrial"], "invalid adapt kept tags")
	for dev: DevelopmentState in state.developments:
		t.eq(dev.ages_survived, 1, "%s survived one age" % dev.card_id)
	t.eq(_of_type(apply_events, "development_preserved").size(), 3, "3 preserved events")
	t.eq(_of_type(apply_events, "development_adapted").size(), 1, "1 adapted event")
	t.eq(_of_type(apply_events, "development_demolished").size(), 1, "1 demolished event")

	t.label("interaction recalc: tag loss deactivates trade_hub")
	var deactivated: Array[Dictionary] = _of_type(apply_events, "interaction_deactivated")
	t.eq(deactivated.size(), 1, "one deactivation")
	t.eq(deactivated[0].get("id"), "trade_hub", "trade_hub deactivated (2 trade tags left)")
	t.is_true("trade_hub" not in state.active_interactions, "trade_hub no longer active")
	t.is_true("trade_hub" in state.interactions_fired, "fired ledger survives deactivation")

	t.label("age switch state")
	t.eq(state.age_id, "test_age2", "age id switched")
	t.eq(state.base_budget, 14, "new base budget")
	t.eq(state.policy_slots, 2, "policy slots take the max")
	t.eq(state.year, 1700, "year reset to the new age's start")
	t.eq(state.turn_number, 0, "turn counter reset")
	t.eq(state.completed_ages, ["test_age_chained"], "old age recorded as completed")
	t.eq(state.transition_pending, false, "pending flag cleared")
	t.eq(state.pending_transition_to, "", "pending target cleared")
	var last: Dictionary = apply_events[apply_events.size() - 1]
	t.eq(last.get("type"), "age_transitioned", "age_transitioned emitted last")
	t.eq(last.get("from"), "test_age_chained", "age_transitioned from")
	t.eq(last.get("to"), "test_age2", "age_transitioned to")

	t.label("new decks from age2 pools with the uniqueness filter")
	var sorted_deck: Array[String] = state.main_deck.duplicate()
	sorted_deck.sort()
	t.eq(sorted_deck, ["printing_press", "steam_mill", "trade_exchange"],
		"built town_market and consumed festival_of_saints filtered out")
	t.eq(state.event_deck, ["never_event_b"], "event deck rebuilt from age2 pool")

	t.label("adapt cost billed on the new age's first turn")
	var start_events: Array[Dictionary] = engine.start_turn()
	t.eq(state.turn_number, 1, "new age turn 1")
	# capacity 14 + income (market 2 + docks 1 + foundry 1) = 18, minus bill 3
	t.eq(state.current_budget, 15, "capacity + income - adapt bill")
	t.eq(state.pending_bill, 0, "bill cleared after charging")
	t.eq((_first_of(start_events, "cards_drawn").get("cards") as Array).size(), 3,
		"drew the whole 3-card age2 deck")

	t.label("re-activation after transition does not re-fire instant effects")
	t.eq(Fixtures.force_play(engine, "trade_exchange").get("ok"), true, "trade_exchange built")
	var approval_pre_check: int = state.approval
	var re_events: Array[Dictionary] = InteractionEngine.check(state, db)
	var re_acts: Array[Dictionary] = _of_type(re_events, "interaction_activated")
	t.eq(re_acts.size(), 1, "trade_hub re-activates at 3 trade tags")
	t.eq(re_acts[0].get("id"), "trade_hub", "re-activated interaction is trade_hub")
	t.eq(re_acts[0].get("first_discovery"), false, "not a first discovery")
	t.eq(state.approval, approval_pre_check, "instant approval bonus NOT re-applied")

	t.label("win fires only at the end of the FINAL age")
	var safety: int = 30
	while not state.game_over and safety > 0:
		Fixtures.scripted_turn(engine)
		safety -= 1
	t.is_true(state.game_over, "final age eventually ends")
	t.eq(state.outcome, GameState.OUTCOME_WON, "completing the final age wins")
	t.eq(state.transition_pending, false, "no further transition pending")
	t.eq(state.completed_ages, ["test_age_chained"], "only the first age in completed_ages")

	t.label("heritage scoring counts survivors and adapted developments")
	var score: Dictionary = Scoring.score(state, db)
	t.eq(score.get("heritage"), 5 * 4 + 10 * 1, "4 survivors, 1 adapted")
	t.eq(score.get("total"),
		int(score.get("population")) + int(score.get("specialization")) + int(score.get("heritage")),
		"total sums the three axes")

	t.label("save roundtrip mid-transition preserves behavior")
	var state_a: GameState = _city_at_boundary(db, 77)
	var engine_a := TurnEngine.new(db, state_a)
	engine_a.end_turn()
	t.eq(state_a.transition_pending, true, "transition pending before snapshot")
	var snapshot: String = JSON.stringify(state_a.to_dict())
	var parsed: Variant = JSON.parse_string(snapshot)
	t.is_true(parsed is Dictionary, "snapshot parses back")
	var state_b: GameState = GameState.from_dict(parsed)
	t.eq(JSON.stringify(state_b.to_dict()), snapshot, "mid-transition state re-serializes identically")
	var same_choices: Dictionary = {"harbor_expansion": "demolish", "town_market": "adapt"}
	AgeTransition.apply(state_a, db, same_choices)
	AgeTransition.apply(state_b, db, same_choices)
	t.eq(JSON.stringify(state_b.to_dict()), JSON.stringify(state_a.to_dict()),
		"identical choices produce identical post-transition states")
	var engine_b := TurnEngine.new(db, state_b)
	Fixtures.scripted_turn(engine_a)
	Fixtures.scripted_turn(engine_b)
	t.eq(JSON.stringify(state_b.to_dict()), JSON.stringify(state_a.to_dict()),
		"both copies keep playing identically after the transition")


# --- helpers -----------------------------------------------------------------

## A test_age_chained city one end_turn away from the age boundary, with
## trade_hub active (town_market + river_docks + harbor_expansion) plus
## stone_church and iron_foundry, and an empty event deck so the boundary
## end_turn cannot be interrupted by an event.
func _city_at_boundary(db: ContentDB, seed_value: int) -> GameState:
	var state: GameState = GameSetup.new_game(db, "test_age_chained", seed_value)
	var engine := TurnEngine.new(db, state)
	engine.start_turn()
	state.hand.clear()
	Fixtures.force_play(engine, "town_market")
	Fixtures.force_play(engine, "river_docks")
	Fixtures.force_play(engine, "harbor_expansion")
	Fixtures.force_play(engine, "stone_church")
	Fixtures.force_play(engine, "iron_foundry")
	InteractionEngine.check(state, db)  # activates trade_hub
	state.event_deck.clear()
	state.year = 1692  # +8 on end_turn -> 1700 == year_end
	return state


func _first_of(events: Array[Dictionary], type_name: String) -> Dictionary:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			return event
	return {}


func _of_type(events: Array[Dictionary], type_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			result.append(event)
	return result


func _entry(decision_list: Array[Dictionary], card_id: String) -> Dictionary:
	for entry: Dictionary in decision_list:
		if String(entry.get("card_id", "")) == card_id:
			return entry
	return {}


func _dev(state: GameState, card_id: String) -> DevelopmentState:
	for dev: DevelopmentState in state.developments:
		if dev.card_id == card_id:
			return dev
	return null
