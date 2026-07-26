class_name TransitionReport
extends RefCounted

## What an age transition did (GDD 4.8). The transition asks the player for
## nothing, so this is the whole player-facing output: the screen that tells
## them their walls became ruins and which interaction they just lost.
##
## `events` carries the same domain-event stream every other engine call
## returns, for the log; the structured fields are for the report screen.

var from_age: String = ""
var to_age: String = ""
var events: Array[Dictionary] = []

## [{"from": card_id, "to": card_id}] in city play order (GDD 4.6).
var supersessions: Array[Dictionary] = []
var interactions_gained: Array[String] = []
var interactions_lost: Array[String] = []
var hand_discarded: int = 0
var base_budget: int = 0
var hand_limit: int = 0

## The demand the new age brings in, and the meter it starts on — counted from
## the standing city, so it is frequently not 0 (GDD 4.0 Age activation).
var activated_demand: String = ""
var activated_demand_value: int = 0
## One row per active demand after the transition:
## {"demand": String, "value": int, "growth": int, "threshold": int}
var demand_rows: Array[Dictionary] = []


func has_changes() -> bool:
	return not supersessions.is_empty() or not interactions_gained.is_empty() \
		or not interactions_lost.is_empty() or activated_demand != ""
