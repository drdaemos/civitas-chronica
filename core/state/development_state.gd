class_name DevelopmentState
extends RefCounted

## A development in play. Tags AND effects are copied from the CardDef at play
## time so later ages can reinterpret them (GDD 4.6) without touching content
## files — after an age transition they may no longer match the printed card.

var card_id: String = ""
var tags: Array[String] = []
var effects: Array[EffectDef] = []  # live effects (may differ from CardDef)
var turn_played: int = 0
var ages_survived: int = 0
var adapted: bool = false


static func from_dict(d: Dictionary) -> DevelopmentState:
	var dev := DevelopmentState.new()
	dev.card_id = String(d.get("card_id", ""))
	dev.tags.assign(d.get("tags", []))
	for effect_dict: Variant in d.get("effects", []):
		dev.effects.append(EffectDef.from_dict(effect_dict))
	dev.turn_played = int(d.get("turn_played", 0))
	dev.ages_survived = int(d.get("ages_survived", 0))
	dev.adapted = bool(d.get("adapted", false))
	return dev


func to_dict() -> Dictionary:
	var effect_dicts: Array = []
	for effect: EffectDef in effects:
		effect_dicts.append(effect.to_dict())
	return {
		"card_id": card_id,
		"tags": Array(tags),
		"effects": effect_dicts,
		"turn_played": turn_played,
		"ages_survived": ages_survived,
		"adapted": adapted,
	}
