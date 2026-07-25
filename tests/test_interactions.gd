extends RefCounted

## Interaction thresholds: single activation, instant effects once, pipeline
## income, first_discovery semantics, Appendix B double activation.


func run(t: TestContext) -> void:
	var db: ContentDB = Fixtures.build_db()

	t.label("third trade development activates trade_hub exactly once")
	var state: GameState = GameSetup.new_game(db, "test_age", 5)
	var engine := TurnEngine.new(db, state)
	engine.start_turn()
	state.hand.clear()  # controlled tableau: ignore the random draw
	Fixtures.force_play(engine, "town_market")
	Fixtures.force_play(engine, "river_docks")
	t.eq(InteractionEngine.check(state, db).size(), 0, "2 trade developments: no activation")
	Fixtures.force_play(engine, "harbor_expansion")
	var approval_before: int = state.approval
	var events: Array[Dictionary] = InteractionEngine.check(state, db)
	var activations: Array[Dictionary] = _of_type(events, "interaction_activated")
	t.eq(activations.size(), 1, "exactly one activation on the third trade dev")
	t.eq(activations[0].get("id"), "trade_hub", "activated interaction is trade_hub")
	t.eq(activations[0].get("first_discovery"), true, "first_discovery on first activation")
	t.is_true("trade_hub" in state.active_interactions, "trade_hub is active")
	t.eq(state.approval, approval_before + 5, "trade_hub instant effect applied once")

	t.label("no re-activation, instant effects not re-applied")
	var approval_after: int = state.approval
	var second: Array[Dictionary] = InteractionEngine.check(state, db)
	t.eq(_of_type(second, "interaction_activated").size(), 0, "no re-activation while active")
	t.eq(state.approval, approval_after, "instant effects not re-applied")
	t.eq(state.active_interactions.count("trade_hub"), 1, "trade_hub active exactly once")

	t.label("pipeline counts interaction income afterwards")
	var pipeline: ModifierPipeline = ModifierPipeline.collect(state, db)
	# market 1 + docks 1 + harbor 2 + trade_hub 2
	t.eq(pipeline.income_total(), 6, "income includes the trade_hub passive")

	t.label("first_discovery false once already seen")
	state.active_interactions.erase("trade_hub")  # simulate re-check of a seen interaction
	var re_events: Array[Dictionary] = InteractionEngine.check(state, db)
	var re_acts: Array[Dictionary] = _of_type(re_events, "interaction_activated")
	t.eq(re_acts.size(), 1, "re-activates once threshold holds")
	t.eq(re_acts[0].get("first_discovery"), false, "first_discovery false the second time")

	t.label("Appendix B: double activation in one check")
	var state2: GameState = GameSetup.new_game(db, "test_age", 5)
	var engine2 := TurnEngine.new(db, state2)
	engine2.start_turn()
	state2.hand.clear()
	Fixtures.force_play(engine2, "town_market")
	Fixtures.force_play(engine2, "river_docks")
	Fixtures.force_play(engine2, "cobblestone_roads")
	Fixtures.force_play(engine2, "grain_storehouse")
	t.eq(InteractionEngine.check(state2, db).size(), 0, "2 trade + 2 infrastructure: nothing yet")
	Fixtures.force_play(engine2, "harbor_expansion")  # 3rd of BOTH tags
	var both: Array[Dictionary] = _of_type(InteractionEngine.check(state2, db), "interaction_activated")
	t.eq(both.size(), 2, "both thresholds cross in the same check")
	t.is_true("trade_hub" in state2.active_interactions, "trade_hub active")
	t.is_true("well_connected_city" in state2.active_interactions, "well_connected_city active")
	for activation: Dictionary in both:
		t.eq(activation.get("first_discovery"), true, "both are first discoveries")
	t.eq(_of_type(InteractionEngine.check(state2, db), "interaction_activated").size(), 0,
		"no further activations on re-check")


func _of_type(events: Array[Dictionary], type_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			result.append(event)
	return result
