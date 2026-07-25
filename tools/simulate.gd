extends SceneTree

## Headless balance simulator (TDD section 8). Plays full saves with simple
## bot policies over many seeded runs and prints aggregate statistics.
##
## Run: godot --headless --path . --script res://tools/simulate.gd -- --runs=50 --bot=random --seed=1000
## Bots: random   (plays random affordable cards; random event options;
##                 uniformly random transition choices per development),
##       greedy   (most expensive card first; option 0; adapts where available),
##       turtle   (plays nothing; cheapest event options; preserves everything),
##       reckless (plays like greedy, but always picks the HIGHEST-cost event
##                 option and demolishes everything at transitions — the
##                 lose-scenario prober).

const MAX_TURNS_SAFETY: int = 500


func _initialize() -> void:
	var runs: int = 20
	var bot: String = "random"
	var base_seed: int = 1000
	var age_id: String = "age1"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--bot="):
			bot = arg.get_slice("=", 1)
		elif arg.begins_with("--seed="):
			base_seed = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--age="):
			age_id = arg.get_slice("=", 1)

	var db: ContentDB = ContentDB.load_from_dir("res://content")
	var errors: Array[String] = db.validate()
	if not errors.is_empty():
		for error: String in errors:
			printerr(error)
		printerr("simulate: content invalid (%d errors), aborting" % errors.size())
		quit(1)
		return

	var outcomes: Dictionary = {}
	var outcome_turns: Dictionary = {}  # outcome -> total turns across its runs
	var ages_reached: Dictionary = {}   # age id -> number of runs that entered it
	var total_score: int = 0
	var total_population: int = 0
	var total_turns: int = 0
	var total_events_seen: int = 0
	var interaction_hits: Dictionary = {}

	for i: int in runs:
		var result: Dictionary = _play_one(db, age_id, base_seed + i, bot)
		var outcome: String = result["outcome"]
		outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
		outcome_turns[outcome] = int(outcome_turns.get(outcome, 0)) + int(result["turns"])
		total_score += int(result["score"])
		total_population += int(result["population"])
		total_turns += int(result["turns"])
		total_events_seen += int(result["events_seen"])
		for interaction_id: String in result["interactions"]:
			interaction_hits[interaction_id] = int(interaction_hits.get(interaction_id, 0)) + 1
		for reached_id: String in result["ages_reached"]:
			ages_reached[reached_id] = int(ages_reached.get(reached_id, 0)) + 1

	print("simulate: bot=%s runs=%d age=%s base_seed=%d" % [bot, runs, age_id, base_seed])
	print("outcomes: %s" % JSON.stringify(outcomes))
	print("avg score: %.1f | avg population: %.1f | avg turns: %.1f | avg events seen: %.1f" % [
		float(total_score) / runs, float(total_population) / runs,
		float(total_turns) / runs, float(total_events_seen) / runs,
	])
	print("avg turns per outcome:")
	var outcome_keys: Array = outcomes.keys()
	outcome_keys.sort()
	for outcome_key: String in outcome_keys:
		print("  %s: %.1f (n=%d)" % [
			outcome_key,
			float(outcome_turns[outcome_key]) / float(outcomes[outcome_key]),
			int(outcomes[outcome_key]),
		])
	print("ages reached:")
	var age_ids: Array = db.ages.keys()
	age_ids.sort()
	for reached_age_id: String in age_ids:
		print("  reached %s: %d/%d" % [reached_age_id, int(ages_reached.get(reached_age_id, 0)), runs])
	print("interaction activation rate:")
	var interaction_ids: Array = interaction_hits.keys()
	interaction_ids.sort()
	for interaction_id: String in interaction_ids:
		print("  %s: %d/%d" % [interaction_id, int(interaction_hits[interaction_id]), runs])
	for interaction_id: String in db.interactions:
		if not interaction_hits.has(interaction_id):
			print("  %s: 0/%d (never activated!)" % [interaction_id, runs])
	quit(0)


func _play_one(db: ContentDB, age_id: String, seed_value: int, bot: String) -> Dictionary:
	var state: GameState = GameSetup.new_game(db, age_id, seed_value)
	var engine: TurnEngine = TurnEngine.new(db, state)
	var decision_rng := RandomNumberGenerator.new()
	decision_rng.seed = seed_value * 7919 + 13
	var turns_played: int = 0
	var safety: int = MAX_TURNS_SAFETY

	while not state.game_over and safety > 0:
		safety -= 1
		engine.start_turn()
		if state.game_over:
			break
		turns_played += 1
		_bot_play_phase(engine, state, bot, decision_rng)
		engine.end_turn()
		if state.pending_event != "":
			_bot_resolve_event(engine, state, db, bot, decision_rng)
		if state.transition_pending:
			_bot_transition(state, db, bot, decision_rng)

	var reached: Array[String] = state.completed_ages.duplicate()
	if state.age_id not in reached:
		reached.append(state.age_id)
	var score: Dictionary = Scoring.score(state, db)
	return {
		"outcome": state.outcome if state.outcome != "" else "timeout",
		"score": int(score.get("total", 0)),
		"population": state.population,
		"turns": turns_played,
		"events_seen": state.seen_events.size(),
		"interactions": Array(state.active_interactions),
		"ages_reached": reached,
	}


func _bot_play_phase(engine: TurnEngine, state: GameState, bot: String, rng: RandomNumberGenerator) -> void:
	if bot == "turtle":
		return
	var made_progress: bool = true
	while made_progress:
		made_progress = false
		var candidates: Array[String] = []
		candidates.assign(state.hand)
		if bot == "greedy" or bot == "reckless":
			var db: ContentDB = engine.db
			candidates.sort_custom(func(a: String, b: String) -> bool:
				return db.get_card(a).cost > db.get_card(b).cost)
		else:
			# random order via decision rng (not the game's RngService — bots
			# are not part of the sim's determinism contract)
			for i: int in range(candidates.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, i)
				var tmp: String = candidates[i]
				candidates[i] = candidates[j]
				candidates[j] = tmp
		for card_id: String in candidates:
			var result: Dictionary = engine.play_card(card_id)
			if bool(result.get("ok", false)):
				made_progress = true
				break


func _bot_resolve_event(engine: TurnEngine, state: GameState, db: ContentDB, bot: String, rng: RandomNumberGenerator) -> void:
	var event: EventDef = db.get_event(state.pending_event)
	if event == null or event.options.is_empty():
		return
	var choice: int = 0
	match bot:
		"turtle":
			var cheapest: int = 0
			for i: int in event.options.size():
				if event.options[i].cost < event.options[cheapest].cost:
					cheapest = i
			choice = cheapest
		"reckless":
			# Highest-cost option, first on ties: the lose-scenario prober.
			var priciest: int = 0
			for i: int in event.options.size():
				if event.options[i].cost > event.options[priciest].cost:
					priciest = i
			choice = priciest
		"greedy":
			choice = 0
		_:
			choice = rng.randi_range(0, event.options.size() - 1)
	engine.resolve_event(choice)


## Builds transition choices from AgeTransition.decisions() and applies them.
func _bot_transition(state: GameState, db: ContentDB, bot: String, rng: RandomNumberGenerator) -> void:
	var decision_list: Array[Dictionary] = AgeTransition.decisions(state, db)
	var choices: Dictionary = {}
	for entry: Dictionary in decision_list:
		var card_id: String = String(entry.get("card_id", ""))
		var can_adapt: bool = entry.get("adapt") != null
		match bot:
			"turtle":
				choices[card_id] = "preserve"
			"greedy":
				choices[card_id] = "adapt" if can_adapt else "preserve"
			"reckless":
				choices[card_id] = "demolish"
			_:
				var options: Array[String] = ["preserve", "demolish"]
				if can_adapt:
					options.append("adapt")
				choices[card_id] = options[rng.randi_range(0, options.size() - 1)]
	AgeTransition.apply(state, db, choices)
