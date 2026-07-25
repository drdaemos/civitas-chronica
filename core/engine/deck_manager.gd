class_name DeckManager
extends RefCounted

## Pure deck operations. Index 0 is the top of a deck. All shuffling flows
## through RngService named streams (constitution rule 5).


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
