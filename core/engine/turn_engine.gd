class_name TurnEngine
extends RefCounted

## Orchestrates the turn sequence (GDD 3): start_turn -> play_card* ->
## end_turn -> (resolve_event) -> next start_turn. Emits domain events as
## Dictionaries with a "type" key; the UI layer renders them.

var db: ContentDB = null
var state: GameState = null


func _init(content_db: ContentDB, game_state: GameState) -> void:
	db = content_db
	state = game_state


## Begins a new turn: bills last turn's event cost against fresh capacity,
## advances the debt-spiral counter, draws cards.
func start_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.game_over or state.pending_event != "" or state.transition_pending:
		return events
	state.turn_number += 1
	var pipeline: ModifierPipeline = ModifierPipeline.collect(state, db)
	var capacity: int = state.base_budget + pipeline.income_total()
	state.current_budget = capacity - state.pending_bill
	state.pending_bill = 0
	if state.current_budget < 0:
		state.debt_turns += 1
	else:
		state.debt_turns = 0
	if state.debt_turns >= 3:
		state.game_over = true
		state.outcome = GameState.OUTCOME_LOST_DEBT
		events.append(_game_over_event())
		return events
	var age: AgeDef = db.get_age(state.age_id)
	var draw_count: int = age.base_draw + pipeline.draw_bonus()
	var drawn: Array[String] = []
	for i: int in draw_count:
		if state.main_deck.is_empty():
			break
		var card_id: String = DeckManager.draw_top(state.main_deck)
		state.hand.append(card_id)
		drawn.append(card_id)
	events.append({
		"type": "turn_started",
		"turn": state.turn_number,
		"year": state.year,
		"budget": state.current_budget,
	})
	events.append({"type": "cards_drawn", "cards": drawn})
	return events


## Plays a card from hand. Interactions are NOT checked here — the
## interaction check is its own phase at end_turn (GDD 3).
func play_card(card_id: String) -> Dictionary:
	if state.game_over:
		return _refuse("game is over")
	if state.pending_event != "":
		return _refuse("an event is awaiting resolution")
	if state.transition_pending:
		return _refuse("an age transition is pending")
	if card_id not in state.hand:
		return _refuse("card is not in hand")
	var card: CardDef = db.get_card(card_id)
	if card == null:
		return _refuse("unknown card: " + card_id)
	if card.is_development():
		if state.has_development(card_id):
			return _refuse("already built: " + card_id)
		for prereq_id: String in card.prerequisites:
			if not state.has_development(prereq_id):
				return _refuse("missing prerequisite: " + prereq_id)
	var pipeline: ModifierPipeline = ModifierPipeline.collect(state, db)
	var cost: int = pipeline.cost_of(card)
	if cost > state.current_budget:
		return _refuse("not enough budget (cost %d, budget %d)" % [cost, state.current_budget])

	state.hand.erase(card_id)
	state.current_budget -= cost
	var events: Array[Dictionary] = []
	events.append({"type": "card_played", "card": card_id})
	if card.is_development():
		var dev := DevelopmentState.new()
		dev.card_id = card.id
		dev.tags = card.tags.duplicate()
		dev.effects = card.effects.duplicate()  # EffectDefs are immutable; refs shared
		dev.turn_played = state.turn_number
		state.developments.append(dev)
	else:
		state.consumed_cards.append(card.id)  # uniqueness ledger: actions never return
	EffectApplier.apply_instant(card.effects, state, events)
	EffectApplier.inject_main_filtered(card.inject_main, state, events)
	if not card.inject_events.is_empty():
		DeckManager.shuffle_into(state.event_deck, card.inject_events, state.rng, "events")
		events.append({"type": "cards_injected", "deck": "event", "count": card.inject_events.size()})
	return {"ok": true, "reason": "", "events": events}


## Ends the play phase: interaction check, then event draw. If an event
## fires, the turn suspends awaiting resolve_event; otherwise it finishes.
func end_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.game_over or state.pending_event != "" or state.transition_pending:
		return events
	events.append_array(InteractionEngine.check(state, db))
	var age: AgeDef = db.get_age(state.age_id)
	var event_id: String = age.forced_event_for_turn(state.turn_number)
	if event_id == "":
		event_id = EventMatcher.draw_matching(state, db)
	if event_id != "" and not db.events.has(event_id):
		# Defensive: an unknown pending_event can never be resolved and would
		# wedge the save. The content validator catches this statically; this
		# guard keeps even a broken save playable.
		push_error("end_turn: unknown event id \"%s\" skipped" % event_id)
		event_id = ""
	if event_id != "":
		state.pending_event = event_id
		if event_id not in state.seen_events:
			state.seen_events.append(event_id)
		events.append({"type": "event_fired", "id": event_id})
		return events
	events.append_array(_finish_turn())
	return events


## Resolves the pending event with the chosen option. The option's cost is
## billed at the start of the NEXT turn (event billing, GDD 3).
func resolve_event(option_index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.pending_event == "" or state.transition_pending:
		return events
	var event: EventDef = db.get_event(state.pending_event)
	if event == null or option_index < 0 or option_index >= event.options.size():
		return events
	var option: EventOptionDef = event.options[option_index]
	EffectApplier.apply_instant(option.effects, state, events)
	state.pending_bill += option.cost
	events.append({"type": "event_resolved", "id": event.id, "option": option_index})
	state.pending_event = ""
	events.append_array(_finish_turn())
	return events


## Activates an unlocked policy in a free slot. Swapping is not supported
## in the MVP.
func adopt_policy(policy_id: String) -> Dictionary:
	if state.transition_pending:
		return {"ok": false, "reason": "an age transition is pending"}
	if policy_id not in state.unlocked_policies:
		return {"ok": false, "reason": "policy is not unlocked"}
	if policy_id in state.active_policies:
		return {"ok": false, "reason": "policy is already active"}
	if state.active_policies.size() >= state.policy_slots:
		return {"ok": false, "reason": "no free policy slot"}
	state.active_policies.append(policy_id)
	return {"ok": true, "reason": ""}


# --- private ----------------------------------------------------------------

## End-of-turn recalculation: passive drifts, population growth, lose/win
## checks, time advance.
func _finish_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var pipeline: ModifierPipeline = ModifierPipeline.collect(state, db)
	state.approval += pipeline.approval_per_turn()
	state.migration_appeal += pipeline.migration_per_turn()
	var growth: int = int(round(
		float(state.population) * 0.01 * float(state.migration_appeal)
		* (1.0 + pipeline.pop_growth_mult())
	))
	state.population += growth
	state.clamp_resources()
	if state.approval < 20:
		state.low_approval_turns += 1
	else:
		state.low_approval_turns = 0
	if state.low_approval_turns >= 3:
		state.game_over = true
		state.outcome = GameState.OUTCOME_LOST_APPROVAL
		events.append(_game_over_event())
		return events
	var age: AgeDef = db.get_age(state.age_id)
	state.year += age.years_per_turn
	events.append({
		"type": "turn_ended",
		"year": state.year,
		"population": state.population,
		"approval": state.approval,
	})
	if state.year >= age.year_end:
		if age.next_age != "" and db.ages.has(age.next_age):
			# Not the final age: suspend for the transition phase (GDD 4.8).
			# The controller drives AgeTransition.decisions/apply next.
			state.transition_pending = true
			state.pending_transition_to = age.next_age
			events.append({"type": "age_ended", "from": age.id, "to": age.next_age})
		else:
			state.game_over = true
			state.outcome = GameState.OUTCOME_WON
			events.append({"type": "age_completed"})
			events.append(_game_over_event())
	return events


func _game_over_event() -> Dictionary:
	return {"type": "game_over", "outcome": state.outcome, "score": Scoring.score(state, db)}


func _refuse(reason: String) -> Dictionary:
	var empty: Array[Dictionary] = []
	return {"ok": false, "reason": reason, "events": empty}
