extends RefCounted

## Hand limit (GDD 4.1): the hand is retained across turns but capped. The turn
## cannot end over the cap; the overflow is discarded and consumed for good.
## Card capacity grows through the limit, never through the draw.


func run(t: TestContext) -> void:
	var db: ContentDB = Fixtures.build_db()

	t.label("base limit is 5 and no development raises the draw")
	var state: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine := TurnEngine.new(db, state)
	t.eq(DeckManager.hand_limit(state, db), 5, "base hand limit")
	engine.start_turn()
	t.eq(state.hand.size(), 3, "age draw of 3")
	state.hand.clear()
	t.eq(Fixtures.force_play(engine, "scriptorium").get("ok"), true, "scriptorium built")
	t.eq(DeckManager.hand_limit(state, db), 7, "hand_limit_bonus raises the limit")
	engine.end_turn()
	engine.start_turn()
	t.eq(state.hand.size(), 3, "the draw is still 3 — capacity is not the draw")

	t.label("end_turn refuses to advance over the limit")
	var state2: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine2 := TurnEngine.new(db, state2)
	engine2.start_turn()
	state2.hand.assign(["town_market", "river_docks", "stone_church", "iron_foundry",
		"cobblestone_roads", "levee", "merchant_guild"])
	t.eq(DeckManager.hand_overflow(state2, db), 2, "two cards over the limit")
	var turn_before: int = state2.turn_number
	var year_before: int = state2.year  # the clock advanced during upkeep
	var blocked: Array[Dictionary] = engine2.end_turn()
	t.eq(blocked.size(), 1, "one event returned")
	t.eq(blocked[0].get("type"), "discard_required", "the turn asks for a discard")
	t.eq(blocked[0].get("count"), 2, "overflow count reported")
	t.eq(blocked[0].get("limit"), 5, "limit reported")
	t.eq(state2.turn_number, turn_before, "the turn did not end")
	t.eq(state2.year, year_before, "and nothing moved on")

	t.label("discarding down to the limit lets the turn end")
	var discard: Dictionary = engine2.discard_cards(["levee", "merchant_guild"])
	t.eq(discard.get("ok"), true, "discard accepted")
	var discard_events: Array[Dictionary] = discard.get("events") as Array[Dictionary]
	t.eq(discard_events[0].get("type"), "cards_discarded", "cards_discarded emitted")
	t.eq(discard_events[0].get("cards"), ["levee", "merchant_guild"], "names what went")
	t.eq(state2.hand.size(), 5, "hand at the limit")
	t.eq(DeckManager.hand_overflow(state2, db), 0, "no overflow left")
	t.is_true("levee" in state2.consumed_cards, "discarded card consumed")
	t.is_true("merchant_guild" in state2.consumed_cards, "second discard consumed")
	var ok_events: Array[Dictionary] = engine2.end_turn()
	t.is_true(ok_events.size() > 0, "the turn now ends")
	t.is_true(not _first_of(ok_events, "turn_ended").is_empty(), "turn_ended emitted")

	t.label("discarded cards never come back")
	var reinject := EffectDef.from_dict({"type": "inject_main", "cards": ["levee"]})
	var effects: Array[EffectDef] = [reinject]
	var emitted: Array[Dictionary] = []
	var deck_before: int = state2.main_deck.size()
	EffectApplier.apply_instant(effects, state2, emitted)
	t.eq(state2.main_deck.size(), deck_before, "a discarded card is not re-injected")

	t.label("discard is refused for cards not in hand, and changes nothing")
	var state3: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine3 := TurnEngine.new(db, state3)
	engine3.start_turn()
	state3.hand.assign(["town_market", "river_docks"])
	var bad: Dictionary = engine3.discard_cards(["town_market", "not_in_hand"])
	t.eq(bad.get("ok"), false, "refused")
	t.is_true(String(bad.get("reason", "")).contains("not in hand"), "reason names the problem")
	t.eq(state3.hand, ["town_market", "river_docks"], "the hand is untouched")
	t.is_true("town_market" not in state3.consumed_cards, "nothing was consumed")

	t.label("losing the bonus lowers the limit again")
	var state4: GameState = GameSetup.new_game(db, "test_age", 3)
	var engine4 := TurnEngine.new(db, state4)
	engine4.start_turn()
	state4.hand.clear()
	Fixtures.force_play(engine4, "scriptorium")
	t.eq(DeckManager.hand_limit(state4, db), 7, "bonus applied")
	state4.developments.clear()
	t.eq(DeckManager.hand_limit(state4, db), 5, "back to the base limit without it")


func _first_of(events: Array[Dictionary], type_name: String) -> Dictionary:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			return event
	return {}
