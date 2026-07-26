extends RefCounted

## Event matching (GDD 4.4): trigger filtering, bottom-return in drawn order,
## unlimited draws, removal of the matched event, and forced events.


func run(t: TestContext) -> bool:
	var db: ContentDB = Fixtures.build_db()

	t.label("non-matching event returns to bottom; match is removed")
	var state: GameState = GameSetup.new_game(db, "test_age", 11)
	state.event_deck.assign(["never_event", "never_event_b", "always_event", "trade_dispute"])
	var matched: String = EventMatcher.draw_matching(state, db)
	t.eq(matched, "always_event", "first matching event wins")
	t.is_true("always_event" not in state.event_deck, "matched event removed from deck")
	t.eq(state.event_deck, ["trade_dispute", "never_event", "never_event_b"],
		"set-aside events returned to the bottom in drawn order")

	t.label("no draw limit: a match deep in the deck still fires")
	var state2: GameState = GameSetup.new_game(db, "test_age", 11)
	state2.event_deck.assign([
		"never_event", "never_event", "never_event", "never_event", "never_event_b",
		"never_event", "never_event", "always_event",
	])
	var deep: String = EventMatcher.draw_matching(state2, db)
	t.eq(deep, "always_event", "the 8th card matched — there is no draw cap")
	t.eq(state2.event_deck.size(), 7, "only the matched event left the deck")
	t.eq(state2.event_deck[4], "never_event_b", "unmatched draws returned in drawn order")

	t.label("a full pass with no match means no event this turn")
	var state2b: GameState = GameSetup.new_game(db, "test_age", 11)
	state2b.event_deck.assign(["never_event", "never_event_b", "never_event"])
	t.eq(EventMatcher.draw_matching(state2b, db), "", "nothing matched")
	t.eq(state2b.event_deck, ["never_event", "never_event_b", "never_event"],
		"the whole deck is back, in drawn order")

	t.label("empty deck matches nothing")
	var state3: GameState = GameSetup.new_game(db, "test_age", 11)
	state3.event_deck.clear()
	t.eq(EventMatcher.draw_matching(state3, db), "", "empty deck returns \"\"")

	t.label("trigger-failing event does not fire in the event phase")
	var state4: GameState = GameSetup.new_game(db, "test_age", 11)
	var engine4 := TurnEngine.new(db, state4)
	Fixtures.quiet_demands(state4)
	var upkeep_events: Array[Dictionary] = engine4.start_turn()
	for event: Dictionary in upkeep_events:
		t.is_true(String(event.get("type", "")) != "event_fired",
			"never_event must not fire")
	t.eq(state4.pending_event, "", "no pending event")
	t.is_true("never_event" in state4.event_deck, "never_event back in the deck")

	t.label("forced event fires on schedule regardless of trigger")
	var state5: GameState = GameSetup.new_game(db, "forced_age", 11)
	var engine5 := TurnEngine.new(db, state5)
	Fixtures.quiet_demands(state5)
	engine5.start_turn()
	t.eq(state5.pending_event, "", "no event on turn 1")
	engine5.end_turn()
	var deck_before: Array[String] = state5.event_deck.duplicate()
	var forced_events: Array[Dictionary] = engine5.start_turn()
	t.eq(state5.pending_event, "royal_decree", "forced event pending on turn 2")
	t.is_true("royal_decree" in state5.seen_events, "forced event marked seen")
	t.eq(state5.event_deck, deck_before, "event deck untouched by a forced event")
	var fired: bool = false
	for event: Dictionary in forced_events:
		if String(event.get("type", "")) == "event_fired" and String(event.get("id", "")) == "royal_decree":
			fired = true
	t.is_true(fired, "event_fired emitted for the forced event")
	var resolve_events: Array[Dictionary] = engine5.resolve_event(0)
	t.eq(state5.pending_event, "", "pending cleared after resolve")
	var resolved: bool = false
	for event: Dictionary in resolve_events:
		if String(event.get("type", "")) == "event_resolved":
			resolved = true
	t.is_true(resolved, "event_resolved emitted")
	return true
