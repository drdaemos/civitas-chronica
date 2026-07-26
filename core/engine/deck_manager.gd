class_name DeckManager
extends RefCounted

## Pure deck operations. Index 0 is the top of a deck. All shuffling flows
## through RngService named streams (constitution rule 5).

## Base hand capacity (GDD 4.1). Raised only by developments carrying
## `hand_limit_bonus` — the draw size is never the growth lever.
const BASE_HAND_LIMIT: int = 5


## Removes and returns the top card id, or "" if the deck is empty.
static func draw_top(deck: Array[String]) -> String:
	if deck.is_empty():
		return ""
	return String(deck.pop_front())


## Appends new_cards, then shuffles the entire deck with the named stream.
static func shuffle_into(deck: Array[String], new_cards: Array[String], rng: RngService, stream: String) -> void:
	deck.append_array(new_cards)
	rng.shuffle(stream, deck)


## Places a card id at the bottom of the deck.
static func to_bottom(deck: Array[String], card_id: String) -> void:
	deck.append(card_id)


## Current hand capacity: the base limit plus the `hand_limit_bonus` of every
## standing development (GDD 4.1). Read from the development's CURRENT card,
## so a supersession can hand the bonus back.
static func hand_limit(state: GameState, db: ContentDB) -> int:
	var limit: int = BASE_HAND_LIMIT
	for dev: DevelopmentState in state.developments:
		var card: CardDef = db.get_card(dev.card_id)
		if card != null:
			limit += card.hand_limit_bonus
	return maxi(limit, 0)


## How many cards must be discarded before the turn can end (0 = none).
static func hand_overflow(state: GameState, db: ContentDB) -> int:
	return maxi(state.hand.size() - hand_limit(state, db), 0)
