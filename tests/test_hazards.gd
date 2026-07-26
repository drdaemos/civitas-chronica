extends RefCounted

## How standing developments change an event's resolution (GDD 4.4):
## type-based hazard cancellation, and extra options gated on a specific card.
## Neither affects whether the event fires — triggers stay permissive.


func run(t: TestContext) -> void:
	var db: ContentDB = Fixtures.build_db()

	t.label("without protection the hazard lands in full")
	var state: GameState = _city_with_pending(db, 9, "river_flood", [])
	var engine := TurnEngine.new(db, state)
	var supply_before: int = state.demand_value("supply")
	var population_before: int = state.population_count
	var events: Array[Dictionary] = engine.resolve_event(0)
	t.eq(state.demand_value("supply"), supply_before + 3, "the demand increase applied")
	t.eq(state.population_count, population_before - 50, "the population loss applied")
	t.is_true("trade_council" in state.unlocked_policies, "harmless effect applied too")
	t.is_true(_first_of(events, "hazard_cancelled").is_empty(), "no cancellation event")

	t.label("a development listing the hazard negates the harm, not the rest")
	var state2: GameState = _city_with_pending(db, 9, "river_flood", ["levee"])
	var engine2 := TurnEngine.new(db, state2)
	var supply_before2: int = state2.demand_value("supply")
	var population_before2: int = state2.population_count
	var events2: Array[Dictionary] = engine2.resolve_event(0)
	t.eq(state2.demand_value("supply"), supply_before2, "the demand did not move")
	t.eq(state2.population_count, population_before2, "nobody was lost")
	t.is_true("trade_council" in state2.unlocked_policies,
		"the option's harmless effect still resolves")
	var cancelled: Dictionary = _first_of(events2, "hazard_cancelled")
	t.is_true(not cancelled.is_empty(), "cancellation reported")
	t.eq(cancelled.get("hazard"), "flood", "names the hazard type")
	t.eq(cancelled.get("by"), "levee", "names the development that held")
	t.eq(state2.pending_event, "", "the event still resolved")

	t.label("cancellation is by type, not by event — and only the matching type")
	# grain_storehouse cancels famine, not flood
	var state3: GameState = _city_with_pending(db, 9, "river_flood", ["grain_storehouse"])
	var engine3 := TurnEngine.new(db, state3)
	var supply_before3: int = state3.demand_value("supply")
	engine3.resolve_event(0)
	t.eq(state3.demand_value("supply"), supply_before3 + 3, "the wrong protection does not help")

	t.label("the player is told before choosing that it is a near-miss")
	var state4: GameState = GameSetup.new_game(db, "test_age", 9)
	var engine4 := TurnEngine.new(db, state4)
	engine4.start_turn()
	state4.hand.clear()
	Fixtures.force_play(engine4, "levee")
	state4.event_deck.assign(["river_flood"])
	Fixtures.settle_turn(engine4)
	var fired: Dictionary = _first_of(engine4.start_turn(), "event_fired")
	t.eq(fired.get("id"), "river_flood", "the event still fires — protection is not a trigger")
	t.eq(fired.get("hazard_cancelled_by"), "levee", "event_fired flags the near-miss")

	t.label("an event with no hazard type can never be cancelled")
	var state5: GameState = GameSetup.new_game(db, "test_age", 9)
	var engine5 := TurnEngine.new(db, state5)
	engine5.start_turn()
	state5.hand.clear()
	Fixtures.force_play(engine5, "levee")
	var no_hazard: EventDef = db.get_event("always_event")
	t.eq(EventMatcher.hazard_cancelled_by(state5, db, no_hazard), "", "nothing cancels it")

	t.label("conditional options are hidden without the development")
	var state6: GameState = _city_with_pending(db, 21, "trade_dispute", [])
	var engine6 := TurnEngine.new(db, state6)
	var dispute: EventDef = db.get_event("trade_dispute")
	var guild_option: int = dispute.options.size() - 1
	t.eq(dispute.options[guild_option].requires_development, "merchant_guild",
		"the last option is the gated one")
	t.is_true(not dispute.options[guild_option].is_available(state6), "unavailable")
	t.is_true(dispute.options[0].is_available(state6), "unconditional options stay available")
	var ignored: Array[Dictionary] = engine6.resolve_event(guild_option)
	t.eq(ignored.size(), 0, "resolving a hidden option does nothing")
	t.eq(state6.pending_event, "trade_dispute", "the event is still pending")

	t.label("standing development unlocks the extra option")
	var state7: GameState = _city_with_pending(db, 21, "trade_dispute", ["merchant_guild"])
	var engine7 := TurnEngine.new(db, state7)
	t.is_true(dispute.options[guild_option].is_available(state7), "now available")
	state7.set_demand("supply", 5)  # the guild's help has to have something to fix
	var supply_before7: int = state7.demand_value("supply")
	engine7.resolve_event(guild_option)
	t.eq(state7.demand_value("supply"), supply_before7 - 2, "the extra option resolved")
	t.eq(state7.pending_event, "", "event cleared")


# --- helpers -----------------------------------------------------------------

## A mid-turn city with the given developments built and an event already
## pending, ready for resolve_event.
func _city_with_pending(db: ContentDB, seed_value: int, event_id: String,
		built: Array[String]) -> GameState:
	var state: GameState = GameSetup.new_game(db, "test_age", seed_value)
	var engine := TurnEngine.new(db, state)
	engine.start_turn()
	state.hand.clear()
	for card_id: String in built:
		Fixtures.force_play(engine, card_id)
	state.pending_event = event_id
	return state


func _first_of(events: Array[Dictionary], type_name: String) -> Dictionary:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			return event
	return {}
