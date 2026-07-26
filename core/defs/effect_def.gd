class_name EffectDef
extends RefCounted

## One effect entry. Instant effects fire once (card play, event option,
## interaction activation); passive effects live while their source is active
## and are collected by the ModifierPipeline. See docs/content-schema.md.
##
## Demands are moved two different ways on purpose (GDD 4.0): `demand_delta` is
## a one-time nudge to the meter (events and action cards), while
## `demand_modifier` / `demand_modifier_per_tag` feed the per-turn growth step
## (interactions and policies). A development's own printed values are not
## effects at all — see CardDef.demands.

const INSTANT_TYPES: Array[String] = [
	"resource_delta", "demand_delta", "unlock_policy",
	"inject_main", "inject_events", "remove_events",
]
## Note: there is no draw-size modifier. Card capacity grows through the hand
## limit (CardDef.hand_limit_bonus), never through the draw (GDD 4.1).
const PASSIVE_TYPES: Array[String] = [
	"income", "demand_modifier", "demand_modifier_per_tag",
	"cost_modifier", "pop_growth_mult",
]

var type: String = ""
var resource: String = ""
var demand: String = ""         # demand_delta / demand_modifier* subject
var amount: float = 0.0
var tag: String = ""            # cost_modifier scope ("" = all cards); demand_modifier_per_tag subject
var id: String = ""             # unlock_policy target
var min_cost: int = -1          # cost_modifier floor; -1 = none
var cards: Array[String] = []   # inject_main payload
var events: Array[String] = []  # inject_events / remove_events payload


static func from_dict(d: Dictionary) -> EffectDef:
	var e := EffectDef.new()
	e.type = String(d.get("type", ""))
	e.resource = String(d.get("resource", ""))
	e.demand = String(d.get("demand", ""))
	e.amount = float(d.get("amount", 0.0))
	e.tag = String(d.get("tag", ""))
	e.id = String(d.get("id", ""))
	e.min_cost = int(d.get("min_cost", -1))
	e.cards.assign(d.get("cards", []))
	e.events.assign(d.get("events", []))
	return e


## Inverse of from_dict. Only non-default fields are written, so
## from_dict(to_dict()) roundtrips equivalently and re-serialization is stable.
func to_dict() -> Dictionary:
	var d: Dictionary = {"type": type}
	if resource != "":
		d["resource"] = resource
	if demand != "":
		d["demand"] = demand
	if amount != 0.0:
		d["amount"] = amount
	if tag != "":
		d["tag"] = tag
	if id != "":
		d["id"] = id
	if min_cost != -1:
		d["min_cost"] = min_cost
	if not cards.is_empty():
		d["cards"] = Array(cards)
	if not events.is_empty():
		d["events"] = Array(events)
	return d


func is_instant() -> bool:
	return type in INSTANT_TYPES


func is_passive() -> bool:
	return type in PASSIVE_TYPES


func amount_int() -> int:
	return int(round(amount))


## True for effects that damage the city. Used by hazard cancellation (GDD
## 4.4): when a standing development cancels an event's hazard type, the
## event's harmful effects are dropped and everything else still applies.
## Deliberately narrow — only a resource loss or a demand increase counts,
## because injections and unlocks can cut either way.
func is_harmful() -> bool:
	if type == "resource_delta":
		return amount < 0.0
	if type == "demand_delta":
		return amount > 0.0  # demands are pressure: up is worse
	return false


## Collects referenced content IDs into refs = {"policies": [], "cards": [], "events": []}.
func collect_refs(refs: Dictionary) -> void:
	match type:
		"unlock_policy":
			(refs["policies"] as Array).append(id)
		"inject_main":
			(refs["cards"] as Array).append_array(cards)
		"inject_events", "remove_events":
			(refs["events"] as Array).append_array(events)
