class_name EffectApplier
extends RefCounted

## Applies INSTANT effects (card play, event option, interaction activation)
## to a GameState. Passive effects are never "applied" — they are read by
## ModifierPipeline.collect each time. Emits domain events into events_out.


static func apply_instant(effects: Array[EffectDef], state: GameState, events_out: Array[Dictionary]) -> void:
	for effect: EffectDef in effects:
		if not effect.is_instant():
			continue
		match effect.type:
			"resource_delta":
				_apply_resource_delta(effect, state)
			"demand_delta":
				DemandEngine.apply_delta(state, effect.demand, effect.amount_int(), events_out)
			"unlock_policy":
				if effect.id not in state.unlocked_policies:
					state.unlocked_policies.append(effect.id)
					events_out.append({"type": "policy_unlocked", "id": effect.id})
			"inject_main":
				inject_main_filtered(effect.cards, state, events_out)
			"inject_events":
				if not effect.events.is_empty():
					DeckManager.shuffle_into(state.event_deck, effect.events, state.rng, "events")
					events_out.append({"type": "cards_injected", "deck": "event", "count": effect.events.size()})
			"remove_events":
				for event_id: String in effect.events:
					while event_id in state.event_deck:
						state.event_deck.erase(event_id)


## Injects card ids into the main deck under the uniqueness rule
## (content-schema.md): any id that already exists anywhere in the save is
## silently skipped. Emits cards_injected with the actually-injected count;
## emits nothing when everything was skipped. Event-deck injection is NOT
## filtered — events are not unique.
static func inject_main_filtered(card_ids: Array[String], state: GameState, events_out: Array[Dictionary]) -> void:
	var to_inject: Array[String] = []
	for card_id: String in card_ids:
		if state.card_exists_anywhere(card_id) or card_id in to_inject:
			continue
		to_inject.append(card_id)
	if to_inject.is_empty():
		return
	DeckManager.shuffle_into(state.main_deck, to_inject, state.rng, "deck")
	events_out.append({"type": "cards_injected", "deck": "main", "count": to_inject.size()})


## The population LEVEL is never written directly — it is derived from the
## count, so an event that takes people away (a plague, a levy) changes the
## count and lets PopulationEngine work out what that means.
static func _apply_resource_delta(effect: EffectDef, state: GameState) -> void:
	match effect.resource:
		"population_count":
			state.population_count += effect.amount_int()
		"budget":
			state.current_budget += effect.amount_int()
		_:
			push_error("resource_delta: unknown resource \"%s\"" % effect.resource)
	state.clamp_resources()
