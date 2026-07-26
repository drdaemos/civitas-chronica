extends RefCounted

## Population as level over count (GDD 4.0): growth governed by demand balance,
## the level as the only number rules read, level-ups raising every growth step,
## levels that can be lost, and hysteresis on the boundary.


func run(t: TestContext) -> void:
	var db: ContentDB = Fixtures.build_db()
	# Fixture boundaries: level 1 from 0, level 2 from 1000, level 3 from 3000.

	t.label("a fresh city takes its level from its starting count")
	var state: GameState = GameSetup.new_game(db, "test_age", 4)
	t.eq(state.population_count, 500, "count from the age def")
	t.eq(state.population_level, 1, "level derived from the boundary table")

	t.label("upkeep grows the count and reports the delta")
	var engine := TurnEngine.new(db, state)
	var events: Array[Dictionary] = engine.start_turn()
	var grew: Dictionary = _first_of(events, "population_grew")
	t.is_true(not grew.is_empty(), "population_grew emitted")
	t.eq(grew.get("count"), state.population_count, "reports the new count")
	t.is_true(int(grew.get("delta", 0)) > 0, "a clean city grows")
	t.eq(grew.get("demands_over_threshold"), 0, "and reports why")
	t.is_true(state.population_count > 500, "the count moved")

	t.label("growth is ±variance around the base rate, never wilder")
	var deltas: Array[int] = []
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		var s: GameState = GameSetup.new_game(db, "test_age", seed_value)
		var e := TurnEngine.new(db, s)
		var evs: Array[Dictionary] = e.start_turn()
		deltas.append(int(_first_of(evs, "population_grew").get("delta", 0)))
	# base 40, variance 0.15 -> 34..46
	for delta: int in deltas:
		t.is_true(delta >= 34 and delta <= 46, "delta %d within variance of the base rate" % delta)

	t.label("demands over threshold slow growth; catastrophe reverses it")
	var clean: int = _one_turn_delta(db, 11, 0)
	t.is_true(clean > 0, "control: a clean city grows (%d)" % clean)
	var pressured: int = _one_turn_delta(db, 11, 3)
	t.is_true(pressured < clean and pressured > 0,
		"one demand over threshold reduces growth without stopping it (%d)" % pressured)
	t.eq(_one_turn_delta(db, 11, 3), pressured, "deterministic for the same seed")
	var doomed: int = _one_turn_delta(db, 11, 9)
	t.is_true(doomed < 0, "a demand at catastrophe level makes the city decline (%d)" % doomed)

	t.label("crossing a boundary changes the level and every growth step")
	var state2: GameState = GameSetup.new_game(db, "test_age", 4)
	var engine2 := TurnEngine.new(db, state2)
	engine2.start_turn()
	state2.hand.clear()
	var step_before: int = _growth(state2, db, "supply")
	state2.population_count = 990
	var level_events: Array[Dictionary] = []
	PopulationEngine.recompute_level(state2, db, level_events)
	t.eq(state2.population_level, 1, "990 is still level 1")
	state2.population_count = 1010
	PopulationEngine.recompute_level(state2, db, level_events)
	t.eq(state2.population_level, 2, "1010 is level 2")
	var changed: Dictionary = _first_of(level_events, "population_level_changed")
	t.eq(changed.get("from"), 1, "reports the old level")
	t.eq(changed.get("to"), 2, "reports the new level")
	t.eq(_growth(state2, db, "supply"), step_before + 1,
		"every active demand now grows 1 faster — success makes the next stretch harder")

	t.label("hysteresis keeps the level from flipping on the boundary")
	state2.population_count = 980  # 2% below the level-2 floor of 1000
	var jitter: Array[Dictionary] = []
	PopulationEngine.recompute_level(state2, db, jitter)
	t.eq(state2.population_level, 2, "a small dip does not drop the level")
	t.eq(jitter.size(), 0, "and reports nothing")

	t.label("levels can be lost, and that genuinely relieves pressure")
	state2.population_count = 900  # 10% below, past the 5% margin
	var lost: Array[Dictionary] = []
	PopulationEngine.recompute_level(state2, db, lost)
	t.eq(state2.population_level, 1, "a real loss drops the level")
	t.eq(_first_of(lost, "population_level_changed").get("to"), 1, "reported")
	t.eq(_growth(state2, db, "supply"), step_before, "the growth step eases back")

	t.label("an event that takes people away can cost a level")
	var state3: GameState = GameSetup.new_game(db, "test_age", 4)
	var engine3 := TurnEngine.new(db, state3)
	engine3.start_turn()
	state3.hand.clear()
	state3.population_count = 1100
	PopulationEngine.recompute_level(state3, db, [])
	t.eq(state3.population_level, 2, "level 2 before the event")
	state3.set_demand("supply", 6)
	state3.pending_event = "supply_collapse_test_age"
	state3.current_budget = 100
	engine3.resolve_event(1)  # -200 people
	t.eq(state3.population_count, 900, "the event moved the count")
	t.eq(state3.population_level, 1, "and the level followed")

	t.label("only the level is readable as a rule input; the count is data")
	var level_condition := ConditionDef.from_dict({
		"type": "resource", "resource": "population_level", "op": ">=", "value": 2,
	})
	t.is_true(not level_condition.evaluate(state3, db), "level 1 city fails a level-2 gate")
	state3.population_count = 3500
	PopulationEngine.recompute_level(state3, db, [])
	t.eq(state3.population_level, 3, "3500 is level 3")
	t.is_true(level_condition.evaluate(state3, db), "and now passes")


# --- helpers -----------------------------------------------------------------

## One turn of population growth in a city whose supply demand sits at `meter`.
func _one_turn_delta(db: ContentDB, seed_value: int, meter: int) -> int:
	var state: GameState = GameSetup.new_game(db, "test_age", seed_value)
	var engine := TurnEngine.new(db, state)
	state.set_demand("supply", meter)
	var events: Array[Dictionary] = engine.start_turn()
	return int(_first_of(events, "population_grew").get("delta", 0))


func _growth(state: GameState, db: ContentDB, demand_id: String) -> int:
	return ModifierPipeline.collect(state, db).demand_growth_step(demand_id)


func _first_of(events: Array[Dictionary], type_name: String) -> Dictionary:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			return event
	return {}
