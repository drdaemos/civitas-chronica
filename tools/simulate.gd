extends SceneTree

## Headless balance simulator (TDD section 8). Plays full saves with simple
## bot policies over many seeded runs and prints aggregate statistics.
##
## Run: godot --headless --path . --script res://tools/simulate.gd -- --runs=50 --bot=random --seed=1000
## Bots: random   (plays random affordable cards; random event options),
##       greedy   (most expensive card first; option 0),
##       steward  (prioritizes the city's worst active demands and efficient
##                 event responses; adopts policies that support them),
##       turtle   (plays nothing; cheapest event options),
##       reckless (plays expensive cards and picks the most damaging available
##                 event response — the lose-scenario prober).
##
## Age transitions take no player input (GDD 4.8), so no bot has a transition
## policy any more. Every bot discards its cheapest cards when over the hand
## limit, so overflow can never stall a run.

const MAX_TURNS_SAFETY: int = 500


func _initialize() -> void:
	var runs: int = 20
	var bot: String = "random"
	var base_seed: int = 1000
	var age_id: String = "age1"
	var suite_requested: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--bot="):
			bot = arg.get_slice("=", 1)
		elif arg.begins_with("--seed="):
			base_seed = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--age="):
			age_id = arg.get_slice("=", 1)
		elif arg == "--suite":
			suite_requested = true

	var db: ContentDB = ContentDB.load_from_dir("res://content")
	var errors: Array[String] = db.validate()
	if not errors.is_empty():
		for error: String in errors:
			printerr(error)
		printerr("simulate: content invalid (%d errors), aborting" % errors.size())
		quit(1)
		return
	if suite_requested:
		_run_verification_suite(db, runs, base_seed)
		return

	var outcomes: Dictionary = {}
	var outcome_turns: Dictionary = {}  # outcome -> total turns across its runs
	var ages_reached: Dictionary = {}   # age id -> number of runs that entered it
	var total_score: int = 0
	var total_population: int = 0
	var total_turns: int = 0
	var total_events_seen: int = 0
	var total_level: int = 0
	var demand_totals: Dictionary = {}    # demand id -> summed final meter
	var demand_over_runs: Dictionary = {} # demand id -> runs that ended over threshold
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
		total_level += int(result["level"])
		var final_demands: Dictionary = result["demands"]
		for demand_id: String in final_demands:
			var value: int = int(final_demands[demand_id])
			demand_totals[demand_id] = int(demand_totals.get(demand_id, 0)) + value
			if value >= db.rules.threshold_for(demand_id):
				demand_over_runs[demand_id] = int(demand_over_runs.get(demand_id, 0)) + 1
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
	print("avg population level: %.2f" % (float(total_level) / runs))
	print("final demand meters (avg | runs ending over threshold):")
	for demand: DemandDef in db.rules.demands:
		if not demand_totals.has(demand.id):
			continue
		print("  %s: %.1f | %d/%d" % [
			demand.id, float(demand_totals[demand.id]) / runs,
			int(demand_over_runs.get(demand.id, 0)), runs,
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


## A compact, exit-code-bearing balance gate for local verification and CI.
## It deliberately tests several bad and good decision policies rather than
## asserting one exact win rate for a single bot.
func _run_verification_suite(db: ContentDB, runs: int, base_seed: int) -> void:
	var bots: Array[String] = ["random", "greedy", "steward", "reckless", "turtle"]
	var summaries: Dictionary = {}
	for bot: String in bots:
		var wins: int = 0
		var catastrophes: int = 0
		var debt_losses: int = 0
		var age5_reached: int = 0
		var transitions: int = 0
		var interactions_total: int = 0
		for i: int in runs:
			# Widely spaced seeds catch stream-specific clusters while keeping
			# the whole matrix deterministic and reproducible.
			var seed_value: int = base_seed + i * 97
			var result: Dictionary = _play_one(db, "age1", seed_value, bot)
			var outcome: String = String(result["outcome"])
			if outcome == GameState.OUTCOME_WON:
				wins += 1
			elif outcome == GameState.OUTCOME_LOST_CATASTROPHE:
				catastrophes += 1
			elif outcome == GameState.OUTCOME_LOST_DEBT:
				debt_losses += 1
			var reached: Array = result["ages_reached"]
			if "age5" in reached:
				age5_reached += 1
			transitions += maxi(0, reached.size() - 1)
			interactions_total += (result["interactions"] as Array).size()
		summaries[bot] = {
			"wins": wins,
			"catastrophes": catastrophes,
			"debt_losses": debt_losses,
			"age5_reached": age5_reached,
			"avg_transitions": float(transitions) / float(runs),
			"avg_interactions": float(interactions_total) / float(runs),
		}

	print("balance suite: runs=%d per bot base_seed=%d" % [runs, base_seed])
	for bot: String in bots:
		var summary: Dictionary = summaries[bot]
		print("  %s: wins=%d/%d age5=%d/%d avg_transitions=%.2f avg_interactions=%.2f" % [
			bot, int(summary["wins"]), runs, int(summary["age5_reached"]), runs,
			float(summary["avg_transitions"]), float(summary["avg_interactions"]),
		])

	var failures: Array[String] = []
	var steward: Dictionary = summaries["steward"]
	var steward_rate: float = float(steward["wins"]) / float(runs)
	if steward_rate < 0.60:
		failures.append("steward win rate %.2f is below 0.60 (too hard for demand-aware play)" % steward_rate)
	if steward_rate > 0.98:
		failures.append("steward win rate %.2f is above 0.98 (no meaningful failure pressure)" % steward_rate)
	if float(steward["age5_reached"]) / float(runs) < 0.65:
		failures.append("fewer than 65%% of steward runs reach age5")
	if int((summaries["turtle"] as Dictionary)["wins"]) != 0:
		failures.append("turtle bot can win without building")
	if float((summaries["reckless"] as Dictionary)["wins"]) / float(runs) > 0.20:
		failures.append("reckless win rate exceeds 0.20")
	if float((summaries["random"] as Dictionary)["wins"]) / float(runs) > 0.50:
		failures.append("random win rate exceeds 0.50 (choices are not carrying enough weight)")
	if float(steward["avg_transitions"]) < 3.0:
		failures.append("steward averages fewer than three age transitions")

	if failures.is_empty():
		print("balance suite: PASS")
		quit(0)
		return
	for failure: String in failures:
		printerr("balance suite: " + failure)
	quit(1)


func _play_one(db: ContentDB, age_id: String, seed_value: int, bot: String) -> Dictionary:
	var state: GameState = GameSetup.new_game(db, age_id, seed_value)
	var engine: TurnEngine = TurnEngine.new(db, state)
	var decision_rng := RandomNumberGenerator.new()
	decision_rng.seed = seed_value * 7919 + 13
	var turns_played: int = 0
	var safety: int = MAX_TURNS_SAFETY

	while not state.game_over and safety > 0:
		safety -= 1
		# Phases in GDD 3 order: upkeep and the event draw, the player's answer
		# to whatever it produced, then the play phase and the turn's close.
		engine.start_turn()
		if state.game_over:
			break
		turns_played += 1
		if state.pending_event != "":
			_bot_resolve_event(engine, state, db, bot, decision_rng)
			if state.game_over:
				break
		_bot_play_phase(engine, state, bot, decision_rng)
		_bot_discard_to_limit(engine, state, db)
		engine.end_turn()
		if state.transition_pending:
			AgeTransition.apply(state, db)

	var reached: Array[String] = state.completed_ages.duplicate()
	if state.age_id not in reached:
		reached.append(state.age_id)
	var score: Dictionary = Scoring.score(state, db)
	return {
		"outcome": state.outcome if state.outcome != "" else "timeout",
		"score": int(score.get("total", 0)),
		"population": state.population_count,
		"level": state.population_level,
		"demands": state.demands.duplicate(),
		"turns": turns_played,
		"events_seen": state.seen_events.size(),
		"interactions": Array(state.interactions_fired),
		"ages_reached": reached,
	}


func _bot_play_phase(engine: TurnEngine, state: GameState, bot: String, rng: RandomNumberGenerator) -> void:
	if bot == "turtle":
		return
	_bot_adopt_policy(engine, state, bot, rng)
	var made_progress: bool = true
	while made_progress:
		made_progress = false
		var candidates: Array[String] = []
		candidates.assign(state.hand)
		if bot == "greedy" or bot == "reckless":
			var db: ContentDB = engine.db
			candidates.sort_custom(func(a: String, b: String) -> bool:
				return db.get_card(a).cost > db.get_card(b).cost)
		elif bot == "steward":
			candidates.sort_custom(func(a: String, b: String) -> bool:
				return _card_priority(engine.db.get_card(a), state, engine.db) \
						> _card_priority(engine.db.get_card(b), state, engine.db))
		else:
			# random order via decision rng (not the game's RngService — bots
			# are not part of the sim's determinism contract)
			for i: int in range(candidates.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, i)
				var tmp: String = candidates[i]
				candidates[i] = candidates[j]
				candidates[j] = tmp
		for card_id: String in candidates:
			if bot == "steward" and _card_priority(
					engine.db.get_card(card_id), state, engine.db) <= 0.0:
				continue
			var result: Dictionary = engine.play_card(card_id)
			if bool(result.get("ok", false)):
				made_progress = true
				break


func _bot_resolve_event(engine: TurnEngine, state: GameState, db: ContentDB, bot: String, rng: RandomNumberGenerator) -> void:
	var event: EventDef = db.get_event(state.pending_event)
	if event == null or event.options.is_empty():
		return
	# Conditional options (GDD 4.4) only exist for cities that built the card.
	var available: Array[int] = []
	for i: int in event.options.size():
		if event.options[i].is_available(state):
			available.append(i)
	if available.is_empty():
		return
	var choice: int = available[0]
	match bot:
		"turtle":
			for i: int in available:
				if event.options[i].cost < event.options[choice].cost:
					choice = i
		"reckless":
			# Lowest-value response: a deliberate stress case.
			for i: int in available:
				if _option_priority(event.options[i], state) \
						< _option_priority(event.options[choice], state):
					choice = i
		"greedy":
			for i: int in available:
				if _option_priority(event.options[i], state) \
						> _option_priority(event.options[choice], state):
					choice = i
		"steward":
			for i: int in available:
				if _option_priority(event.options[i], state) \
						> _option_priority(event.options[choice], state):
					choice = i
		_:
			choice = available[rng.randi_range(0, available.size() - 1)]
	engine.resolve_event(choice)


func _card_priority(card: CardDef, state: GameState, db: ContentDB) -> float:
	if card == null:
		return -1000.0
	var score: float = -0.35 * float(card.cost)
	if card.is_development():
		score += float(card.hand_limit_bonus) * 3.0
		var pipeline: ModifierPipeline = ModifierPipeline.collect(state, db)
		for demand_id: String in card.demands:
			var printed: int = int(card.demands[demand_id])
			if state.is_demand_active(demand_id):
				var urgency: float = 2.0
				var threshold: int = db.rules.threshold_for(demand_id)
				if state.demand_value(demand_id) >= threshold:
					urgency = 5.0
				elif state.demand_value(demand_id) >= threshold - 2:
					urgency = 3.5
				urgency += float(pipeline.demand_growth_step(demand_id)) * 0.75
				score -= float(printed) * urgency
			else:
				# Future liabilities matter, but less than a live emergency.
				score -= float(printed) * (2.0 if printed > 0 else 0.5)
	for effect: EffectDef in card.effects:
		match effect.type:
			"income":
				score += effect.amount * 2.0
			"demand_delta":
				if state.is_demand_active(effect.demand):
					score -= effect.amount * 3.0
			"resource_delta":
				if effect.resource == "budget":
					score += effect.amount
				elif effect.resource == "population_count":
					score += effect.amount / 250.0
	return score


func _option_priority(option: EventOptionDef, state: GameState) -> float:
	var score: float = -float(option.cost) * 0.8
	for effect: EffectDef in option.effects:
		match effect.type:
			"demand_delta":
				if state.is_demand_active(effect.demand):
					score -= effect.amount * 4.0
			"resource_delta":
				if effect.resource == "budget":
					score += effect.amount
				elif effect.resource == "population_count":
					score += effect.amount / 100.0
			"unlock_policy":
				score += 1.0
			"inject_main":
				score += float(effect.cards.size()) * 0.5
	return score


func _bot_adopt_policy(engine: TurnEngine, state: GameState, bot: String,
		rng: RandomNumberGenerator) -> void:
	if state.active_policies.size() >= state.policy_slots:
		return
	var candidates: Array[String] = []
	for policy_id: String in state.unlocked_policies:
		if policy_id not in state.active_policies:
			candidates.append(policy_id)
	if candidates.is_empty():
		return
	if bot == "random":
		var pick: String = candidates[rng.randi_range(0, candidates.size() - 1)]
		engine.adopt_policy(pick)
		return
	candidates.sort_custom(func(a: String, b: String) -> bool:
		return _policy_priority(engine.db.get_policy(a), state) \
				> _policy_priority(engine.db.get_policy(b), state))
	if bot == "reckless":
		engine.adopt_policy(candidates[candidates.size() - 1])
	else:
		engine.adopt_policy(candidates[0])


func _policy_priority(policy: PolicyDef, state: GameState) -> float:
	if policy == null:
		return -1000.0
	var score: float = 0.0
	for effect: EffectDef in policy.effects:
		match effect.type:
			"income":
				score += effect.amount * 2.0
			"demand_modifier", "demand_modifier_per_tag":
				var urgency: float = 1.0
				if state.is_demand_active(effect.demand):
					urgency = 3.0
				score -= effect.amount * urgency
			"cost_modifier":
				score -= effect.amount
	return score


## Discards the cheapest cards when over the hand limit (GDD 4.1). A cheap
## uniform policy across all bots: hand management is not what these bots are
## meant to differentiate, but the turn cannot end without it.
func _bot_discard_to_limit(engine: TurnEngine, state: GameState, db: ContentDB) -> void:
	var overflow: int = DeckManager.hand_overflow(state, db)
	if overflow <= 0:
		return
	var candidates: Array[String] = state.hand.duplicate()
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var card_a: CardDef = db.get_card(a)
		var card_b: CardDef = db.get_card(b)
		var cost_a: int = card_a.cost if card_a != null else 0
		var cost_b: int = card_b.cost if card_b != null else 0
		if cost_a == cost_b:
			return a < b  # stable, id-ordered tie-break
		return cost_a < cost_b)
	engine.discard_cards(candidates.slice(0, overflow))
