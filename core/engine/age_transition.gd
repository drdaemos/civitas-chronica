class_name AgeTransition
extends RefCounted

## The age-transition phase (GDD 4.8, content-schema.md "superseded_by").
## Entered when TurnEngine sets state.transition_pending at an age boundary.
##
## Amended 2026-07-26: the transition takes NO player input. Preserve / Adapt /
## Demolish is gone; a development whose card names a successor for the new age
## is replaced by it automatically. apply() is therefore a single call and its
## TransitionReport is a report, not a decision screen. apply() does NOT start
## the new age's first turn — the controller calls TurnEngine.start_turn()
## afterwards.


## Applies the pending transition and returns what it did. Returns an empty
## report (from_age == "") if no transition is pending.
static func apply(state: GameState, db: ContentDB) -> TransitionReport:
	var report := TransitionReport.new()
	if not state.transition_pending:
		return report
	var old_age_id: String = state.age_id
	var target: String = state.pending_transition_to
	report.from_age = old_age_id
	report.to_age = target
	var events: Array[Dictionary] = report.events

	# 1. Hand discard (GDD 4.8 step 1): discarded ids enter the uniqueness
	# ledger so they can never be re-injected.
	report.hand_discarded = state.hand.size()
	for card_id: String in state.hand:
		if card_id not in state.consumed_cards:
			state.consumed_cards.append(card_id)
	state.hand.clear()

	# 2. Supersession (GDD 4.6): every development whose card names a successor
	# for this age is replaced by it, in place, keeping its history. The old
	# card joins the uniqueness ledger; it has left the city for good.
	# A successor may itself be superseded later, but not within one transition.
	var pending_main: Array[String] = []
	var pending_events: Array[String] = []
	for dev: DevelopmentState in state.developments:
		var card: CardDef = db.get_card(dev.card_id)
		if card == null:
			continue
		var successor_id: String = card.successor_for(target)
		if successor_id == "":
			continue
		var successor: CardDef = db.get_card(successor_id)
		if successor == null:
			# Dangling successor: the validator rejects this statically, so a
			# broken save keeps the old form rather than losing the structure.
			push_error("AgeTransition: unknown successor \"%s\" for \"%s\"" % [
				successor_id, dev.card_id,
			])
			continue
		var predecessor_id: String = dev.card_id
		# Tags, printed demands and effects all become the successor's: a wall
		# becoming ruins stops mitigating Security, and the player has to
		# replace that from somewhere (GDD 4.6).
		dev.take_form_of(successor)
		dev.superseded_count += 1
		if predecessor_id not in state.consumed_cards:
			state.consumed_cards.append(predecessor_id)
		pending_main.append_array(successor.inject_main)
		pending_events.append_array(successor.inject_events)
		report.supersessions.append({"from": predecessor_id, "to": successor.id})
		events.append({
			"type": "development_superseded", "from": predecessor_id, "to": successor.id,
		})
	for dev: DevelopmentState in state.developments:
		dev.ages_survived += 1

	# 3. Interaction recalculation (GDD 4.8 step 4): supersession may drop the
	# city below a threshold — deactivation is possible here. New activations
	# run through the normal check; instant effects stay gated by
	# state.interactions_fired.
	var still_active: Array[String] = []
	for interaction_id: String in state.active_interactions:
		var interaction: InteractionDef = db.get_interaction(interaction_id)
		if interaction != null and interaction.threshold != null \
				and interaction.threshold.evaluate(state, db):
			still_active.append(interaction_id)
		else:
			report.interactions_lost.append(interaction_id)
			events.append({"type": "interaction_deactivated", "id": interaction_id})
	state.active_interactions = still_active
	var check_events: Array[Dictionary] = InteractionEngine.check(state, db)
	events.append_array(check_events)
	for ev: Dictionary in check_events:
		if String(ev.get("type", "")) == "interaction_activated":
			report.interactions_gained.append(String(ev.get("id", "")))

	# 4. Age switch: population and city carry forward; capacity, slots, and
	# the clock take the new age's values (GDD 4.8 step 6/7).
	state.completed_ages.append(old_age_id)
	state.age_id = target
	var new_age: AgeDef = db.get_age(target)
	state.base_budget = new_age.base_budget
	state.policy_slots = maxi(state.policy_slots, new_age.policy_slots)
	state.year = new_age.year_start
	state.turn_number = 0

	# 4b. Demand activation (GDD 4.8 step 6): the new demand's meter is counted
	# from the standing city AFTER supersession. A city that spent two hundred
	# years building tanneries is measured against a standard that did not
	# exist when it was built — and may start the age already in the red.
	if new_age.activates_demand != "":
		var starting_value: int = DemandEngine.activate(
			state, db, new_age.activates_demand, events)
		report.activated_demand = new_age.activates_demand
		report.activated_demand_value = starting_value

	# 5. Deck generation (GDD 4.8 step 5): the old main deck is discarded; the
	# new pool is filtered by the uniqueness rule. Successor injections are
	# applied AFTER the rebuild, or the rebuild would discard them.
	state.main_deck.clear()
	var new_deck: Array[String] = []
	for card_id: String in new_age.base_deck:
		if not state.card_exists_anywhere(card_id) and card_id not in new_deck:
			new_deck.append(card_id)
	state.main_deck.assign(new_deck)
	state.rng.shuffle("deck", state.main_deck)
	state.event_deck = new_age.base_events.duplicate()
	state.rng.shuffle("events", state.event_deck)
	EffectApplier.inject_main_filtered(pending_main, state, events)
	if not pending_events.is_empty():
		DeckManager.shuffle_into(state.event_deck, pending_events, state.rng, "events")
		events.append({
			"type": "cards_injected", "deck": "event", "count": pending_events.size(),
		})

	# 6. Policies carry forward unchanged.
	# TODO: policy evolution choices (GDD 4.8 step 3) — the one decision the
	# transition still owes the player; deferred post-MVP.
	for policy_id: String in db.policies:
		var policy: PolicyDef = db.policies[policy_id]
		if policy.is_unlocked_from_start() and policy_id not in state.unlocked_policies:
			state.unlocked_policies.append(policy_id)

	# 7. Wrap up.
	state.clamp_resources()
	state.transition_pending = false
	state.pending_transition_to = ""
	report.base_budget = state.base_budget
	report.hand_limit = DeckManager.hand_limit(state, db)
	# Every demand's growth step is recalculated from the post-supersession city
	# — this is the number the player most needs off this screen.
	var pipeline: ModifierPipeline = ModifierPipeline.collect(state, db)
	for demand_id: String in state.active_demands:
		report.demand_rows.append({
			"demand": demand_id,
			"value": state.demand_value(demand_id),
			"growth": pipeline.demand_growth_step(demand_id),
			"threshold": db.rules.threshold_for(demand_id),
		})
	events.append({"type": "age_transitioned", "from": old_age_id, "to": target})
	return report
