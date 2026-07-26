class_name EventMatcher
extends RefCounted

## Event draw per GDD 4.4 (amended 2026-07-26): draw from the top of the event
## deck until a trigger matches — there is NO draw limit. A full pass with no
## match means no event this turn. Non-matching draws are set aside and
## returned to the BOTTOM of the deck in drawn order after matching concludes.
##
## Also the home of the two ways a standing development changes how an event
## resolves: hazard cancellation (type-based) and conditional options
## (card-specific, see EventOptionDef.is_available).


## Returns the matched event id, or "" if nothing in the deck matches. The
## loop is bounded by the deck size — each iteration removes one card.
static func draw_matching(state: GameState, db: ContentDB) -> String:
	var set_aside: Array[String] = []
	var matched: String = ""
	while not state.event_deck.is_empty():
		var event_id: String = DeckManager.draw_top(state.event_deck)
		var event: EventDef = db.get_event(event_id)
		if event != null and event.matches(state, db):
			matched = event_id
			break
		set_aside.append(event_id)
	for event_id: String in set_aside:
		DeckManager.to_bottom(state.event_deck, event_id)
	return matched


## The card id of the first standing development that cancels this event's
## hazard type, or "" if the hazard lands (GDD 4.4). Events with no hazard
## type can never be cancelled.
static func hazard_cancelled_by(state: GameState, db: ContentDB, event: EventDef) -> String:
	if event == null or event.hazard == "":
		return ""
	for dev: DevelopmentState in state.developments:
		var card: CardDef = db.get_card(dev.card_id)
		if card != null and event.hazard in card.cancels:
			return dev.card_id
	return ""


## The subset of an option's effects that actually applies. With the hazard
## cancelled, harmful effects are dropped; everything else still resolves.
static func effects_after_cancellation(option: EventOptionDef, cancelled: bool) -> Array[EffectDef]:
	if not cancelled:
		return option.effects
	var kept: Array[EffectDef] = []
	for effect: EffectDef in option.effects:
		if not effect.is_harmful():
			kept.append(effect)
	return kept
