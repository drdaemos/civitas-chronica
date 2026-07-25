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


static func build_db() -> ContentDB:
	var db := ContentDB.new()

	# --- age-1 cards -----------------------------------------------------------
	_add_card(db, {
		"id": "town_market", "name": "Town Market",
		"category": "development", "cost": 3, "tags": ["trade"],
		"effects": [{"type": "income", "amount": 1}],
		# Adapted upgrade for the transition suites (cost billed to age 2).
		"age_variants": {
			"test_age2": {
				"adapted": {"cost": 3, "tags": ["trade", "cultural"],
					"effects": [{"type": "income", "amount": 2}]},
			},
		},
	})
	_add_card(db, {
		"id": "river_docks", "name": "River Docks",
		"category": "development", "cost": 4, "tags": ["trade"],
		"effects": [{"type": "income", "amount": 1}],
		"inject_main": ["harbor_expansion"],
		"inject_events": ["trade_dispute"],
	})
	_add_card(db, {
		"id": "harbor_expansion", "name": "Harbor Expansion",
		"category": "development", "cost": 5, "tags": ["trade", "infrastructure"],
		"prerequisites": ["river_docks"],
		"effects": [
			{"type": "income", "amount": 2},
			{"type": "resource_delta", "resource": "migration_appeal", "amount": 2},
		],
		"inject_events": ["trade_dispute"],
		# Preserved tag-shift: losing "trade" can break trade_hub's threshold.
		"age_variants": {
			"test_age2": {
				"preserved": {"tags": ["cultural"],
					"effects": [{"type": "approval_per_turn", "amount": 1}]},
				"demolish_approval": -5,
			},
		},
	})
	_add_card(db, {
		"id": "cobblestone_roads", "name": "Cobblestone Roads",
		"category": "development", "cost": 2, "tags": ["infrastructure"],
		"effects": [],
	})
	_add_card(db, {
		"id": "grain_storehouse", "name": "Grain Storehouse",
		"category": "development", "cost": 2, "tags": ["infrastructure"],
		"effects": [],
	})
	_add_card(db, {
		"id": "stone_church", "name": "Stone Church",
		"category": "development", "cost": 4, "tags": ["religious", "cultural"],
		"effects": [{"type": "resource_delta", "resource": "approval", "amount": 3}],
		# Variant with only defaults: no preserved/adapted set, demolish -3.
		"age_variants": {"test_age2": {}},
	})
	_add_card(db, {
		"id": "iron_foundry", "name": "Iron Foundry",
		"category": "development", "cost": 4, "tags": ["industrial"],
		"effects": [{"type": "income", "amount": 1}],
	})
	_add_card(db, {
		"id": "festival_of_saints", "name": "Festival of Saints",
		"category": "action", "cost": 1,
		"effects": [{"type": "resource_delta", "resource": "approval", "amount": 5}],
	})
	# Lose-condition test helper: tanks approval in one play.
	_add_card(db, {
		"id": "unpopular_decree", "name": "Unpopular Decree",
		"category": "action", "cost": 0,
		"effects": [{"type": "resource_delta", "resource": "approval", "amount": -100}],
	})

	# --- age-2 cards -----------------------------------------------------------
	_add_card(db, {
		"id": "steam_mill", "name": "Steam Mill",
		"category": "development", "cost": 4, "tags": ["industrial"],
		"effects": [{"type": "income", "amount": 2}],
	}, "test_age2")
	_add_card(db, {
		"id": "printing_press", "name": "Printing Press",
		"category": "development", "cost": 3, "tags": ["science", "cultural"],
		"effects": [{"type": "income", "amount": 1}],
	}, "test_age2")
	_add_card(db, {
		"id": "trade_exchange", "name": "Trade Exchange",
		"category": "development", "cost": 3, "tags": ["trade"],
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
			{"type": "resource_delta", "resource": "approval", "amount": 5},
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
				{"type": "resource_delta", "resource": "approval", "amount": 5},
				{"type": "resource_delta", "resource": "migration_appeal", "amount": -2},
			]},
			{"text": "Open the markets", "cost": 0, "effects": [
				{"type": "resource_delta", "resource": "approval", "amount": -5},
				{"type": "resource_delta", "resource": "migration_appeal", "amount": 3},
			]},
			{"text": "Mediate", "cost": 3, "effects": [
				{"type": "unlock_policy", "id": "trade_council"},
			]},
		],
	})
	_add_event(db, {
		"id": "never_event", "title": "Never Event",
		"text": "Trigger can never be satisfied.",
		"trigger": {"type": "resource", "resource": "population", "op": ">=", "value": 999999},
		"options": [{"text": "Fine", "cost": 0, "effects": []}],
	})
	_add_event(db, {
		"id": "never_event_b", "title": "Never Event B",
		"text": "Trigger can never be satisfied.",
		"trigger": {"type": "resource", "resource": "population", "op": ">=", "value": 999999},
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
				{"type": "resource_delta", "resource": "approval", "amount": -100},
			]},
		],
	})
	_add_event(db, {
		"id": "royal_decree", "title": "Royal Decree",
		"text": "Forced event; its trigger is never true on its own.",
		"trigger": {"type": "resource", "resource": "population", "op": ">=", "value": 999999},
		"options": [{"text": "Comply", "cost": 0, "effects": []}],
	})

	# --- policies ----------------------------------------------------------------
	db.policies["trade_council"] = PolicyDef.from_dict({
		"id": "trade_council", "name": "Trade Council",
		"description": "Merchant representation in city governance.",
		"unlock": {"type": "interaction_active", "id": "trade_hub"},
		"effects": [{"type": "income", "amount": 1}],
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
		"start": {"population": 500, "approval": 70, "migration_appeal": 4},
		"base_deck": age1_deck,
		"base_events": ["never_event"],
		"forced_events": [],
	})
	db.ages["test_age_chained"] = AgeDef.from_dict({
		"id": "test_age_chained", "name": "Test Age (Chained)",
		"year_start": 1500, "year_end": 1700, "years_per_turn": 8,
		"base_draw": 3, "base_budget": 10, "policy_slots": 1,
		"next_age": "test_age2",
		"start": {"population": 500, "approval": 70, "migration_appeal": 4},
		"base_deck": age1_deck,
		"base_events": ["never_event"],
		"forced_events": [],
	})
	db.ages["test_age2"] = AgeDef.from_dict({
		"id": "test_age2", "name": "Test Age Two",
		"year_start": 1700, "year_end": 1860, "years_per_turn": 8,
		"base_draw": 3, "base_budget": 14, "policy_slots": 2,
		"start": {"population": 500, "approval": 70, "migration_appeal": 4},
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
		"start": {"population": 500, "approval": 70, "migration_appeal": 4},
		"base_deck": ["festival_of_saints"],
		"base_events": [],
		"forced_events": [{"event": "royal_decree", "turn": 2}],
	})

	return db


static func _add_card(db: ContentDB, d: Dictionary, age_id: String = "test_age") -> void:
	var card: CardDef = CardDef.from_dict(d)
	card.age_id = age_id
	db.cards[card.id] = card


static func _add_event(db: ContentDB, d: Dictionary) -> void:
	var event: EventDef = EventDef.from_dict(d)
	event.age_id = "test_age"
	db.events[event.id] = event


## Puts a card into hand with ample budget and plays it. For tests that
## need a specific tableau regardless of draws.
static func force_play(engine: TurnEngine, card_id: String) -> Dictionary:
	engine.state.hand.append(card_id)
	engine.state.current_budget = 100
	return engine.play_card(card_id)


## Deterministic scripted turn: start, greedily play affordable cards from
## the front of the hand, end, resolve any event with option 0. Used by the
## determinism and save-roundtrip suites.
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
	engine.end_turn()
	if engine.state.pending_event != "":
		engine.resolve_event(0)
