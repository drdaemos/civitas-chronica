class_name DevelopmentState
extends RefCounted

## A development in play. Tags, printed demand values AND effects are copied
## from the CardDef at play time. At an age boundary a development may be
## SUPERSEDED (GDD 4.6): all three are replaced by the successor card's, in
## place, so the same structure keeps its turn_played and ages_survived history.

var card_id: String = ""
var tags: Array[String] = []
var demands: Dictionary = {}        # demand id String -> printed int (GDD 4.0)
var effects: Array[EffectDef] = []  # live effects (from the current card_id)
var turn_played: int = 0
var ages_survived: int = 0
var superseded_count: int = 0  # how many times this structure changed form


## Builds the in-play record for a card. The copies are what make demand values
## reversible on removal and re-readable when a demand activates ages later.
static func from_card(card: CardDef, turn: int) -> DevelopmentState:
	var dev := DevelopmentState.new()
	dev.card_id = card.id
	dev.take_form_of(card)
	dev.turn_played = turn
	return dev


## Adopts another card's tags, printed demands and effects — used on play and
## on supersession, which are the only two ways a structure gets its form.
func take_form_of(card: CardDef) -> void:
	card_id = card.id
	tags = card.tags.duplicate()
	demands = card.demands.duplicate()
	effects = card.effects.duplicate()  # EffectDefs are immutable; refs shared


## Printed value for one demand, 0 if this development does not touch it.
func printed_demand(demand_id: String) -> int:
	return int(demands.get(demand_id, 0))


static func from_dict(d: Dictionary) -> DevelopmentState:
	var dev := DevelopmentState.new()
	dev.card_id = String(d.get("card_id", ""))
	dev.tags.assign(d.get("tags", []))
	var saved: Dictionary = d.get("demands", {})
	for demand_id: String in saved:
		dev.demands[demand_id] = int(saved[demand_id])
	for effect_dict: Variant in d.get("effects", []):
		dev.effects.append(EffectDef.from_dict(effect_dict))
	dev.turn_played = int(d.get("turn_played", 0))
	dev.ages_survived = int(d.get("ages_survived", 0))
	dev.superseded_count = int(d.get("superseded_count", 0))
	return dev


func to_dict() -> Dictionary:
	var effect_dicts: Array = []
	for effect: EffectDef in effects:
		effect_dicts.append(effect.to_dict())
	return {
		"card_id": card_id,
		"tags": Array(tags),
		"demands": demands.duplicate(),
		"effects": effect_dicts,
		"turn_played": turn_played,
		"ages_survived": ages_survived,
		"superseded_count": superseded_count,
	}
