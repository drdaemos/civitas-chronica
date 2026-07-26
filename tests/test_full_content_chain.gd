extends RefCounted

## Integration coverage over the real five-Age content chain. Unit fixtures
## exercise transition mechanics in isolation; this suite catches broken age
## links, demand activation order, real supersession targets, and empty rebuilt
## pools in the authored database.


func run(t: TestContext) -> bool:
	var db: ContentDB = ContentDB.load_from_dir("res://content")
	t.label("expanded content validates before integration traversal")
	t.eq(db.validate(), [], "real content database is valid")
	t.eq(db.cards.size(), 302, "expanded card count")
	t.eq(db.events.size(), 100, "expanded event count")
	t.eq(db.interactions.size(), 25, "expanded interaction count")
	t.eq(db.policies.size(), 20, "expanded policy count")
	t.eq(db.ages.size(), 5, "five authored ages")

	var expected_chain: Array[String] = ["age1", "age2", "age3", "age4", "age5"]
	var expected_demands: Array[String] = [
		"provision", "security", "fairness", "health", "appeal",
	]
	var state: GameState = GameSetup.new_game(db, "age1", 24680)
	var engine := TurnEngine.new(db, state)
	var preserved_population: int = state.population_count
	_add_development(state, db, "city_walls")
	_add_development(state, db, "parish_school")
	_add_development(state, db, "town_market")

	for i: int in expected_chain.size():
		var age_id: String = expected_chain[i]
		var age: AgeDef = db.get_age(age_id)
		t.label("real transition coverage: " + age_id)
		t.eq(state.age_id, age_id, "entered expected age")
		t.eq(state.active_demands.size(), i + 1, "one additional demand is active")
		for demand_index: int in range(i + 1):
			t.is_true(expected_demands[demand_index] in state.active_demands,
				"expected demand remains active: " + expected_demands[demand_index])
		t.is_true(not state.main_deck.is_empty(), "age has a playable main deck")
		t.is_true(not state.event_deck.is_empty(), "age has an ordinary event deck")
		t.eq(state.turn_number, 0, "transition leaves the new age before turn 1")

		if age_id == "age2":
			t.is_true(state.has_development("wall_ruins"), "walls became ruins")
			t.is_true(state.has_development("grammar_academy"), "school became academy")
			t.is_true(state.has_development("covered_market_hall"), "market was covered")
			_add_development(state, db, "weaving_manufactory")
			_add_development(state, db, "water_works")
		elif age_id == "age3":
			t.is_true(state.has_development("mechanized_mill"), "manufactory mechanized")
			t.is_true(state.has_development("municipal_water_board"), "water works reorganized")
			_add_development(state, db, "early_factory_quarter")
			_add_development(state, db, "infirmary")
			_add_development(state, db, "corn_exchange")
		elif age_id == "age4":
			t.is_true(state.has_development("engineering_works"), "factory quarter became works")
			t.is_true(state.has_development("municipal_hospital"), "infirmary became hospital")
			t.is_true(state.has_development("municipal_market_hall"), "corn exchange became market hall")
			_add_development(state, db, "railway_station")
			_add_development(state, db, "coal_gas_works")
		elif age_id == "age5":
			t.is_true(state.has_development("converted_lofts"), "engineering works became lofts")
			t.is_true(state.has_development("commuter_station"), "railway became commuter station")
			t.is_true(state.has_development("brownfield_reclamation"), "gas works was reclaimed")

		state.hand.clear()
		state.pending_event = ""
		state.year = age.year_end
		if i < expected_chain.size() - 1:
			var end_events: Array[Dictionary] = engine.end_turn()
			t.is_true(state.transition_pending, "non-final age requests a transition")
			t.eq(state.pending_transition_to, expected_chain[i + 1], "transition target")
			t.is_true(_has_type(end_events, "age_ended"), "age_ended emitted")
			var report: TransitionReport = AgeTransition.apply(state, db)
			t.eq(report.from_age, age_id, "report records source age")
			t.eq(report.to_age, expected_chain[i + 1], "report records target age")
			t.eq(report.activated_demand, expected_demands[i + 1], "next demand activates")
			t.eq(state.population_count, preserved_population, "transition preserves population exactly")
			t.eq(state.completed_ages.size(), i + 1, "completed-age ledger grows once")
		else:
			var final_events: Array[Dictionary] = engine.end_turn()
			t.is_true(state.game_over, "final age completion ends the save")
			t.eq(state.outcome, GameState.OUTCOME_WON, "full authored chain is winnable")
			t.is_true(_has_type(final_events, "age_completed"), "age_completed emitted")

	return true


func _add_development(state: GameState, db: ContentDB, card_id: String) -> void:
	var card: CardDef = db.get_card(card_id)
	if card == null or state.has_development(card_id):
		return
	state.developments.append(DevelopmentState.from_card(card, state.turn_number))


func _has_type(events: Array[Dictionary], type_name: String) -> bool:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			return true
	return false
