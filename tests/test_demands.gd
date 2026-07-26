extends RefCounted

## The demand system (GDD 4.0): the growth step, the double duty of a printed
## value, one-time deltas, the threshold consequences, age activation against a
## standing city, and the rule that demands never damage the city directly.


func run(t: TestContext) -> void:
	var db: ContentDB = Fixtures.build_db()

	t.label("only the age's demand is active, and it starts at 0")
	var state: GameState = GameSetup.new_game(db, "test_age", 7)
	t.eq(state.active_demands, ["supply"], "the first age activates one demand")
	t.eq(state.demand_value("supply"), 0, "a fresh city owes nothing")
	t.is_true(not state.is_demand_active("order"), "later demands are not active yet")

	t.label("growth step is population level + printed values")
	var engine := TurnEngine.new(db, state)
	engine.start_turn()
	state.hand.clear()
	t.eq(_growth(state, db, "supply"), 1, "level 1 alone pushes the demand up 1 per turn")
	Fixtures.force_play(engine, "town_market")  # supply -1
	t.eq(_growth(state, db, "supply"), 0, "one mitigator reaches equilibrium")
	Fixtures.force_play(engine, "grain_storehouse")  # supply -2
	t.eq(_growth(state, db, "supply"), 0, "the step is floored at 0, never negative")
	Fixtures.force_play(engine, "iron_foundry")  # supply +1
	t.eq(_growth(state, db, "supply"), 0, "still held: 1 + 1 - 3 floors to 0")
	t.eq(_growth(state, db, "order"), 0, "an inactive demand reports no growth")

	t.label("a printed value moves the meter once AND feeds the step forever")
	var state2: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine2 := TurnEngine.new(db, state2)
	engine2.start_turn()
	state2.hand.clear()
	state2.set_demand("supply", 4)
	Fixtures.force_play(engine2, "grain_storehouse")  # printed supply -2
	t.eq(state2.demand_value("supply"), 2, "the meter moved by the printed value on play")
	t.eq(_growth(state2, db, "supply"), 0, "and the same number is in the growth step")

	t.label("the immediate half is clamped at 0, which is what stops buffering")
	var state3: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine3 := TurnEngine.new(db, state3)
	engine3.start_turn()
	state3.hand.clear()
	Fixtures.force_play(engine3, "grain_storehouse")
	t.eq(state3.demand_value("supply"), 0, "no credit banked against future need")
	t.eq(_growth(state3, db, "supply"), 0, "but the permanent half still counts")

	t.label("upkeep applies the growth step and reports it")
	var state4: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine4 := TurnEngine.new(db, state4)
	var first: Array[Dictionary] = engine4.start_turn()
	t.eq(state4.demand_value("supply"), 1, "the demand grew by its step")
	var grew: Dictionary = _first_of(first, "demand_grew")
	t.eq(grew.get("demand"), "supply", "demand_grew names the demand")
	t.eq(grew.get("from"), 0, "reports where it was")
	t.eq(grew.get("to"), 1, "reports where it is")
	t.eq(grew.get("step"), 1, "reports the step")

	t.label("a demand at equilibrium is quiet — no event at all")
	var state5: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine5 := TurnEngine.new(db, state5)
	engine5.start_turn()
	state5.hand.clear()
	Fixtures.force_play(engine5, "town_market")
	state5.set_demand("supply", 0)
	var quiet: Array[Dictionary] = engine5.start_turn()
	t.eq(state5.demand_value("supply"), 0, "the meter did not move")
	t.is_true(_first_of(quiet, "demand_grew").is_empty(), "and nothing was reported")

	t.label("crossing the threshold shuffles an emergency card, every turn")
	var state6: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine6 := TurnEngine.new(db, state6)
	engine6.start_turn()
	state6.hand.clear()
	state6.event_deck.clear()
	state6.set_demand("supply", 2)
	var crossing: Array[Dictionary] = engine6.start_turn()
	t.eq(state6.demand_value("supply"), 3, "the meter reached the threshold")
	var crossed: Dictionary = _first_of(crossing, "demand_over_threshold")
	t.eq(crossed.get("demand"), "supply", "the crossing is announced once")
	var shuffled: Dictionary = _first_of(crossing, "pressure_card_shuffled")
	t.eq(shuffled.get("severity"), EventDef.SEVERITY_EMERGENCY, "an emergency card entered")
	t.eq(shuffled.get("event"), "supply_shortage_test_age", "the demand's own emergency card")
	t.is_true(_of_type(crossing, "pressure_card_shuffled").size() == 1,
		"and no catastrophe card yet")

	t.label("cards keep accumulating and are not removed by recovering")
	state6.pending_event = ""
	state6.set_demand("supply", 9)
	var deck_before: int = state6.event_deck.size()
	var deep: Array[Dictionary] = engine6.start_turn()
	t.eq(_of_type(deep, "pressure_card_shuffled").size(), 2,
		"past the catastrophe value both severities enter")
	t.is_true(state6.event_deck.size() + (1 if state6.pending_event != "" else 0) > deck_before,
		"the deck is fuller than it was")
	state6.pending_event = ""
	state6.set_demand("supply", 0)
	var recovered_deck: int = state6.event_deck.size()
	engine6.start_turn()
	t.eq(_of_type(engine6.start_turn(), "pressure_card_shuffled").size(), 0,
		"recovering stops new cards entering")
	t.is_true(state6.event_deck.size() >= recovered_deck - 2,
		"but the cards already in the deck stay there")

	t.label("events move the meter one-time only, never the growth step")
	var state7: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine7 := TurnEngine.new(db, state7)
	engine7.start_turn()
	state7.hand.clear()
	var step_before: int = _growth(state7, db, "supply")
	state7.pending_event = "trade_dispute"
	engine7.resolve_event(0)  # supply +2
	t.eq(state7.demand_value("supply"), 3, "the option moved the meter")
	t.eq(_growth(state7, db, "supply"), step_before, "the growth step is untouched")

	t.label("action cards buy time, and cannot push a meter below 0")
	var state8: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine8 := TurnEngine.new(db, state8)
	engine8.start_turn()
	state8.hand.clear()
	state8.set_demand("supply", 1)
	Fixtures.force_play(engine8, "festival_of_saints")  # supply -2 one-time
	t.eq(state8.demand_value("supply"), 0, "clamped at 0")

	t.label("interactions and policies feed the growth step, not the meter")
	var state9: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine9 := TurnEngine.new(db, state9)
	engine9.start_turn()
	state9.hand.clear()
	Fixtures.force_play(engine9, "town_market")
	Fixtures.force_play(engine9, "river_docks")
	Fixtures.force_play(engine9, "harbor_expansion")
	InteractionEngine.check(state9, db)  # trade_hub: order +1 modifier
	t.is_true("trade_hub" in state9.active_interactions, "trade_hub active")
	t.eq(ModifierPipeline.collect(state9, db).demand_modifier_total("order"), 1,
		"the interaction's modifier is counted")
	t.eq(_growth(state9, db, "order"), 0, "but an inactive demand still does not grow")
	t.eq(state9.demand_value("order"), 0, "and has no meter yet")

	t.label("activation counts the standing city, not a clean slate")
	var events: Array[Dictionary] = []
	DemandEngine.activate(state9, db, "order", events)
	t.is_true(state9.is_demand_active("order"), "the demand is live")
	# harbor_expansion prints order +1, stone_church is not built here
	t.eq(state9.demand_value("order"), 1, "the meter starts from what was already built")
	var activated: Dictionary = _first_of(events, "demand_activated")
	t.eq(activated.get("demand"), "order", "activation is announced")
	t.eq(activated.get("value"), 1, "with the value the city is measured at")
	t.eq(_growth(state9, db, "order"), 3, "level 1 + printed 1 + interaction 1")

	t.label("activating twice does nothing")
	var second: Array[Dictionary] = []
	DemandEngine.activate(state9, db, "order", second)
	t.eq(second.size(), 0, "no second activation event")
	t.eq(state9.demand_value("order"), 1, "and no re-count")

	t.label("removing a development takes both halves of its value with it")
	var state10: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine10 := TurnEngine.new(db, state10)
	engine10.start_turn()
	state10.hand.clear()
	Fixtures.force_play(engine10, "grain_storehouse")
	t.eq(_growth(state10, db, "supply"), 0, "held while it stands")
	state10.developments.clear()
	t.eq(_growth(state10, db, "supply"), 1, "the mitigation is gone with the building")

	t.label("per-tag modifiers scale with the city")
	var per_tag := EffectDef.from_dict({
		"type": "demand_modifier_per_tag", "demand": "supply", "tag": "trade", "amount": -1,
	})
	var state11: GameState = GameSetup.new_game(db, "test_age", 7)
	var engine11 := TurnEngine.new(db, state11)
	engine11.start_turn()
	state11.hand.clear()
	Fixtures.force_play(engine11, "cobblestone_roads")
	var dev: DevelopmentState = state11.developments[0]
	dev.effects.append(per_tag)
	t.eq(ModifierPipeline.collect(state11, db).demand_modifier_total("supply"), 0,
		"no trade developments yet")
	Fixtures.force_play(engine11, "town_market")
	Fixtures.force_play(engine11, "river_docks")
	t.eq(ModifierPipeline.collect(state11, db).demand_modifier_total("supply"), -2,
		"one per trade development")


# --- helpers -----------------------------------------------------------------

func _growth(state: GameState, db: ContentDB, demand_id: String) -> int:
	return ModifierPipeline.collect(state, db).demand_growth_step(demand_id)


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
