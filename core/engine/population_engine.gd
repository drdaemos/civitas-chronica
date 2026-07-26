class_name PopulationEngine
extends RefCounted

## Population as two numbers with different jobs (GDD 4.0 Population):
## the COUNT moves every turn and drives nothing; the LEVEL is the only
## population number any rule reads, and every level-up adds 1 to every active
## demand's growth step. Growth is a cost that cannot be switched off, only
## slowed — neglecting demands stalls the city instead of protecting it.


## Upkeep step 2: grow the count by this turn's delta, then recompute the level.
## Emits `population_grew` always and `population_level_changed` when the level
## moves, which is the event the rest of the engine actually cares about.
static func grow(state: GameState, db: ContentDB, age: AgeDef,
		events_out: Array[Dictionary]) -> void:
	var over: int = DemandEngine.demands_over_threshold(state, db)
	var multiplier: float = db.rules.growth_multiplier(over)
	if DemandEngine.any_at_catastrophe(state, db):
		multiplier = db.rules.decline_multiplier()  # decline regardless of the count
	var pipeline: ModifierPipeline = ModifierPipeline.collect(state, db)
	var base: float = float(age.population_growth_base) * multiplier
	base *= 1.0 + pipeline.pop_growth_mult()
	# ±variance so the numbers look alive, never enough to make level timing
	# unpredictable in practice. Always drawn, so the RNG stream advances
	# identically whether or not the city happens to be growing.
	var variance: float = db.rules.population_variance
	var roll: float = state.rng.rand_float("population") * 2.0 - 1.0
	var delta: int = int(round(base * (1.0 + roll * variance)))
	var before_count: int = state.population_count
	state.population_count = maxi(state.population_count + delta, 0)
	events_out.append({
		"type": "population_grew",
		"delta": state.population_count - before_count,
		"count": state.population_count,
		"demands_over_threshold": over,
	})
	recompute_level(state, db, events_out)


## Collapses the count into the level using the boundary table, with a
## hysteresis margin so the level does not flip while the count sits on a
## boundary. Levels CAN be lost: a disaster that costs the city a level
## genuinely relieves demand pressure (GDD 4.0).
static func recompute_level(state: GameState, db: ContentDB,
		events_out: Array[Dictionary]) -> void:
	var before: int = state.population_level
	var target: int = db.rules.level_for_count(state.population_count)
	if target < before:
		# Only drop once the count is clearly below the current level's floor.
		var floor_value: int = db.rules.level_lower_bound(before)
		var margin: float = float(floor_value) * (1.0 - db.rules.population_level_hysteresis)
		if float(state.population_count) >= margin:
			return
	if target == before:
		return
	state.population_level = target
	events_out.append({
		"type": "population_level_changed", "from": before, "to": target,
		"count": state.population_count,
	})


## Level for a fresh save: derived from the starting count, no hysteresis.
static func initial_level(state: GameState, db: ContentDB) -> int:
	return db.rules.level_for_count(state.population_count)
