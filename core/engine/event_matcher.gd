class_name EventMatcher
extends RefCounted

## Event draw per GDD 4.4: draw from the top of the event deck up to 5 times;
## the first event whose trigger matches the current city state fires and is
## removed from the deck. Non-matching draws are set aside and returned to
## the BOTTOM of the deck in drawn order after matching concludes.

const MAX_DRAWS: int = 5


## Returns the matched event id, or "" if no match within MAX_DRAWS.
static func draw_matching(state: GameState, db: ContentDB) -> String:
	var set_aside: Array[String] = []
	var matched: String = ""
	for i: int in MAX_DRAWS:
		if state.event_deck.is_empty():
			break
		var event_id: String = DeckManager.draw_top(state.event_deck)
		var event: EventDef = db.get_event(event_id)
		if event != null and event.matches(state):
			matched = event_id
			break
		set_aside.append(event_id)
	for event_id: String in set_aside:
		DeckManager.to_bottom(state.event_deck, event_id)
	return matched
