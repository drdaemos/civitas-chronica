extends RefCounted

## Card uniqueness (Terraforming Mars rule, content-schema.md): every card
## exists at most once per save across deck, hand, developments, and the
## consumed ledger. Events are NOT unique.


func run(t: TestContext) -> bool:
	var db: ContentDB = Fixtures.build_db()

	t.label("a development cannot be played twice")
	var state: GameState = GameSetup.new_game(db, "test_age", 17)
	var engine := TurnEngine.new(db, state)
	engine.start_turn()
	state.hand.clear()
	t.eq(Fixtures.force_play(engine, "town_market").get("ok"), true, "first play accepted")
	var again: Dictionary = Fixtures.force_play(engine, "town_market")
	t.eq(again.get("ok"), false, "second play refused")
	t.is_true(String(again.get("reason", "")).contains("already built"),
		"reason names the duplicate build")
	t.eq(state.developments.size(), 1, "only one town_market in the city")
	state.hand.clear()

	t.label("injection skipped when the card is already in hand")
	# river_docks injects harbor_expansion into the main deck.
	state.hand.append("harbor_expansion")
	var main_before: int = state.main_deck.size()
	var result: Dictionary = Fixtures.force_play(engine, "river_docks")
	t.eq(result.get("ok"), true, "river_docks playable")
	t.eq(state.main_deck.size(), main_before, "main deck unchanged: harbor already in hand")
	var main_injections: int = 0
	for event: Dictionary in (result.get("events") as Array[Dictionary]):
		if String(event.get("type", "")) == "cards_injected" \
				and String(event.get("deck", "")) == "main":
			main_injections += 1
	t.eq(main_injections, 0, "no cards_injected(main) event when everything was skipped")

	t.label("event injection is NOT filtered (events are not unique)")
	t.is_true("trade_dispute" in state.event_deck, "river_docks still injected its event")

	t.label("injection skipped for deck / development / consumed copies")
	var state2: GameState = GameSetup.new_game(db, "test_age", 17)
	var engine2 := TurnEngine.new(db, state2)
	Fixtures.force_play(engine2, "stone_church")  # development (a deck copy also exists)
	state2.consumed_cards.append("unpopular_decree")
	var effect := EffectDef.from_dict({"type": "inject_main", "cards": [
		"town_market",       # sits in the base deck
		"stone_church",      # development in play
		"unpopular_decree",  # consumed
		"harbor_expansion",  # exists nowhere -> the only one injected
	]})
	var effects: Array[EffectDef] = [effect]
	var deck_before: int = state2.main_deck.size()
	var emitted: Array[Dictionary] = []
	EffectApplier.apply_instant(effects, state2, emitted)
	t.eq(state2.main_deck.size(), deck_before + 1, "exactly one card injected")
	t.is_true("harbor_expansion" in state2.main_deck, "the new card is harbor_expansion")
	t.eq(state2.main_deck.count("town_market"), 1, "no duplicate town_market")
	t.eq(emitted.size(), 1, "one cards_injected event")
	t.eq(emitted[0].get("count"), 1, "cards_injected reports the actually-injected count")

	t.label("consumed action cards are never re-injected")
	var state3: GameState = GameSetup.new_game(db, "test_age", 17)
	var engine3 := TurnEngine.new(db, state3)
	state3.main_deck.clear()  # isolate: drop the base-deck copy
	var played: Dictionary = Fixtures.force_play(engine3, "festival_of_saints")
	t.eq(played.get("ok"), true, "action card playable")
	t.is_true("festival_of_saints" in state3.consumed_cards, "action recorded as consumed")
	var re_effect := EffectDef.from_dict(
		{"type": "inject_main", "cards": ["festival_of_saints"]})
	var re_effects: Array[EffectDef] = [re_effect]
	var re_emitted: Array[Dictionary] = []
	EffectApplier.apply_instant(re_effects, state3, re_emitted)
	t.eq(state3.main_deck.size(), 0, "consumed action not re-injected")
	t.eq(re_emitted.size(), 0, "no cards_injected event for a fully-skipped injection")

	t.label("validator rejects duplicate base_deck ids")
	var db2: ContentDB = Fixtures.build_db()
	db2.ages["dupe_age"] = AgeDef.from_dict({
		"id": "dupe_age", "name": "Dupe Age",
		"year_start": 1500, "year_end": 1700, "years_per_turn": 8,
		"base_deck": ["town_market", "town_market"],
		"base_events": [],
	})
	var errors: Array[String] = db2.validate()
	var found_dupe: bool = false
	for error: String in errors:
		if error.contains("duplicate base_deck card \"town_market\""):
			found_dupe = true
	t.is_true(found_dupe, "duplicate base_deck id reported by validate()")
	return true
