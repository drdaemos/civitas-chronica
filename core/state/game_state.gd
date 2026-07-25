class_name GameState
extends RefCounted

## The entire save-relevant state of a running game. Pure data + invariant
## helpers; all rules live in core/engine. Serializes to a Dictionary for
## the save system (snapshot taken at TURN_START only — see TDD 4.2).

const OUTCOME_NONE: String = ""
const OUTCOME_WON: String = "won"
const OUTCOME_LOST_APPROVAL: String = "lost_approval"
const OUTCOME_LOST_DEBT: String = "lost_debt"

const APPROVAL_MAX: int = 100
const MIGRATION_MAX: int = 10

# --- progression ---
var age_id: String = ""
var turn_number: int = 0
var year: int = 0
var completed_ages: Array[String] = []
var transition_pending: bool = false   # age ended; awaiting AgeTransition.apply
var pending_transition_to: String = ""  # target age id while transition_pending

# --- resources ---
var population: int = 0
var approval: int = 0
var migration_appeal: int = 0
var base_budget: int = 0        # base capacity from the age def
var current_budget: int = 0     # spendable this turn (capacity + income - bill)
var pending_bill: int = 0       # event billing: charged at next TURN_START
var policy_slots: int = 1

# --- city ---
var developments: Array[DevelopmentState] = []
var active_interactions: Array[String] = []
var unlocked_policies: Array[String] = []
var active_policies: Array[String] = []

# --- decks & hand (card/event IDs) ---
var main_deck: Array[String] = []
var event_deck: Array[String] = []
var hand: Array[String] = []
var pending_event: String = ""      # event awaiting a player choice, "" if none
var consumed_cards: Array[String] = []  # uniqueness ledger: played actions, discards, demolitions

# --- interactions whose INSTANT effects already fired this save ---
var interactions_fired: Array[String] = []

# --- lose-condition counters (grace periods per GDD design intent) ---
var low_approval_turns: int = 0
var debt_turns: int = 0
var game_over: bool = false
var outcome: String = OUTCOME_NONE

# --- per-save discovery (account-level copy lives in the profile) ---
var seen_interactions: Array[String] = []
var seen_events: Array[String] = []

var rng: RngService = null


func tag_count(tag: String) -> int:
	var count: int = 0
	for dev: DevelopmentState in developments:
		if tag in dev.tags:
			count += 1
	return count


func has_development(card_id: String) -> bool:
	for dev: DevelopmentState in developments:
		if dev.card_id == card_id:
			return true
	return false


## Card uniqueness (content-schema.md): true if the card exists in any zone —
## main deck, hand, developments, or the consumed ledger.
func card_exists_anywhere(card_id: String) -> bool:
	return card_id in main_deck or card_id in hand \
		or has_development(card_id) or card_id in consumed_cards


func development_ids() -> Array[String]:
	var ids: Array[String] = []
	for dev: DevelopmentState in developments:
		ids.append(dev.card_id)
	return ids


## Resource accessor used by ConditionDef. "budget" means spendable budget.
func get_resource(resource_name: String) -> int:
	match resource_name:
		"population":
			return population
		"approval":
			return approval
		"migration_appeal":
			return migration_appeal
		"budget":
			return current_budget
		_:
			push_error("Unknown resource: " + resource_name)
			return 0


func clamp_resources() -> void:
	approval = clampi(approval, 0, APPROVAL_MAX)
	migration_appeal = clampi(migration_appeal, 0, MIGRATION_MAX)
	population = maxi(population, 0)


func to_dict() -> Dictionary:
	var devs: Array = []
	for dev: DevelopmentState in developments:
		devs.append(dev.to_dict())
	return {
		"age_id": age_id,
		"turn_number": turn_number,
		"year": year,
		"completed_ages": Array(completed_ages),
		"transition_pending": transition_pending,
		"pending_transition_to": pending_transition_to,
		"population": population,
		"approval": approval,
		"migration_appeal": migration_appeal,
		"base_budget": base_budget,
		"current_budget": current_budget,
		"pending_bill": pending_bill,
		"policy_slots": policy_slots,
		"developments": devs,
		"active_interactions": Array(active_interactions),
		"unlocked_policies": Array(unlocked_policies),
		"active_policies": Array(active_policies),
		"main_deck": Array(main_deck),
		"event_deck": Array(event_deck),
		"hand": Array(hand),
		"pending_event": pending_event,
		"consumed_cards": Array(consumed_cards),
		"interactions_fired": Array(interactions_fired),
		"low_approval_turns": low_approval_turns,
		"debt_turns": debt_turns,
		"game_over": game_over,
		"outcome": outcome,
		"seen_interactions": Array(seen_interactions),
		"seen_events": Array(seen_events),
		"rng": rng.to_dict() if rng != null else {},
	}


static func from_dict(d: Dictionary) -> GameState:
	var state := GameState.new()
	state.age_id = String(d.get("age_id", ""))
	state.turn_number = int(d.get("turn_number", 0))
	state.year = int(d.get("year", 0))
	state.completed_ages.assign(d.get("completed_ages", []))
	state.transition_pending = bool(d.get("transition_pending", false))
	state.pending_transition_to = String(d.get("pending_transition_to", ""))
	state.population = int(d.get("population", 0))
	state.approval = int(d.get("approval", 0))
	state.migration_appeal = int(d.get("migration_appeal", 0))
	state.base_budget = int(d.get("base_budget", 0))
	state.current_budget = int(d.get("current_budget", 0))
	state.pending_bill = int(d.get("pending_bill", 0))
	state.policy_slots = int(d.get("policy_slots", 1))
	for dev_dict: Variant in d.get("developments", []):
		state.developments.append(DevelopmentState.from_dict(dev_dict))
	state.active_interactions.assign(d.get("active_interactions", []))
	state.unlocked_policies.assign(d.get("unlocked_policies", []))
	state.active_policies.assign(d.get("active_policies", []))
	state.main_deck.assign(d.get("main_deck", []))
	state.event_deck.assign(d.get("event_deck", []))
	state.hand.assign(d.get("hand", []))
	state.pending_event = String(d.get("pending_event", ""))
	state.consumed_cards.assign(d.get("consumed_cards", []))
	state.interactions_fired.assign(d.get("interactions_fired", []))
	state.low_approval_turns = int(d.get("low_approval_turns", 0))
	state.debt_turns = int(d.get("debt_turns", 0))
	state.game_over = bool(d.get("game_over", false))
	state.outcome = String(d.get("outcome", OUTCOME_NONE))
	state.seen_interactions.assign(d.get("seen_interactions", []))
	state.seen_events.assign(d.get("seen_events", []))
	state.rng = RngService.from_dict(d.get("rng", {}))
	return state
