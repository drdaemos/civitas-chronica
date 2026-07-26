extends RefCounted

## Age transitions (GDD 4.8): boundary suspension, automatic supersession with
## no player input, the transition report, interaction recalc + instant-effect
## gating, deck rebuild under uniqueness (including successor injections), win
## only at the final age, heritage scoring, and a mid-transition save roundtrip.


func run(t: TestContext) -> bool:
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
	t.eq(engine.discard_cards(["cobblestone_roads"]).get("ok"), false, "discard_cards refused")
	t.eq(engine.adopt_policy("civic_charter").get("ok"), false, "adopt_policy refused")

	t.label("apply(): supersession replaces developments in place")
	state.hand.append("festival_of_saints")  # discarded to consumed with the hand
	var report: TransitionReport = AgeTransition.apply(state, db)
	t.eq(state.hand.size(), 0, "hand discarded")
	t.eq(report.hand_discarded, 2, "report counts the discarded hand")
	t.is_true("cobblestone_roads" in state.consumed_cards, "hand card consumed")
	t.is_true("festival_of_saints" in state.consumed_cards, "hand action consumed")
	t.eq(state.developments.size(), 5, "no development leaves the city")
	t.is_true(not state.has_development("town_market"), "the old market is gone")
	var market: DevelopmentState = _dev(state, "covered_market")
	t.is_true(market != null, "the successor stands in its place")
	t.eq(market.tags, ["trade"], "successor tags applied")
	t.eq(market.effects.size(), 1, "successor effects applied")
	t.eq(market.effects[0].amount_int(), 2, "successor income replaces the predecessor's")
	t.eq(market.superseded_count, 1, "supersession counted")
	t.eq(market.turn_played, 1, "the structure keeps the turn it was first built")
	t.is_true("town_market" in state.consumed_cards, "the predecessor joins the ledger")
	var promenade: DevelopmentState = _dev(state, "harbor_promenade")
	t.is_true(promenade != null, "harbor superseded too")
	t.eq(promenade.tags, ["cultural"], "harbor lost its trade tag")
	var docks: DevelopmentState = _dev(state, "river_docks")
	t.eq(docks.superseded_count, 0, "a card with no successor is untouched")
	t.eq(docks.tags, ["trade"], "untouched tags")
	for dev: DevelopmentState in state.developments:
		t.eq(dev.ages_survived, 1, "%s survived one age" % dev.card_id)
	t.eq(state.pending_bill, 0, "supersession bills nothing")
	t.eq(_of_type(report.events, "development_superseded").size(), 2, "2 supersession events")

	t.label("the report is the whole player-facing output")
	t.eq(report.from_age, "test_age_chained", "report names the old age")
	t.eq(report.to_age, "test_age2", "report names the new age")
	t.eq(report.supersessions.size(), 2, "both supersessions listed")
	t.eq(report.supersessions[0].get("from"), "town_market", "listed in city play order")
	t.eq(report.supersessions[0].get("to"), "covered_market", "successor recorded")
	t.eq(report.interactions_lost, ["trade_hub"], "lost interaction reported")
	t.eq(report.interactions_gained, [], "nothing gained here")
	t.eq(report.base_budget, 14, "report carries the new capacity")
	t.eq(report.hand_limit, DeckManager.BASE_HAND_LIMIT, "report carries the hand limit")
	t.is_true(report.has_changes(), "the report has something to show")

	t.label("interaction recalc: tag loss deactivates trade_hub")
	t.is_true("trade_hub" not in state.active_interactions, "trade_hub no longer active")
	t.is_true("trade_hub" in state.interactions_fired, "fired ledger survives deactivation")
	t.eq(_of_type(report.events, "interaction_deactivated").size(), 1, "one deactivation event")

	t.label("age switch state")
	t.eq(state.age_id, "test_age2", "age id switched")
	t.eq(state.base_budget, 14, "new base budget")
	t.eq(state.policy_slots, 2, "policy slots take the max")
	t.eq(state.year, 1700, "year reset to the new age's start")
	t.eq(state.turn_number, 0, "turn counter reset")
	t.eq(state.completed_ages, ["test_age_chained"], "old age recorded as completed")
	t.eq(state.transition_pending, false, "pending flag cleared")
	t.eq(state.pending_transition_to, "", "pending target cleared")
	var last: Dictionary = report.events[report.events.size() - 1]
	t.eq(last.get("type"), "age_transitioned", "age_transitioned emitted last")
	t.eq(last.get("from"), "test_age_chained", "age_transitioned from")
	t.eq(last.get("to"), "test_age2", "age_transitioned to")

	t.label("new decks from age2 pools, plus successor injections")
	var sorted_deck: Array[String] = state.main_deck.duplicate()
	sorted_deck.sort()
	t.eq(sorted_deck, ["market_hall", "printing_press", "steam_mill", "trade_exchange"],
		"town_market and festival_of_saints filtered out; market_hall injected by the successor")
	t.eq(state.event_deck.count("never_event_b"), 2,
		"event deck rebuilt from the age2 pool plus the successor's injection")

	t.label("first turn of the new age")
	var start_events: Array[Dictionary] = engine.start_turn()
	t.eq(state.turn_number, 1, "new age turn 1")
	# capacity 14 + income (covered_market 2, docks 1, foundry 1, promenade 1)
	t.eq(state.current_budget, 19, "capacity + income, nothing billed")
	t.eq((_first_of(start_events, "cards_drawn").get("cards") as Array).size(), 3,
		"drew the age's fixed 3 cards")

	t.label("re-activation after transition does not re-fire instant effects")
	t.eq(Fixtures.force_play(engine, "trade_exchange").get("ok"), true, "trade_exchange built")
	var supply_pre_check: int = state.demand_value("supply")
	var re_events: Array[Dictionary] = InteractionEngine.check(state, db)
	var re_acts: Array[Dictionary] = _of_type(re_events, "interaction_activated")
	t.eq(re_acts.size(), 1, "trade_hub re-activates at 3 trade tags")
	t.eq(re_acts[0].get("id"), "trade_hub", "re-activated interaction is trade_hub")
	t.eq(re_acts[0].get("first_discovery"), false, "not a first discovery")
	t.eq(state.demand_value("supply"), supply_pre_check, "instant demand relief NOT re-applied")

	t.label("win fires only at the end of the FINAL age")
	var safety: int = 30
	while not state.game_over and safety > 0:
		# Demands are held at 0 by fiat: this suite is about the transition, and
		# an unanswered demand would end the save before the age does.
		Fixtures.quiet_demands(state)
		Fixtures.scripted_turn(engine)
		safety -= 1
	t.is_true(state.game_over, "final age eventually ends")
	t.eq(state.outcome, GameState.OUTCOME_WON, "completing the final age wins")
	t.eq(state.transition_pending, false, "no further transition pending")
	t.eq(state.completed_ages, ["test_age_chained"], "only the first age in completed_ages")

	t.label("heritage scoring counts survivors and supersessions")
	var expected_survived: int = 0
	var expected_superseded: int = 0
	for dev: DevelopmentState in state.developments:
		expected_survived += dev.ages_survived
		expected_superseded += dev.superseded_count
	t.eq(expected_superseded, 2, "both supersessions still standing at the end")
	var score: Dictionary = Scoring.score(state, db)
	t.eq(score.get("heritage"), 5 * expected_survived + 10 * expected_superseded,
		"5 per age survived + 10 per supersession")
	t.eq(score.get("total"),
		int(score.get("population")) + int(score.get("specialization")) + int(score.get("heritage")),
		"total sums the three axes")

	t.label("save roundtrip mid-transition preserves behavior")
	var state_a: GameState = _city_at_boundary(db, 77)
	var engine_a := TurnEngine.new(db, state_a)
	Fixtures.quiet_demands(state_a)
	engine_a.end_turn()
	t.eq(state_a.transition_pending, true, "transition pending before snapshot")
	var snapshot: String = JSON.stringify(state_a.to_dict())
	var parsed: Variant = JSON.parse_string(snapshot)
	t.is_true(parsed is Dictionary, "snapshot parses back")
	var state_b: GameState = GameState.from_dict(parsed)
	t.eq(JSON.stringify(state_b.to_dict()), snapshot, "mid-transition state re-serializes identically")
	AgeTransition.apply(state_a, db)
	AgeTransition.apply(state_b, db)
	t.eq(JSON.stringify(state_b.to_dict()), JSON.stringify(state_a.to_dict()),
		"the transition is deterministic on both copies")
	var engine_b := TurnEngine.new(db, state_b)
	Fixtures.scripted_turn(engine_a)
	Fixtures.scripted_turn(engine_b)
	t.eq(JSON.stringify(state_b.to_dict()), JSON.stringify(state_a.to_dict()),
		"both copies keep playing identically after the transition")

	t.label("apply() on a state with no transition pending does nothing")
	var idle: GameState = GameSetup.new_game(db, "test_age", 5)
	var idle_report: TransitionReport = AgeTransition.apply(idle, db)
	t.eq(idle_report.from_age, "", "empty report")
	t.eq(idle_report.events.size(), 0, "no events emitted")
	return true



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
	state.year = 1700  # upkeep already carried the clock to year_end
	state.hand.clear()  # the boundary hand is set up by each test
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


func _dev(state: GameState, card_id: String) -> DevelopmentState:
	for dev: DevelopmentState in state.developments:
		if dev.card_id == card_id:
			return dev
	return null
