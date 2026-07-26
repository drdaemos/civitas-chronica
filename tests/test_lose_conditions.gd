extends RefCounted

## Lose conditions (GDD 3): the debt spiral's grace period, the catastrophe
## card, and the design-pillar property that nothing kills the city suddenly —
## every path to loss telegraphs and leaves turns to react.


func run(t: TestContext) -> bool:
	var db: ContentDB = Fixtures.build_db()

	t.label("debt loses only after 3 consecutive turns in the red")
	var state: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine := TurnEngine.new(db, state)
	state.pending_bill = 100
	_run_turn(engine)
	t.eq(state.debt_turns, 1, "one turn in the red")
	t.is_true(not state.game_over, "one turn in the red does not lose")
	state.pending_bill = 100
	_run_turn(engine)
	t.eq(state.debt_turns, 2, "two turns in the red")
	t.is_true(not state.game_over, "two turns in the red do not lose")
	state.pending_bill = 100
	_run_turn(engine)
	t.is_true(state.game_over, "three consecutive turns in the red lose")
	t.eq(state.outcome, GameState.OUTCOME_LOST_DEBT, "outcome is lost_debt")

	t.label("a solvent turn resets the debt counter")
	var state2: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine2 := TurnEngine.new(db, state2)
	state2.pending_bill = 100
	_run_turn(engine2)
	t.eq(state2.debt_turns, 1, "counter at 1")
	_run_turn(engine2)
	t.eq(state2.debt_turns, 0, "solvent turn resets the counter")
	state2.pending_bill = 100
	_run_turn(engine2)
	t.eq(state2.debt_turns, 1, "counter rebuilt from zero")
	t.is_true(not state2.game_over, "still alive")

	t.label("a demand past catastrophe does not itself lose the game")
	var state3: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine3 := TurnEngine.new(db, state3)
	engine3.start_turn()
	state3.hand.clear()
	Fixtures.force_play(engine3, "unpopular_decree")  # supply +12
	t.is_true(state3.demand_value("supply") >= 12, "the meter is far past tolerance")
	t.is_true(not state3.game_over, "the demand system never kills directly")
	engine3.end_turn()
	t.is_true(not state3.game_over, "and the turn still ends normally")

	t.label("pressure cards accumulate while a demand stays in the red")
	var before: int = state3.event_deck.size()
	engine3.start_turn()
	t.is_true(state3.event_deck.size() > before or state3.pending_event != "",
		"upkeep shuffled emergency and catastrophe cards in")
	var pressure: int = 0
	for event_id: String in state3.event_deck:
		if (db.get_event(event_id) as EventDef).severity != "":
			pressure += 1
	if state3.pending_event != "":
		pressure += 1
	t.is_true(pressure >= 2, "both severities entered the deck (found %d)" % pressure)

	t.label("the catastrophe card is what ends the save, and only while in the red")
	var state4: GameState = _city_with_doomed_supply(db, 5)
	var engine4 := TurnEngine.new(db, state4)
	# Option 0 pays the meter down but the card has already been drawn.
	var events: Array[Dictionary] = engine4.resolve_event(0)
	t.is_true(state4.game_over, "resolving a catastrophe for a doomed demand loses")
	t.eq(state4.outcome, GameState.OUTCOME_LOST_CATASTROPHE, "outcome is lost_catastrophe")
	t.is_true(not _first_of(events, "catastrophe_struck").is_empty(), "catastrophe_struck emitted")
	var over: Dictionary = _first_of(events, "game_over")
	t.eq(over.get("outcome"), GameState.OUTCOME_LOST_CATASTROPHE, "game_over carries the outcome")

	t.label("pulling the meter back down before the card surfaces removes the danger")
	var state5: GameState = _city_with_doomed_supply(db, 5)
	var engine5 := TurnEngine.new(db, state5)
	state5.set_demand("supply", 2)  # recovered in the meantime
	engine5.resolve_event(0)
	t.is_true(not state5.game_over, "the same card is survivable once the demand is answered")
	t.eq(state5.pending_event, "", "and it resolves like any other event")

	t.label("an emergency card is never fatal, however deep the demand is")
	var state6: GameState = GameSetup.new_game(db, "test_age", 5)
	var engine6 := TurnEngine.new(db, state6)
	engine6.start_turn()
	state6.hand.clear()
	state6.set_demand("supply", 20)
	state6.pending_event = "supply_shortage_test_age"
	engine6.resolve_event(1)
	t.is_true(not state6.game_over, "emergencies are pressure, not death")
	return true



# --- helpers -----------------------------------------------------------------

## A city whose supply demand is past catastrophe with the catastrophe card
## already drawn and awaiting an answer.
func _city_with_doomed_supply(db: ContentDB, seed_value: int) -> GameState:
	var state: GameState = GameSetup.new_game(db, "test_age", seed_value)
	var engine := TurnEngine.new(db, state)
	engine.start_turn()
	state.hand.clear()
	state.set_demand("supply", 10)
	state.pending_event = "supply_collapse_test_age"
	state.current_budget = 100  # the option's cost is not what is being tested
	return state


## A turn where the player does nothing but keep the hand legal — without the
## discard, the hand-limit gate would stop the turn from ending (GDD 4.1).
func _run_turn(engine: TurnEngine) -> void:
	engine.start_turn()
	if engine.state.game_over:
		return
	var overflow: int = DeckManager.hand_overflow(engine.state, engine.db)
	if overflow > 0:
		engine.discard_cards(engine.state.hand.slice(0, overflow))
	if engine.state.pending_event != "":
		engine.resolve_event(Fixtures.first_available_option(engine.state, engine.db))
	engine.end_turn()


func _first_of(events: Array[Dictionary], type_name: String) -> Dictionary:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			return event
	return {}
