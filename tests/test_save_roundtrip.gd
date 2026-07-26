extends RefCounted

## Mid-game save/load: to_dict -> JSON -> from_dict, then both copies keep
## playing identically to the same final state.


func run(t: TestContext) -> bool:
	var db: ContentDB = Fixtures.build_db()

	t.label("roundtrip preserves state exactly")
	var state: GameState = GameSetup.new_game(db, "test_age", 314)
	var engine := TurnEngine.new(db, state)
	for i: int in 2:
		Fixtures.scripted_turn(engine)
	var snapshot: String = JSON.stringify(state.to_dict())
	var parsed: Variant = JSON.parse_string(snapshot)
	t.is_true(parsed is Dictionary, "snapshot parses back to a Dictionary")
	var copy: GameState = GameState.from_dict(parsed)
	t.eq(JSON.stringify(copy.to_dict()), snapshot, "loaded state re-serializes identically")

	t.label("both copies continue identically")
	var engine_copy := TurnEngine.new(db, copy)
	for i: int in 4:
		Fixtures.scripted_turn(engine)
		Fixtures.scripted_turn(engine_copy)
	t.eq(JSON.stringify(copy.to_dict()), JSON.stringify(state.to_dict()),
		"4 further identical turns keep the states identical")
	t.eq(copy.turn_number, state.turn_number, "turn counters agree")
	t.eq(copy.population_count, state.population_count, "population agrees")
	return true
