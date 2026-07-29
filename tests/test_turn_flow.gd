extends RefCounted

## Basic turn cycle: draw, budget, play, hand retention, budget refresh, win.


func run(t: TestContext) -> bool:
	var db: ContentDB = Fixtures.build_db()
	var state: GameState = GameSetup.new_game(db, "test_age", 42)
	var engine := TurnEngine.new(db, state)

	t.label("turn 1 draws 3 with budget 10")
	var events: Array[Dictionary] = engine.start_turn()
	t.eq(state.turn_number, 1, "turn number after first start_turn")
	t.eq(state.hand.size(), 3, "hand size after first draw")
	t.eq(state.current_budget, 10, "budget on turn 1")
	t.eq(_first_of(events, "turn_started").get("budget"), 10, "turn_started reports budget")
	var drawn: Array = _first_of(events, "cards_drawn").get("cards", [])
	t.eq(drawn.size(), 3, "cards_drawn reports 3 cards")

	t.label("a new run may replace turn 1's event phase with its welcome")
	var welcome_state: GameState = GameSetup.new_game(db, "test_age", 42)
	var welcome_engine := TurnEngine.new(db, welcome_state)
	Fixtures.quiet_demands(welcome_state)
	welcome_state.event_deck.assign(["always_event"])
	var welcome_events: Array[Dictionary] = welcome_engine.start_turn(true)
	t.eq(welcome_state.pending_event, "", "no event is pending during the welcome")
	t.is_true(_first_of(welcome_events, "event_fired").is_empty(),
		"the suppressed opening emits no event_fired")
	t.eq(welcome_state.event_deck, ["always_event"],
		"the opening does not consume or reorder the event deck")
	t.eq(welcome_state.hand.size(), 3, "the opening hand is ready behind the welcome")
	welcome_engine.end_turn()
	var after_welcome: Array[Dictionary] = welcome_engine.start_turn()
	t.eq(welcome_state.pending_event, "always_event", "events begin normally on turn 2")
	t.is_true(not _first_of(after_welcome, "event_fired").is_empty(),
		"turn 2 emits the deferred event")

	t.label("playing a card deducts its cost")
	state.hand.append("cobblestone_roads")
	var result: Dictionary = engine.play_card("cobblestone_roads")
	t.eq(result.get("ok"), true, "cobblestone_roads should be playable")
	t.eq(state.current_budget, 8, "budget after playing a cost-2 card")
	t.eq(state.developments.size(), 1, "development entered the city")

	t.label("unplayed cards stay in hand; budget refreshes")
	var kept: Array[String] = state.hand.duplicate()
	engine.end_turn()
	t.is_true(not state.game_over, "game continues after turn 1")
	engine.start_turn()
	t.eq(state.hand.size(), kept.size() + 3, "hand keeps unplayed cards plus new draw")
	for card_id: String in kept:
		t.is_true(card_id in state.hand, "kept card %s still in hand" % card_id)
	t.eq(state.current_budget, 10, "budget refreshes fully (no income sources)")

	t.label("start_turn rejected while an event is pending")
	state.pending_event = "always_event"
	t.eq(engine.start_turn().size(), 0, "start_turn must return [] with pending event")
	t.eq(engine.end_turn().size(), 0, "end_turn must return [] with pending event")
	state.pending_event = ""

	t.label("reaching the age boundary wins")
	var win_state: GameState = GameSetup.new_game(db, "test_age", 42)
	var win_engine := TurnEngine.new(db, win_state)
	win_state.year = 1692  # one turn (8 years) before year_end 1700
	win_engine.start_turn()
	var end_events: Array[Dictionary] = win_engine.end_turn()
	t.is_true(win_state.game_over, "game over at age boundary")
	t.eq(win_state.outcome, GameState.OUTCOME_WON, "outcome is won")
	t.is_true(not _first_of(end_events, "age_completed").is_empty(), "age_completed emitted")
	var over: Dictionary = _first_of(end_events, "game_over")
	t.eq(over.get("outcome"), GameState.OUTCOME_WON, "game_over carries the outcome")
	t.is_true(over.get("score") is Dictionary, "game_over carries a score dict")

	t.label("policies are temporarily disabled at the simulation boundary")
	var adopt: Dictionary = engine.adopt_policy("civic_charter")
	t.eq(adopt.get("ok"), false, "policy adoption is refused")
	t.eq(adopt.get("reason"), "policies are temporarily disabled",
		"refusal explains the feature gate")
	state.active_policies.append("civic_charter")
	var without_policy: ModifierPipeline = ModifierPipeline.collect(state, db)
	t.eq(without_policy.income_total(), 0,
		"even a policy retained by an older save contributes no passive effects")
	return true



func _first_of(events: Array[Dictionary], type_name: String) -> Dictionary:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			return event
	return {}
