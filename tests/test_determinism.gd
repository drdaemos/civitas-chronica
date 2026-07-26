extends RefCounted

## Same seed + same inputs => identical state; different seed => different deck.


func run(t: TestContext) -> bool:
	var db: ContentDB = Fixtures.build_db()

	t.label("same seed, same script, identical state")
	var state_a: GameState = GameSetup.new_game(db, "test_age", 12345)
	var state_b: GameState = GameSetup.new_game(db, "test_age", 12345)
	t.eq(JSON.stringify(state_a.to_dict()), JSON.stringify(state_b.to_dict()),
		"fresh games with the same seed must serialize identically")
	var engine_a := TurnEngine.new(db, state_a)
	var engine_b := TurnEngine.new(db, state_b)
	for i: int in 6:
		Fixtures.scripted_turn(engine_a)
		Fixtures.scripted_turn(engine_b)
	t.eq(JSON.stringify(state_a.to_dict()), JSON.stringify(state_b.to_dict()),
		"after 6 identical scripted turns states must serialize identically")

	t.label("different seed, different deck order")
	var state_c: GameState = GameSetup.new_game(db, "test_age", 111)
	var state_d: GameState = GameSetup.new_game(db, "test_age", 222)
	t.eq(state_c.main_deck.size(), state_d.main_deck.size(),
		"deck sizes must match regardless of seed")
	t.is_true(state_c.main_deck != state_d.main_deck,
		"different seeds must produce a different main_deck order")
	return true
