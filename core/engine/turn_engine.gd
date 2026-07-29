class_name TurnEngine
extends RefCounted

## Orchestrates the turn sequence (GDD 3) in its three phases, in order:
##
##   Phase 1 UPKEEP  — bill, budget, population, demand growth, pressure cards,
##                     clock. Runs to completion on its own.
##   Phase 2 EVENTS  — draw until a trigger matches; blocks on the player if an
##                     event fires.
##   Phase 3 PLAY    — draw hand, play cards, interaction check, hand limit.
##
## The city acts before the player does: growth and demand pressure resolve
## first, the crisis they produced is drawn second, and the player commits
## budget last, having seen both. Nothing the player cannot see happens after
## they spend.
##
## start_turn() runs phases 1 and 2 and either stops on a pending event or falls
## through into the hand draw. end_turn() closes phase 3. Domain events are
## Dictionaries with a "type" key; the UI layer renders them.

const DEBT_TURNS_TO_LOSE: int = 3

var db: ContentDB = null
var state: GameState = null


func _init(content_db: ContentDB, game_state: GameState) -> void:
	db = content_db
	state = game_state


## Phase 1 (upkeep) followed by phase 2 (event draw). If an event fires the
## turn suspends awaiting resolve_event, which then opens phase 3; otherwise
## phase 3's draw happens here. A fresh run may suppress the opening event
## phase so the player can meet the city and its hand before facing a crisis.
func start_turn(suppress_event_phase: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.game_over or state.pending_event != "" or state.transition_pending:
		return events
	state.turn_number += 1
	var age: AgeDef = db.get_age(state.age_id)

	# 1. Budget refreshes fully; last turn's event bill comes off the top.
	var pipeline: ModifierPipeline = ModifierPipeline.collect(state, db)
	var capacity: int = state.base_budget + pipeline.income_total()
	state.current_budget = capacity - state.pending_bill
	state.pending_bill = 0
	if state.current_budget < 0:
		state.debt_turns += 1
	else:
		state.debt_turns = 0
	events.append({
		"type": "turn_started",
		"turn": state.turn_number,
		"year": state.year,
		"budget": state.current_budget,
	})
	if state.debt_turns >= DEBT_TURNS_TO_LOSE:
		state.game_over = true
		state.outcome = GameState.OUTCOME_LOST_DEBT
		events.append(_game_over_event())
		return events

	# 2-4. The city moves: people, then demands, then the crises they cause.
	PopulationEngine.grow(state, db, age, events)
	DemandEngine.apply_growth(state, db, events)
	DemandEngine.shuffle_pressure_cards(state, db, events)

	# 5. Time advances.
	state.year += age.years_per_turn

	# Phase 2 — events.
	var event_id: String = ""
	if not suppress_event_phase:
		event_id = age.forced_event_for_turn(state.turn_number)
		if event_id == "":
			event_id = EventMatcher.draw_matching(state, db)
	if event_id != "" and not db.events.has(event_id):
		# Defensive: an unknown pending_event can never be resolved and would
		# wedge the save. The content validator catches this statically; this
		# guard keeps even a broken save playable.
		push_error("start_turn: unknown event id \"%s\" skipped" % event_id)
		event_id = ""
	if event_id != "":
		events.append(_fire_event(event_id))
		return events
	events.append_array(_draw_phase())
	return events


## Resolves the pending event with the chosen option, then opens phase 3. The
## option's cost is billed at the start of the NEXT turn (event billing, GDD 3).
## If a standing development cancels the event's hazard type the option's
## harmful effects are dropped (GDD 4.4).
func resolve_event(option_index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.pending_event == "" or state.transition_pending:
		return events
	var event: EventDef = db.get_event(state.pending_event)
	if event == null or option_index < 0 or option_index >= event.options.size():
		return events
	var option: EventOptionDef = event.options[option_index]
	if not option.is_available(state):
		# Conditional options are gated on a standing development; the UI
		# hides them, but a stale click must never sneak one through.
		return events
	var cancelled_by: String = EventMatcher.hazard_cancelled_by(state, db, event)
	if cancelled_by != "":
		events.append({
			"type": "hazard_cancelled",
			"id": event.id,
			"hazard": event.hazard,
			"by": cancelled_by,
		})
	# Whether this card is fatal is decided by the state it was drawn against,
	# before the chosen option pays anything down: the city is lost because the
	# demand was still in the red when the catastrophe arrived (GDD 3).
	var fatal: bool = cancelled_by == "" and DemandEngine.is_fatal_catastrophe(state, db, event)
	EffectApplier.apply_instant(
		EventMatcher.effects_after_cancellation(option, cancelled_by != ""), state, events)
	PopulationEngine.recompute_level(state, db, events)  # events may move the count
	state.pending_bill += option.cost
	events.append({"type": "event_resolved", "id": event.id, "option": option_index})
	state.pending_event = ""

	# A catastrophe card drawn for a demand still far above tolerance ends the
	# save (GDD 3). The player answered the event first — the city is lost
	# because it was left in the red for many turns, not because of this click.
	if fatal:
		state.game_over = true
		state.outcome = GameState.OUTCOME_LOST_CATASTROPHE
		events.append({"type": "catastrophe_struck", "id": event.id, "demand": event.demand})
		events.append(_game_over_event())
		return events
	events.append_array(_draw_phase())
	return events


## Plays a card from hand (phase 3 step 2). Interactions are NOT checked here —
## the interaction check is its own step at end_turn (GDD 3).
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
		var dev: DevelopmentState = DevelopmentState.from_card(card, state.turn_number)
		state.developments.append(dev)
		# The printed values move the meters once, here; their permanent half is
		# read off the standing development by the pipeline (GDD 4.0).
		DemandEngine.apply_printed_on_play(state, dev, events)
	else:
		state.consumed_cards.append(card.id)  # uniqueness ledger: actions never return
	EffectApplier.apply_instant(card.effects, state, events)
	PopulationEngine.recompute_level(state, db, events)
	EffectApplier.inject_main_filtered(card.inject_main, state, events)
	if not card.inject_events.is_empty():
		DeckManager.shuffle_into(state.event_deck, card.inject_events, state.rng, "events")
		events.append({"type": "cards_injected", "deck": "event", "count": card.inject_events.size()})
	return {"ok": true, "reason": "", "events": events}


## Discards cards from hand to get back under the hand limit (GDD 4.1).
## Discarded cards enter the uniqueness ledger and never return.
func discard_cards(card_ids: Array[String]) -> Dictionary:
	if state.game_over:
		return _refuse("game is over")
	if state.pending_event != "":
		return _refuse("an event is awaiting resolution")
	if state.transition_pending:
		return _refuse("an age transition is pending")
	# Validate the whole set before touching the hand: a partly-applied discard
	# would leave the player unable to tell what they still hold.
	var remaining: Array[String] = state.hand.duplicate()
	for card_id: String in card_ids:
		if card_id not in remaining:
			return _refuse("card is not in hand: " + card_id)
		remaining.erase(card_id)
	var events: Array[Dictionary] = []
	var discarded: Array[String] = []
	for card_id: String in card_ids:
		state.hand.erase(card_id)
		if card_id not in state.consumed_cards:
			state.consumed_cards.append(card_id)
		discarded.append(card_id)
	if not discarded.is_empty():
		events.append({"type": "cards_discarded", "cards": discarded})
	return {"ok": true, "reason": "", "events": events}


## Closes phase 3: hand-limit check, then the interaction check, then the
## age-boundary test. Over the hand limit the turn does NOT advance — the
## caller must discard down first (GDD 4.1).
func end_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.game_over or state.pending_event != "" or state.transition_pending:
		return events
	var overflow: int = DeckManager.hand_overflow(state, db)
	if overflow > 0:
		events.append({
			"type": "discard_required",
			"count": overflow,
			"limit": DeckManager.hand_limit(state, db),
		})
		return events
	events.append_array(InteractionEngine.check(state, db))
	events.append({
		"type": "turn_ended",
		"year": state.year,
		"population_count": state.population_count,
		"population_level": state.population_level,
	})
	var age: AgeDef = db.get_age(state.age_id)
	if state.year >= age.year_end:
		if age.next_age != "" and db.ages.has(age.next_age):
			# Not the final age: suspend for the transition phase (GDD 4.8).
			# The controller drives AgeTransition.apply next.
			state.transition_pending = true
			state.pending_transition_to = age.next_age
			events.append({"type": "age_ended", "from": age.id, "to": age.next_age})
		else:
			state.game_over = true
			state.outcome = GameState.OUTCOME_WON
			events.append({"type": "age_completed"})
			events.append(_game_over_event())
	return events


## Activates an unlocked policy in a free slot. Swapping is not supported
## in the MVP.
func adopt_policy(policy_id: String) -> Dictionary:
	if not PolicySystem.ENABLED:
		return {"ok": false, "reason": "policies are temporarily disabled"}
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

## Suspends the turn on an event, flagging a near-miss if a standing
## development cancels its hazard (GDD 4.4).
func _fire_event(event_id: String) -> Dictionary:
	state.pending_event = event_id
	if event_id not in state.seen_events:
		state.seen_events.append(event_id)
	var fired: Dictionary = {"type": "event_fired", "id": event_id}
	var cancelled_by: String = EventMatcher.hazard_cancelled_by(
		state, db, db.get_event(event_id))
	if cancelled_by != "":
		# The player learns it is a near-miss before choosing, which is the
		# point of protection being a printed, plannable hazard type.
		fired["hazard_cancelled_by"] = cancelled_by
	return fired


## Phase 3 step 1: draw the age's fixed hand size. Card capacity grows through
## the hand limit instead, so a bigger engine means more room to hold, not more
## forced decisions per turn (GDD 4.1).
func _draw_phase() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var age: AgeDef = db.get_age(state.age_id)
	var drawn: Array[String] = []
	for i: int in age.base_draw:
		if state.main_deck.is_empty():
			break
		var card_id: String = DeckManager.draw_top(state.main_deck)
		state.hand.append(card_id)
		drawn.append(card_id)
	events.append({"type": "cards_drawn", "cards": drawn})
	return events


func _game_over_event() -> Dictionary:
	return {"type": "game_over", "outcome": state.outcome, "score": Scoring.score(state, db)}


func _refuse(reason: String) -> Dictionary:
	var empty: Array[Dictionary] = []
	return {"ok": false, "reason": reason, "events": empty}
