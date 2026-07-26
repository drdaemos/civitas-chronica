extends RefCounted

## Scoring: population / 10 + 25 per active interaction + heritage
## (5 per age survived by a development, +10 per supersession it came through).


func run(t: TestContext) -> bool:
	var db: ContentDB = Fixtures.build_db()

	t.label("score formula")
	var state: GameState = GameSetup.new_game(db, "test_age", 1)
	state.population_count = 630
	state.active_interactions.assign(["trade_hub", "well_connected_city"])
	var result: Dictionary = Scoring.score(state, db)
	t.eq(result.get("population"), 63, "population axis is population / 10")
	t.eq(result.get("specialization"), 25 * 2, "25 per active interaction")
	t.eq(result.get("heritage"), 0, "fresh city has no heritage")
	t.eq(result.get("total"), 63 + 50, "total is the sum of the axes")

	t.label("integer division and empty interactions")
	state.population_count = 999
	state.active_interactions.clear()
	var result2: Dictionary = Scoring.score(state, db)
	t.eq(result2.get("population"), 99, "population score uses integer division")
	t.eq(result2.get("specialization"), 0, "no interactions, no specialization score")
	t.eq(result2.get("total"), 99, "total matches")

	t.label("score grows with interactions")
	state.active_interactions.assign(["trade_hub"])
	t.eq(Scoring.score(state, db).get("total"), 99 + 25, "one interaction adds 25")

	t.label("heritage axis: survivors and superseded developments")
	var dev_a := DevelopmentState.new()
	dev_a.card_id = "town_market"
	dev_a.ages_survived = 2
	dev_a.superseded_count = 1
	var dev_b := DevelopmentState.new()
	dev_b.card_id = "stone_church"
	dev_b.ages_survived = 1
	state.developments.append(dev_a)
	state.developments.append(dev_b)
	var result3: Dictionary = Scoring.score(state, db)
	t.eq(result3.get("heritage"), 5 * 3 + 10 * 1, "5 per age survived + 10 per supersession")
	t.eq(result3.get("total"), 99 + 25 + 25, "total includes heritage")
	return true
