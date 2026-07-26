class_name Fixtures
extends RefCounted

## In-code fixture ContentDB for tests only (constitution rule 4 permits
## in-code content for tests). Mirrors the GDD Appendix B worked example:
## the trade/infrastructure build-up toward Trade Hub + Well-Connected City,
## plus a second age ("test_age2") for the age-transition suites.
##
## Ages:
## - test_age          single age, no next_age -> completing it wins.
## - test_age_chained  same window as test_age but next_age = test_age2.
## - test_age2         the follow-up age (final), its own deck/event pools.
## - forced_age        single age with a scheduled forced event.
##
## Demands: "supply" activates with the first age and "order" with test_age2,
## deliberately NOT named after the shipped content's demands — nothing in the
## engine may care which demands exist (GDD 4.0).


static func build_db() -> ContentDB:
	var db := ContentDB.new()
	db.rules = RulesDef.from_dict({
		"demand_threshold": 3,
		"demand_catastrophe": 8,
		"population_levels": [0, 1000, 3000],
		"population_level_hysteresis": 0.05,
		"population_variance": 0.15,
		"growth_by_demands_over_threshold": [1.0, 0.5, 0.0, -0.5],
		"demands": [
			{"id": "supply", "name": "Supply", "bands": [
				{"at": 0, "text": "The stores are full."},
				{"at": 3, "text": "The stores are short."},
			]},
			{"id": "order", "name": "Order"},
		],
	})

	# --- age-1 cards -----------------------------------------------------------
	_add_card(db, {
		"id": "town_market", "name": "Town Market",
		"category": "development", "cost": 3, "tags": ["trade"],
		"demands": {"supply": -1}, "effects": [{"type": "income", "amount": 1}],
		# Supersession that keeps the trade tag but changes what the building
		# does, and opens a path in the new age (transition suites).
		"superseded_by": {"test_age2": "covered_market"},
	})
	_add_card(db, {
		"id": "river_docks", "name": "River Docks",
		"category": "development", "cost": 4, "tags": ["trade"],
		"demands": {"supply": -1}, "effects": [{"type": "income", "amount": 1}],
		"inject_main": ["harbor_expansion"],
		"inject_events": ["trade_dispute"],
	})
	_add_card(db, {
		"id": "harbor_expansion", "name": "Harbor Expansion",
		"category": "development", "cost": 5, "tags": ["trade", "infrastructure"],
		"prerequisites": ["river_docks"],
		"demands": {"supply": -1, "order": 1}, "effects": [
			{"type": "income", "amount": 2},
		],
		"inject_events": ["trade_dispute"],
		# Supersession that drops "trade": enough to break trade_hub's
		# threshold, which is how an interaction gets lost at a boundary.
		"superseded_by": {"test_age2": "harbor_promenade"},
	})
	_add_card(db, {
		"id": "cobblestone_roads", "name": "Cobblestone Roads",
		"category": "development", "cost": 2, "tags": ["infrastructure"],
		"demands": {"supply": -1}, "effects": [],
	})
	_add_card(db, {
		"id": "grain_storehouse", "name": "Grain Storehouse",
		"category": "development", "cost": 2, "tags": ["infrastructure"],
		"demands": {"supply": -2}, "effects": [],
	})
	_add_card(db, {
		"id": "stone_church", "name": "Stone Church",
		"category": "development", "cost": 4, "tags": ["religious", "cultural"],
		"demands": {"order": -1}, "effects": [],
	})
	# Hazard protection (GDD 4.4) plus the hand-limit lever (GDD 4.1).
	_add_card(db, {
		"id": "levee", "name": "Levee",
		"category": "development", "cost": 3, "tags": ["infrastructure"],
		"cancels": ["flood"],
		"demands": {"supply": -1}, "effects": [],
	})
	_add_card(db, {
		"id": "scriptorium", "name": "Scriptorium",
		"category": "development", "cost": 3, "tags": ["cultural"],
		"hand_limit_bonus": 2,
		"effects": [],
	})
	_add_card(db, {
		"id": "merchant_guild", "name": "Merchant Guild",
		"category": "development", "cost": 3, "tags": ["trade"],
		"demands": {"supply": -1}, "effects": [],
	})
	_add_card(db, {
		"id": "iron_foundry", "name": "Iron Foundry",
		"category": "development", "cost": 4, "tags": ["industrial"],
		"demands": {"supply": 1, "order": 1}, "effects": [{"type": "income", "amount": 1}],
	})
	_add_card(db, {
		"id": "festival_of_saints", "name": "Festival of Saints",
		"category": "action", "cost": 1,
		"effects": [{"type": "demand_delta", "demand": "supply", "amount": -2}],
	})
	# Lose-condition test helper: drives a demand straight past catastrophe.
	_add_card(db, {
		"id": "unpopular_decree", "name": "Unpopular Decree",
		"category": "action", "cost": 0,
		"effects": [{"type": "demand_delta", "demand": "supply", "amount": 12}],
	})

	# --- age-2 cards -----------------------------------------------------------
	_add_card(db, {
		"id": "steam_mill", "name": "Steam Mill",
		"category": "development", "cost": 4, "tags": ["industrial"],
		"demands": {"supply": 1}, "effects": [{"type": "income", "amount": 2}],
	}, "test_age2")
	_add_card(db, {
		"id": "printing_press", "name": "Printing Press",
		"category": "development", "cost": 3, "tags": ["science", "cultural"],
		"effects": [{"type": "income", "amount": 1}],
	}, "test_age2")
	_add_card(db, {
		"id": "trade_exchange", "name": "Trade Exchange",
		"category": "development", "cost": 3, "tags": ["trade"],
		"demands": {"supply": -1}, "effects": [{"type": "income", "amount": 1}],
	}, "test_age2")
	# Supersession successors: never drawn, never in a base deck (GDD 4.6).
	_add_card(db, {
		"id": "covered_market", "name": "Covered Market",
		"category": "development", "cost": 3, "tags": ["trade"],
		"demands": {"supply": -2}, "effects": [{"type": "income", "amount": 2}],
		"inject_main": ["market_hall"],
		"inject_events": ["never_event_b"],
	}, "test_age2")
	_add_card(db, {
		"id": "market_hall", "name": "Market Hall",
		"category": "development", "cost": 2, "tags": ["trade"],
		"demands": {"supply": -1}, "effects": [],
	}, "test_age2")
	_add_card(db, {
		"id": "harbor_promenade", "name": "Harbor Promenade",
		"category": "development", "cost": 4, "tags": ["cultural"],
		"effects": [{"type": "income", "amount": 1}],
	}, "test_age2")

	# --- interactions ----------------------------------------------------------
	db.interactions["trade_hub"] = InteractionDef.from_dict({
		"id": "trade_hub", "name": "Trade Hub",
		"description": "+2 budget/turn. Industrial developments cost +1.",
		"threshold": {"type": "tag_count", "tag": "trade", "op": ">=", "value": 3},
		"effects": [
			{"type": "income", "amount": 2},
			{"type": "cost_modifier", "tag": "industrial", "amount": 1},
			{"type": "demand_delta", "demand": "supply", "amount": -2},
			{"type": "demand_modifier", "demand": "order", "amount": 1},
		],
	})
	db.interactions["well_connected_city"] = InteractionDef.from_dict({
		"id": "well_connected_city", "name": "Well-Connected City",
		"description": "All development costs -1 (min 1). Population growth +10%.",
		"threshold": {"type": "tag_count", "tag": "infrastructure", "op": ">=", "value": 3},
		"effects": [
			{"type": "cost_modifier", "amount": -1, "min_cost": 1},
			{"type": "pop_growth_mult", "amount": 0.1},
		],
	})

	# --- events ----------------------------------------------------------------
	_add_event(db, {
		"id": "trade_dispute", "title": "Trade Dispute",
		"text": "Foreign merchants accuse local traders of unfair tariffs.",
		"trigger": {"type": "interaction_active", "id": "trade_hub"},
		"options": [
			{"text": "Side with local traders", "cost": 0, "effects": [
				{"type": "demand_delta", "demand": "supply", "amount": 2},
			]},
			{"text": "Open the markets", "cost": 0, "effects": [
				{"type": "demand_delta", "demand": "supply", "amount": -1},
			]},
			{"text": "Mediate", "cost": 3, "effects": [
				{"type": "unlock_policy", "id": "trade_council"},
			]},
			# Extra option, only for a city with the guild standing (GDD 4.4).
			{"text": "Let the guild arbitrate", "cost": 0,
				"requires_development": "merchant_guild", "effects": [
					{"type": "demand_delta", "demand": "supply", "amount": -2},
				]},
		],
	})
	# Hazard event for the cancellation suite: a mix of harmful and harmless
	# effects on one option, so cancellation has to be selective.
	_add_event(db, {
		"id": "river_flood", "title": "River Flood",
		"text": "The thaw puts the low quarter under water.",
		"hazard": "flood",
		"options": [
			{"text": "Absorb the damage", "cost": 0, "effects": [
				{"type": "demand_delta", "demand": "supply", "amount": 3},
				{"type": "resource_delta", "resource": "population_count", "amount": -50},
				{"type": "unlock_policy", "id": "trade_council"},
			]},
			{"text": "Pay for repairs", "cost": 4, "effects": []},
		],
	})
	_add_event(db, {
		"id": "never_event", "title": "Never Event",
		"text": "Trigger can never be satisfied.",
		"trigger": {"type": "resource", "resource": "population_count", "op": ">=", "value": 999999},
		"options": [{"text": "Fine", "cost": 0, "effects": []}],
	})
	_add_event(db, {
		"id": "never_event_b", "title": "Never Event B",
		"text": "Trigger can never be satisfied.",
		"trigger": {"type": "resource", "resource": "population_count", "op": ">=", "value": 999999},
		"options": [{"text": "Fine", "cost": 0, "effects": []}],
	})
	_add_event(db, {
		"id": "always_event", "title": "Always Event",
		"text": "Matches any city state.",
		"options": [
			{"text": "Do nothing", "cost": 0, "effects": []},
			{"text": "Spend some", "cost": 3, "effects": []},
			{"text": "Spend a fortune", "cost": 50, "effects": []},
		],
	})
	_add_event(db, {
		"id": "catastrophe", "title": "Catastrophe",
		"text": "Worst-case single-turn shock for lose-condition tests.",
		"options": [
			{"text": "Endure", "cost": 100, "effects": [
				{"type": "demand_delta", "demand": "supply", "amount": 6},
			]},
		],
	})
	_add_event(db, {
		"id": "royal_decree", "title": "Royal Decree",
		"text": "Forced event; its trigger is never true on its own.",
		"trigger": {"type": "resource", "resource": "population_count", "op": ">=", "value": 999999},
		"options": [{"text": "Comply", "cost": 0, "effects": []}],
	})
	# Pressure coverage: every active demand needs an emergency and a
	# catastrophe card in every age it is live in (content-schema.md). "supply"
	# activates with the first age of each chain, "order" with test_age2.
	for age_id: String in ["test_age", "test_age_chained", "test_age2", "forced_age"]:
		_add_pressure_pair(db, "supply", age_id)
	_add_pressure_pair(db, "order", "test_age2")

	# --- policies ----------------------------------------------------------------
	db.policies["trade_council"] = PolicyDef.from_dict({
		"id": "trade_council", "name": "Trade Council",
		"description": "Merchant representation in city governance.",
		"unlock": {"type": "interaction_active", "id": "trade_hub"},
		"effects": [
			{"type": "income", "amount": 1},
			{"type": "demand_modifier", "demand": "supply", "amount": -1},
		],
	})
	db.policies["civic_charter"] = PolicyDef.from_dict({
		"id": "civic_charter", "name": "Civic Charter",
		"description": "Available from the start.",
		"unlock": {"type": "always"},
		"effects": [{"type": "income", "amount": 1}],
	})
	db.policies["public_works"] = PolicyDef.from_dict({
		"id": "public_works", "name": "Public Works",
		"description": "Available from the start; used for slot tests.",
		"unlock": {"type": "always"},
		"effects": [],
	})

	# --- ages ----------------------------------------------------------------
	var age1_deck: Array = [
		"town_market", "river_docks", "cobblestone_roads", "grain_storehouse",
		"stone_church", "iron_foundry", "festival_of_saints",
	]
	db.ages["test_age"] = AgeDef.from_dict({
		"id": "test_age", "name": "Test Age",
		"year_start": 1500, "year_end": 1700, "years_per_turn": 8,
		"base_draw": 3, "base_budget": 10, "policy_slots": 1,
		"activates_demand": "supply", "population_growth_base": 40,
		"start": {"population_count": 500},
		"base_deck": age1_deck,
		"base_events": ["never_event"],
		"forced_events": [],
	})
	db.ages["test_age_chained"] = AgeDef.from_dict({
		"id": "test_age_chained", "name": "Test Age (Chained)",
		"year_start": 1500, "year_end": 1700, "years_per_turn": 8,
		"base_draw": 3, "base_budget": 10, "policy_slots": 1,
		"next_age": "test_age2",
		"activates_demand": "supply", "population_growth_base": 40,
		"start": {"population_count": 500},
		"base_deck": age1_deck,
		"base_events": ["never_event"],
		"forced_events": [],
	})
	db.ages["test_age2"] = AgeDef.from_dict({
		"id": "test_age2", "name": "Test Age Two",
		"year_start": 1700, "year_end": 1860, "years_per_turn": 8,
		"base_draw": 3, "base_budget": 14, "policy_slots": 2,
		"activates_demand": "order", "population_growth_base": 60,
		"start": {"population_count": 500},
		"base_deck": [
			"steam_mill", "printing_press", "trade_exchange",
			"town_market", "festival_of_saints",
		],
		"base_events": ["never_event_b"],
		"forced_events": [],
	})
	db.ages["forced_age"] = AgeDef.from_dict({
		"id": "forced_age", "name": "Forced Event Age",
		"year_start": 1500, "year_end": 1700, "years_per_turn": 8,
		"base_draw": 3, "base_budget": 10, "policy_slots": 1,
		"activates_demand": "supply", "population_growth_base": 40,
		"start": {"population_count": 500},
		"base_deck": ["festival_of_saints"],
		"base_events": [],
		"forced_events": [{"event": "royal_decree", "turn": 2}],
	})

	return db


static func _add_card(db: ContentDB, d: Dictionary, age_id: String = "test_age") -> void:
	var card: CardDef = CardDef.from_dict(d)
	card.age_id = age_id
	db.cards[card.id] = card


## One emergency and one catastrophe card for a demand in one age, with ids
## scoped to the age so each age has its own pool.
static func _add_pressure_pair(db: ContentDB, demand_id: String, age_id: String) -> void:
	_add_event(db, {
		"id": "%s_shortage_%s" % [demand_id, age_id], "title": "Shortage",
		"text": "The city is short of what it needs.",
		"demand": demand_id, "severity": "emergency",
		"trigger": {"type": "demand", "demand": demand_id, "op": ">=", "value": 3},
		"options": [
			{"text": "Answer it", "cost": 3, "effects": [
				{"type": "demand_delta", "demand": demand_id, "amount": -2},
			]},
			{"text": "Do without", "cost": 0, "effects": []},
		],
	}, age_id)
	_add_event(db, {
		"id": "%s_collapse_%s" % [demand_id, age_id], "title": "Collapse",
		"text": "What the city needs is simply gone.",
		"demand": demand_id, "severity": "catastrophe",
		"trigger": {"type": "demand", "demand": demand_id, "op": ">=", "value": 8},
		"options": [
			{"text": "Empty the treasury", "cost": 8, "effects": [
				{"type": "demand_delta", "demand": demand_id, "amount": -6},
			]},
			{"text": "Endure it", "cost": 0, "effects": [
				{"type": "resource_delta", "resource": "population_count", "amount": -200},
			]},
		],
	}, age_id)


static func _add_event(db: ContentDB, d: Dictionary, age_id: String = "test_age") -> void:
	var event: EventDef = EventDef.from_dict(d)
	event.age_id = age_id
	db.events[event.id] = event


## Silences the demand system for suites that are about something else. With no
## active demands, upkeep grows nothing and shuffles no pressure cards, so the
## turn sequence under test is not interrupted by crises it did not ask for.
static func quiet_demands(state: GameState) -> void:
	state.active_demands.clear()
	state.demands.clear()


## Closes a turn the way a player would: discard down to the hand limit, answer
## whatever event is pending, then end the turn.
static func settle_turn(engine: TurnEngine) -> void:
	var overflow: int = DeckManager.hand_overflow(engine.state, engine.db)
	if overflow > 0:
		engine.discard_cards(engine.state.hand.slice(0, overflow))
	if engine.state.pending_event != "":
		engine.resolve_event(first_available_option(engine.state, engine.db))
	engine.end_turn()


## Puts a card into hand with ample budget and plays it. For tests that
## need a specific tableau regardless of draws.
static func force_play(engine: TurnEngine, card_id: String) -> Dictionary:
	engine.state.hand.append(card_id)
	engine.state.current_budget = 100
	return engine.play_card(card_id)


## Deterministic scripted turn: start, greedily play affordable cards from the
## front of the hand, discard from the front down to the hand limit, end,
## resolve any event with the first available option. Used by the determinism
## and save-roundtrip suites.
static func scripted_turn(engine: TurnEngine) -> void:
	if engine.state.game_over:
		return
	engine.start_turn()
	if engine.state.game_over:
		return
	var idx: int = 0
	while idx < engine.state.hand.size():
		var result: Dictionary = engine.play_card(engine.state.hand[idx])
		if not bool(result.get("ok", false)):
			idx += 1
	var overflow: int = DeckManager.hand_overflow(engine.state, engine.db)
	if overflow > 0:
		engine.discard_cards(engine.state.hand.slice(0, overflow))
	engine.end_turn()
	if engine.state.pending_event != "":
		engine.resolve_event(first_available_option(engine.state, engine.db))


## Index of the first option the current city may actually choose — options
## gated on a development (GDD 4.4) are skipped.
static func first_available_option(state: GameState, db: ContentDB) -> int:
	var event: EventDef = db.get_event(state.pending_event)
	if event == null:
		return 0
	for i: int in event.options.size():
		if event.options[i].is_available(state):
			return i
	return 0
