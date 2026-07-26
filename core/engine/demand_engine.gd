class_name DemandEngine
extends RefCounted

## Owns the demand meters (GDD 4.0). Demands never damage the city directly —
## they load the event deck, and every consequence arrives through an event the
## player gets to answer. Nothing here names a specific demand: the set of
## demands, their tolerances and their order all come from content
## (RulesDef/DemandDef), so they can be re-cut after playtests.


## Applies one growth step to every active demand (upkeep step 3). Emits one
## `demand_grew` per demand that moved, plus a `demand_over_threshold` the turn
## a demand crosses into emergency territory.
static func apply_growth(state: GameState, db: ContentDB, events_out: Array[Dictionary]) -> void:
	var pipeline: ModifierPipeline = ModifierPipeline.collect(state, db)
	for demand_id: String in state.active_demands:
		var step: int = pipeline.demand_growth_step(demand_id)
		if step == 0:
			continue  # equilibrium: the row is quiet by design
		var before: int = state.demand_value(demand_id)
		var threshold: int = db.rules.threshold_for(demand_id)
		state.set_demand(demand_id, before + step)
		var after: int = state.demand_value(demand_id)
		events_out.append({
			"type": "demand_grew", "demand": demand_id,
			"from": before, "to": after, "step": step,
		})
		if before < threshold and after >= threshold:
			events_out.append({
				"type": "demand_over_threshold", "demand": demand_id,
				"value": after, "threshold": threshold,
			})


## Shuffles pressure cards into the event deck (upkeep step 4): one emergency
## per demand at or above its threshold, plus one catastrophe per demand at or
## above its catastrophe value. Duplicates are expected — this is the entire
## punishment mechanism, and a demand ignored for ten turns has stuffed ten
## cards into a deck that surfaces them at a time the player does not choose.
static func shuffle_pressure_cards(state: GameState, db: ContentDB,
		events_out: Array[Dictionary]) -> void:
	for demand_id: String in state.active_demands:
		var value: int = state.demand_value(demand_id)
		if value < db.rules.threshold_for(demand_id):
			continue
		_shuffle_one(state, db, demand_id, EventDef.SEVERITY_EMERGENCY, events_out)
		if value >= db.rules.catastrophe_for(demand_id):
			_shuffle_one(state, db, demand_id, EventDef.SEVERITY_CATASTROPHE, events_out)


## Activates a demand for the age that introduces it (GDD 4.0 Age activation).
## The meter does not start at 0 unless the city happens to be clean: every
## standing development's printed value is counted, exactly as if the cards had
## just been played. This is how a city gets measured against a standard that
## did not exist when it was built.
static func activate(state: GameState, db: ContentDB, demand_id: String,
		events_out: Array[Dictionary]) -> int:
	if demand_id == "" or state.is_demand_active(demand_id):
		return state.demand_value(demand_id)
	if not db.rules.has_demand(demand_id):
		push_error("DemandEngine: unknown demand \"%s\"" % demand_id)
		return 0
	state.active_demands.append(demand_id)
	state.demands[demand_id] = 0
	state.set_demand(demand_id, state.printed_demand_total(demand_id))
	var value: int = state.demand_value(demand_id)
	events_out.append({
		"type": "demand_activated", "demand": demand_id, "value": value,
		"threshold": db.rules.threshold_for(demand_id),
	})
	return value


## One-time meter movement from an event option or action card, clamped at 0.
## Never touches a growth step (GDD 4.0).
static func apply_delta(state: GameState, demand_id: String, amount: int,
		events_out: Array[Dictionary]) -> void:
	if not state.is_demand_active(demand_id) or amount == 0:
		return
	var before: int = state.demand_value(demand_id)
	state.set_demand(demand_id, before + amount)
	var after: int = state.demand_value(demand_id)
	if after != before:
		events_out.append({
			"type": "demand_changed", "demand": demand_id, "from": before, "to": after,
		})


## Applies a development's printed values the moment it is built: the meter
## moves by the printed amount immediately (clamped at 0, which is what stops
## the player buffering against problems they do not have yet), while the
## permanent half is read straight off the standing development by the pipeline.
static func apply_printed_on_play(state: GameState, dev: DevelopmentState,
		events_out: Array[Dictionary]) -> void:
	for demand_id: String in dev.demands:
		apply_delta(state, demand_id, dev.printed_demand(demand_id), events_out)


## Active demands at or above their threshold — the count that governs
## population growth (GDD 4.0 Population).
static func demands_over_threshold(state: GameState, db: ContentDB) -> int:
	var count: int = 0
	for demand_id: String in state.active_demands:
		if state.demand_value(demand_id) >= db.rules.threshold_for(demand_id):
			count += 1
	return count


static func any_at_catastrophe(state: GameState, db: ContentDB) -> bool:
	for demand_id: String in state.active_demands:
		if state.demand_value(demand_id) >= db.rules.catastrophe_for(demand_id):
			return true
	return false


## True when this event is a catastrophe card whose demand is STILL far above
## tolerance — the save-ending condition (GDD 3 Lose conditions). Pulling the
## meter back down before the card surfaces removes the danger entirely.
static func is_fatal_catastrophe(state: GameState, db: ContentDB, event: EventDef) -> bool:
	if event == null or not event.is_catastrophe() or event.demand == "":
		return false
	return state.demand_value(event.demand) >= db.rules.catastrophe_for(event.demand)


# --- private ----------------------------------------------------------------

## Picks one pressure event for a demand from the `events` RNG stream and
## shuffles it in. Candidates are restricted to the current age's events so an
## era's crises stay era-appropriate.
static func _shuffle_one(state: GameState, db: ContentDB, demand_id: String,
		severity: String, events_out: Array[Dictionary]) -> void:
	var candidates: Array[String] = db.pressure_events(demand_id, severity, state.age_id)
	if candidates.is_empty():
		# The validator rejects this statically; a broken save just gets no card.
		push_error("DemandEngine: no %s event for demand \"%s\" in age \"%s\"" % [
			severity, demand_id, state.age_id,
		])
		return
	var pick: String = candidates[state.rng.rand_int("events", 0, candidates.size() - 1)]
	var payload: Array[String] = [pick]
	DeckManager.shuffle_into(state.event_deck, payload, state.rng, "events")
	events_out.append({
		"type": "pressure_card_shuffled", "demand": demand_id,
		"severity": severity, "event": pick,
	})
