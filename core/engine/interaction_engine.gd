class_name InteractionEngine
extends RefCounted

## The interaction check phase (GDD 4.2). Activates every interaction whose
## threshold is satisfied, applies its instant effects once, and cascades —
## activating one interaction can satisfy another's threshold.


static func check(state: GameState, db: ContentDB) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var changed: bool = true
	while changed:
		changed = false
		for interaction_id: String in db.interactions:
			if interaction_id in state.active_interactions:
				continue
			var interaction: InteractionDef = db.interactions[interaction_id]
			if interaction.threshold == null or not interaction.threshold.evaluate(state):
				continue
			state.active_interactions.append(interaction_id)
			var first_discovery: bool = interaction_id not in state.seen_interactions
			if first_discovery:
				state.seen_interactions.append(interaction_id)
			events.append({
				"type": "interaction_activated",
				"id": interaction_id,
				"first_discovery": first_discovery,
			})
			# Instant effects fire at most once per save (interactions_fired
			# ledger) — re-activation after an age transition is safe.
			if interaction_id not in state.interactions_fired:
				state.interactions_fired.append(interaction_id)
				EffectApplier.apply_instant(interaction.effects, state, events)
			changed = true
	return events
