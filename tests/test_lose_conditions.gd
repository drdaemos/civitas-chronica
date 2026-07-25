extends RefCounted

## Approval lose condition grace period, recovery, and the design-pillar
## property that no single turn from a healthy state can lose the game.


func run(t: TestContext) -> void:
	var db: ContentDB = Fixtures.build_db()

	t.label("low approval loses only after 3 consecutive turns")
	var state: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine := TurnEngine.new(db, state)
	state.approval = 10
	_run_turn(engine)
	t.eq(state.low_approval_turns, 1, "one low turn counted")
	t.is_true(not state.game_over, "one low-approval turn does not lose")
	_run_turn(engine)
	t.eq(state.low_approval_turns, 2, "two low turns counted")
	t.is_true(not state.game_over, "two low-approval turns do not lose")
	_run_turn(engine)
	t.is_true(state.game_over, "three consecutive low-approval turns lose")
	t.eq(state.outcome, GameState.OUTCOME_LOST_APPROVAL, "outcome is lost_approval")

	t.label("recovery resets the approval counter")
	var state2: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine2 := TurnEngine.new(db, state2)
	state2.approval = 10
	_run_turn(engine2)
	t.eq(state2.low_approval_turns, 1, "counter at 1")
	state2.approval = 50
	_run_turn(engine2)
	t.eq(state2.low_approval_turns, 0, "healthy turn resets the counter")
	state2.approval = 10
	_run_turn(engine2)
	_run_turn(engine2)
	t.eq(state2.low_approval_turns, 2, "counter rebuilt from zero")
	t.is_true(not state2.game_over, "still alive after reset + 2 low turns")

	t.label("healthy state cannot lose in one turn: approval shock")
	var state3: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine3 := TurnEngine.new(db, state3)
	state3.approval = 20  # healthy floor
	engine3.start_turn()
	state3.hand.append("unpopular_decree")
	var played: Dictionary = engine3.play_card("unpopular_decree")
	t.eq(played.get("ok"), true, "decree playable at cost 0")
	t.eq(state3.approval, 0, "approval floored at 0")
	engine3.end_turn()
	t.is_true(not state3.game_over, "a single catastrophic turn never loses from healthy")
	t.eq(state3.low_approval_turns, 1, "grace counter started instead")

	t.label("healthy state cannot lose in one turn: combined debt + event shock")
	var state4: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine4 := TurnEngine.new(db, state4)
	state4.approval = 20
	state4.pending_bill = 100
	state4.event_deck.assign(["catastrophe"])
	engine4.start_turn()
	t.eq(state4.debt_turns, 1, "debt counter at 1, not game over")
	t.is_true(not state4.game_over, "oversized bill alone does not lose")
	engine4.end_turn()
	t.eq(state4.pending_event, "catastrophe", "catastrophe fires")
	engine4.resolve_event(0)  # -100 approval, cost 100
	t.is_true(not state4.game_over, "worst-case single turn still does not lose")
	t.eq(state4.low_approval_turns, 1, "approval grace counter at 1")
	t.eq(state4.pending_bill, 100, "next turn's bill recorded")


func _run_turn(engine: TurnEngine) -> void:
	engine.start_turn()
	engine.end_turn()
	if engine.state.pending_event != "":
		engine.resolve_event(0)
