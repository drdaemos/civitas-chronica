class_name AgeTransition
extends RefCounted

## The age-transition phase (GDD 4.8, content-schema.md "age_variants").
## Entered when TurnEngine sets state.transition_pending at an age boundary.
## The UI presents decisions() and submits the player's choices to apply();
## apply() does NOT start the new age's first turn — the controller calls
## TurnEngine.start_turn() afterwards.

const CHOICE_PRESERVE: String = "preserve"
const CHOICE_ADAPT: String = "adapt"
const CHOICE_DEMOLISH: String = "demolish"

const DEFAULT_DEMOLISH_APPROVAL: int = -3


## One decision entry per development, in play order:
## {"card_id": String, "name": String, "current_tags": Array[String],
##  "preserve": {"tags": [...]},          # resulting tags if preserved
##  "adapt": null | {"cost": int, "tags": [...]},
##  "demolish": {"approval": int}}
## The target age is state.pending_transition_to.
static func decisions(state: GameState, db: ContentDB) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var target: String = state.pending_transition_to
	for dev: DevelopmentState in state.developments:
		var card: CardDef = db.get_card(dev.card_id)
		var variant: AgeVariantDef = _variant_for(card, target)
		var preserve_tags: Array[String] = dev.tags.duplicate()
		if variant != null and variant.has_preserved:
			preserve_tags = variant.preserved_tags.duplicate()
		var adapt: Variant = null
		if variant != null and variant.has_adapted:
			adapt = {"cost": variant.adapt_cost, "tags": variant.adapted_tags.duplicate()}
		var demolish_approval: int = DEFAULT_DEMOLISH_APPROVAL
		if variant != null:
			demolish_approval = variant.demolish_approval
		result.append({
			"card_id": dev.card_id,
			"name": card.display_name if card != null else dev.card_id,
			"current_tags": dev.tags.duplicate(),
			"preserve": {"tags": preserve_tags},
			"adapt": adapt,
			"demolish": {"approval": demolish_approval},
		})
	return result


## Applies the transition. choices maps card_id -> "preserve"|"adapt"|
## "demolish"; a missing entry (or an invalid "adapt" without a variant)
## means "preserve". Returns the emitted domain events; [] if no transition
## is pending.
static func apply(state: GameState, db: ContentDB, choices: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not state.transition_pending:
		return events
	var old_age_id: String = state.age_id
	var target: String = state.pending_transition_to

	# 1. Hand discard (GDD 4.8 step 1): discarded ids enter the uniqueness
	# ledger so they can never be re-injected.
	for card_id: String in state.hand:
		if card_id not in state.consumed_cards:
			state.consumed_cards.append(card_id)
	state.hand.clear()

	# 2. Transition decisions per development (GDD 4.6).
	var survivors: Array[DevelopmentState] = []
	for dev: DevelopmentState in state.developments:
		var choice: String = String(choices.get(dev.card_id, CHOICE_PRESERVE))
		var card: CardDef = db.get_card(dev.card_id)
		var variant: AgeVariantDef = _variant_for(card, target)
		if choice == CHOICE_ADAPT and (variant == null or not variant.has_adapted):
			choice = CHOICE_PRESERVE  # invalid adapt falls back to preserve
		match choice:
			CHOICE_DEMOLISH:
				var approval_delta: int = DEFAULT_DEMOLISH_APPROVAL
				if variant != null:
					approval_delta = variant.demolish_approval
				state.approval += approval_delta
				if dev.card_id not in state.consumed_cards:
					state.consumed_cards.append(dev.card_id)
				events.append({"type": "development_demolished", "card": dev.card_id})
			CHOICE_ADAPT:
				dev.tags = variant.adapted_tags.duplicate()
				dev.effects = variant.adapted_effects.duplicate()
				dev.adapted = true
				dev.ages_survived += 1
				# Billed on the new age's first turn (event-billing mechanism).
				state.pending_bill += variant.adapt_cost
				survivors.append(dev)
				events.append({"type": "development_adapted", "card": dev.card_id})
			_:
				if variant != null and variant.has_preserved:
					dev.tags = variant.preserved_tags.duplicate()
					dev.effects = variant.preserved_effects.duplicate()
				dev.ages_survived += 1
				survivors.append(dev)
				events.append({"type": "development_preserved", "card": dev.card_id})
	state.developments = survivors

	# 3. Interaction recalculation (GDD 4.8 step 4): reinterpreted tags may
	# drop below thresholds — deactivation is possible here. New activations
	# run through the normal check; instant effects stay gated by
	# state.interactions_fired.
	var still_active: Array[String] = []
	for interaction_id: String in state.active_interactions:
		var interaction: InteractionDef = db.get_interaction(interaction_id)
		if interaction != null and interaction.threshold != null \
				and interaction.threshold.evaluate(state):
			still_active.append(interaction_id)
		else:
			events.append({"type": "interaction_deactivated", "id": interaction_id})
	state.active_interactions = still_active
	events.append_array(InteractionEngine.check(state, db))

	# 4. Age switch: population and city carry forward; capacity, slots, and
	# the clock take the new age's values (GDD 4.8 step 6/7).
	state.completed_ages.append(old_age_id)
	state.age_id = target
	var new_age: AgeDef = db.get_age(target)
	state.base_budget = new_age.base_budget
	state.policy_slots = maxi(state.policy_slots, new_age.policy_slots)
	state.year = new_age.year_start
	state.turn_number = 0

	# 5. Deck generation (GDD 4.8 step 5): the old main deck is discarded;
	# the new pool is filtered by the uniqueness rule.
	state.main_deck.clear()
	var new_deck: Array[String] = []
	for card_id: String in new_age.base_deck:
		if not state.card_exists_anywhere(card_id) and card_id not in new_deck:
			new_deck.append(card_id)
	state.main_deck.assign(new_deck)
	state.rng.shuffle("deck", state.main_deck)
	state.event_deck = new_age.base_events.duplicate()
	state.rng.shuffle("events", state.event_deck)

	# 6. Policies carry forward unchanged.
	# TODO: policy evolution choices (GDD 4.8 step 3) — deferred post-MVP.
	for policy_id: String in db.policies:
		var policy: PolicyDef = db.policies[policy_id]
		if policy.is_unlocked_from_start() and policy_id not in state.unlocked_policies:
			state.unlocked_policies.append(policy_id)

	# 7. Wrap up.
	state.clamp_resources()
	state.transition_pending = false
	state.pending_transition_to = ""
	events.append({"type": "age_transitioned", "from": old_age_id, "to": target})
	return events


static func _variant_for(card: CardDef, target_age_id: String) -> AgeVariantDef:
	if card == null or not card.age_variants.has(target_age_id):
		return null
	return card.age_variants[target_age_id]
