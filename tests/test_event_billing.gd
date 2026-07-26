extends RefCounted

## Event billing (GDD 3): event option costs land on NEXT turn's budget and
## drive the debt-spiral lose condition. Demands are silenced throughout — this
## suite is about the budget, and pressure cards would keep interrupting it.


func run(t: TestContext) -> bool:
	var db: ContentDB = Fixtures.build_db()

	t.label("event cost bills next turn, not this turn")
	var state: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine := TurnEngine.new(db, state)
	Fixtures.quiet_demands(state)
	state.event_deck.assign(["always_event"])
	engine.start_turn()
	t.eq(state.current_budget, 10, "budget before event")
	t.eq(state.pending_event, "always_event", "always_event fires in the event phase")
	engine.resolve_event(1)  # option 1 costs 3
	t.eq(state.pending_bill, 3, "bill recorded for next turn")
	t.eq(state.current_budget, 10, "this turn's budget untouched by event cost")
	engine.start_turn()
	t.eq(state.current_budget, 7, "next turn's spendable reduced by the bill")
	t.eq(state.pending_bill, 0, "bill cleared after charging")
	t.eq(state.debt_turns, 0, "no debt from an affordable bill")
	Fixtures.settle_turn(engine)

	t.label("oversized bill pushes budget negative")
	state.pending_bill = 50
	engine.start_turn()
	t.eq(state.current_budget, -40, "capacity 10 minus bill 50")
	t.eq(state.debt_turns, 1, "debt counter starts")
	t.is_true(not state.game_over, "one debt turn does not lose")
	var refused: Dictionary = engine.play_card(state.hand[0])
	t.eq(refused.get("ok"), false, "nothing playable on negative budget")
	Fixtures.settle_turn(engine)

	t.label("three consecutive debt turns lose the game")
	state.pending_bill = 50
	engine.start_turn()
	t.eq(state.debt_turns, 2, "second consecutive debt turn")
	t.is_true(not state.game_over, "two debt turns do not lose")
	Fixtures.settle_turn(engine)
	state.pending_bill = 50
	var events: Array[Dictionary] = engine.start_turn()
	t.eq(state.debt_turns, 3, "third consecutive debt turn")
	t.is_true(state.game_over, "three debt turns lose")
	t.eq(state.outcome, GameState.OUTCOME_LOST_DEBT, "outcome is lost_debt")
	var over: Dictionary = {}
	for event: Dictionary in events:
		if String(event.get("type", "")) == "game_over":
			over = event
	t.eq(over.get("outcome"), GameState.OUTCOME_LOST_DEBT, "game_over event emitted")

	t.label("a recovery turn resets the debt counter")
	var state2: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine2 := TurnEngine.new(db, state2)
	Fixtures.quiet_demands(state2)
	state2.pending_bill = 50
	engine2.start_turn()
	t.eq(state2.debt_turns, 1, "debt turn recorded")
	Fixtures.settle_turn(engine2)
	engine2.start_turn()
	t.eq(state2.current_budget, 10, "budget recovers with no bill")
	t.eq(state2.debt_turns, 0, "recovery resets the debt counter")
	t.is_true(not state2.game_over, "game continues after recovery")
	return true
