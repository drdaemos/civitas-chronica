extends RefCounted

## Prerequisite validation and cost modifiers via ModifierPipeline.cost_of.


func run(t: TestContext) -> void:
	var db: ContentDB = Fixtures.build_db()

	t.label("unmet prerequisite rejected")
	var state: GameState = GameSetup.new_game(db, "test_age", 21)
	var engine := TurnEngine.new(db, state)
	engine.start_turn()
	state.hand.clear()
	state.current_budget = 100
	state.hand.append("harbor_expansion")
	var refused: Dictionary = engine.play_card("harbor_expansion")
	t.eq(refused.get("ok"), false, "harbor_expansion rejected without river_docks")
	t.is_true(String(refused.get("reason", "")).contains("prerequisite"),
		"reason names the prerequisite problem")
	t.is_true("harbor_expansion" in state.hand, "rejected card stays in hand")

	t.label("met prerequisite accepted")
	state.hand.append("river_docks")
	t.eq(engine.play_card("river_docks").get("ok"), true, "river_docks playable")
	t.eq(engine.play_card("harbor_expansion").get("ok"), true,
		"harbor_expansion playable once river_docks is in play")

	t.label("insufficient budget rejected")
	state.hand.append("town_market")
	state.current_budget = 1
	var poor: Dictionary = engine.play_card("town_market")
	t.eq(poor.get("ok"), false, "cost 3 rejected on budget 1")
	t.is_true(String(poor.get("reason", "")).contains("budget"), "reason names the budget")

	t.label("well_connected_city discount and min_cost floor")
	var state2: GameState = GameSetup.new_game(db, "test_age", 21)
	state2.active_interactions.append("well_connected_city")
	var pipeline: ModifierPipeline = ModifierPipeline.collect(state2, db)
	t.eq(pipeline.cost_of(db.get_card("town_market")), 2, "cost 3 discounted to 2")
	t.eq(pipeline.cost_of(db.get_card("harbor_expansion")), 4, "cost 5 discounted to 4")
	t.eq(pipeline.cost_of(db.get_card("festival_of_saints")), 1,
		"cost 1 - 1 = 0 raised back to the min_cost floor of 1")

	t.label("trade_hub industrial surcharge")
	var state3: GameState = GameSetup.new_game(db, "test_age", 21)
	state3.active_interactions.append("trade_hub")
	var pipeline3: ModifierPipeline = ModifierPipeline.collect(state3, db)
	t.eq(pipeline3.cost_of(db.get_card("iron_foundry")), 5, "industrial cost 4 -> 5")
	t.eq(pipeline3.cost_of(db.get_card("town_market")), 3, "non-industrial unaffected")

	t.label("stacked modifiers: surcharge + discount + floor")
	var state4: GameState = GameSetup.new_game(db, "test_age", 21)
	state4.active_interactions.append("trade_hub")
	state4.active_interactions.append("well_connected_city")
	var pipeline4: ModifierPipeline = ModifierPipeline.collect(state4, db)
	t.eq(pipeline4.cost_of(db.get_card("iron_foundry")), 4, "4 + 1 - 1 = 4")
	t.eq(pipeline4.cost_of(db.get_card("cobblestone_roads")), 1, "2 - 1 = 1, at the floor")

	t.label("cost may drain budget to exactly 0")
	var state5: GameState = GameSetup.new_game(db, "test_age", 21)
	var engine5 := TurnEngine.new(db, state5)
	engine5.start_turn()
	state5.hand.clear()
	state5.hand.append("town_market")
	state5.current_budget = 3
	t.eq(engine5.play_card("town_market").get("ok"), true, "exact-cost play allowed")
	t.eq(state5.current_budget, 0, "budget lands on exactly 0")
