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

	t.label("adopt_policy slots")
	var adopt: Dictionary = engine.adopt_policy("civic_charter")
	t.eq(adopt.get("ok"), true, "start-unlocked policy adoptable")
	t.eq(engine.adopt_policy("civic_charter").get("ok"), false, "already active rejected")
	t.eq(engine.adopt_policy("trade_council").get("ok"), false, "locked policy rejected")
	var full: Dictionary = engine.adopt_policy("public_works")
	t.eq(full.get("ok"), false, "second policy with 1 slot rejected")
	t.eq(full.get("reason"), "no free policy slot", "slot-full reason text")
	return true



func _first_of(events: Array[Dictionary], type_name: String) -> Dictionary:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			return event
	return {}
