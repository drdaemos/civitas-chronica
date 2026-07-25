extends RefCounted

## Deck injection: played developments grow both decks, and injected main
## cards become drawable in later turns.


func run(t: TestContext) -> void:
	var db: ContentDB = Fixtures.build_db()
	var state: GameState = GameSetup.new_game(db, "test_age", 9)
	var engine := TurnEngine.new(db, state)
	engine.start_turn()
	state.hand.clear()

	t.label("playing river_docks injects into both decks")
	var main_before: int = state.main_deck.size()
	var events_before: int = state.event_deck.size()
	var result: Dictionary = Fixtures.force_play(engine, "river_docks")
	t.eq(result.get("ok"), true, "river_docks playable")
	t.eq(state.main_deck.size(), main_before + 1, "main deck grew by 1")
	t.eq(state.event_deck.size(), events_before + 1, "event deck grew by 1")
	t.is_true("harbor_expansion" in state.main_deck, "injected card in main deck")
	t.is_true("trade_dispute" in state.event_deck, "injected event id in event deck")

	t.label("cards_injected events emitted per non-empty injection")
	var injected: Array[Dictionary] = []
	for event: Dictionary in (result.get("events") as Array[Dictionary]):
		if String(event.get("type", "")) == "cards_injected":
			injected.append(event)
	t.eq(injected.size(), 2, "one cards_injected per deck")
	var decks: Array[String] = []
	for event: Dictionary in injected:
		decks.append(String(event.get("deck", "")))
		t.eq(event.get("count"), 1, "each injection carries its count")
	t.is_true("main" in decks and "event" in decks, "both decks reported")

	t.label("injected main card is drawable in later turns")
	var found: bool = "harbor_expansion" in state.hand
	var safety: int = 0
	while not found and not state.main_deck.is_empty() and safety < 20:
		engine.end_turn()
		if state.pending_event != "":
			engine.resolve_event(0)
		if state.game_over:
			break
		engine.start_turn()
		found = "harbor_expansion" in state.hand
		safety += 1
	t.is_true(found, "harbor_expansion eventually drawn into hand")
