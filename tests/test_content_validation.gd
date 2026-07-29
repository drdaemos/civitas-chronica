extends RefCounted

## The content rules added with supersession and hazards (content-schema.md):
## successor references, supersession cycles, successors kept out of base
## decks, the canonical hazard vocabulary, and conditional-option references.


func run(t: TestContext) -> bool:
	# The fixture DB deliberately holds cards and events that no deck can reach
	# (test helpers played through force_play), so only the rules under test are
	# asserted clean here.
	t.label("valid supersession and hazard content produces no errors")
	var db: ContentDB = Fixtures.build_db()
	for fragment: String in ["supersession", "supersedes", "hazard", "hand_limit_bonus",
			"requires_development", "gated on a development", "lives in age"]:
		t.is_true(not _has_error(db, fragment), "fixture DB is clean of \"%s\"" % fragment)

	t.label("unknown successor is reported")
	t.is_true(_has_error(_db_with_card({
		"id": "town_market", "name": "Town Market", "category": "development",
		"cost": 3, "tags": ["trade"], "superseded_by": {"test_age2": "no_such_card"},
	}), "unknown card \"no_such_card\""), "dangling successor rejected")

	t.label("supersession cycles are reported")
	var cyclic: ContentDB = _db_with_card({
		"id": "town_market", "name": "Town Market", "category": "development",
		"cost": 3, "tags": ["trade"], "superseded_by": {"test_age2": "covered_market"},
	})
	var covered: CardDef = cyclic.cards["covered_market"]
	covered.superseded_by = {"test_age": "town_market"}
	t.is_true(_has_error(cyclic, "supersession chain revisits"), "cycle rejected")

	t.label("a card cannot supersede itself")
	t.is_true(_has_error(_db_with_card({
		"id": "town_market", "name": "Town Market", "category": "development",
		"cost": 3, "tags": ["trade"], "superseded_by": {"test_age2": "town_market"},
	}), "supersedes itself"), "self-supersession rejected")

	t.label("successors must not sit in a base deck — they are never drawn")
	var in_deck: ContentDB = Fixtures.build_db()
	var age2: AgeDef = in_deck.ages["test_age2"]
	age2.base_deck.append("covered_market")
	t.is_true(_has_error(in_deck, "is a supersession successor"), "successor in a deck rejected")

	t.label("successors live in the age they appear in")
	t.is_true(_has_error(_db_with_card({
		"id": "town_market", "name": "Town Market", "category": "development",
		"cost": 3, "tags": ["trade"], "superseded_by": {"test_age": "covered_market"},
	}), "lives in age \"test_age2\""), "wrong-age successor rejected")

	t.label("only developments take supersession, cancels and hand_limit_bonus")
	var action: ContentDB = _db_with_card({
		"id": "festival_of_saints", "name": "Festival of Saints", "category": "action",
		"cost": 1, "cancels": ["fire"], "hand_limit_bonus": 1,
		"superseded_by": {"test_age2": "covered_market"},
	})
	t.is_true(_has_error(action, "only developments may cancel hazards"), "cancels rejected")
	t.is_true(_has_error(action, "only developments may carry hand_limit_bonus"),
		"hand_limit_bonus rejected")
	t.is_true(_has_error(action, "superseded_by is for developments only"),
		"superseded_by rejected")

	t.label("hazard vocabulary is closed on both sides")
	t.is_true(_has_error(_db_with_card({
		"id": "levee", "name": "Levee", "category": "development",
		"cost": 3, "tags": ["infrastructure"], "cancels": ["locusts"],
	}), "non-canonical cancelled hazard \"locusts\""), "unknown cancelled hazard rejected")
	var bad_event: ContentDB = Fixtures.build_db()
	bad_event.events["river_flood"] = EventDef.from_dict({
		"id": "river_flood", "title": "River Flood", "hazard": "locusts",
		"options": [{"text": "Endure", "cost": 0, "effects": []}],
	})
	t.is_true(_has_error(bad_event, "non-canonical hazard \"locusts\""),
		"unknown event hazard rejected")

	t.label("the demand vocabulary is closed: unknown demands are rejected everywhere")
	t.is_true(_has_error(_db_with_card({
		"id": "town_market", "name": "Town Market", "category": "development",
		"cost": 3, "tags": ["trade"], "demands": {"nostalgia": -1},
	}), "printed value for unknown demand \"nostalgia\""), "printed value rejected")
	var bad_modifier: ContentDB = Fixtures.build_db()
	(bad_modifier.interactions["trade_hub"] as InteractionDef).effects.append(
		EffectDef.from_dict({"type": "demand_modifier", "demand": "nostalgia", "amount": 1}))
	t.is_true(_has_error(bad_modifier, "demand_modifier names unknown demand \"nostalgia\""),
		"modifier rejected")
	var bad_condition: ContentDB = Fixtures.build_db()
	(bad_condition.events["always_event"] as EventDef).trigger = ConditionDef.from_dict(
		{"type": "demand", "demand": "nostalgia", "op": ">=", "value": 1})
	t.is_true(_has_error(bad_condition, "condition demand names unknown demand \"nostalgia\""),
		"condition rejected")

	t.label("action cards move demands with an effect, not a printed map")
	t.is_true(_has_error(_db_with_card({
		"id": "festival_of_saints", "name": "Festival of Saints", "category": "action",
		"cost": 1, "demands": {"supply": -1},
	}), "action cards move demands with a demand_delta effect"), "printed map on an action rejected")

	t.label("only the count and the budget are writable; the level is derived")
	t.is_true(_has_error(_db_with_card({
		"id": "festival_of_saints", "name": "Festival of Saints", "category": "action",
		"cost": 1, "effects": [
			{"type": "resource_delta", "resource": "population_level", "amount": 1},
		],
	}), "resource_delta cannot write \"population_level\""), "writing the level rejected")

	t.label("an age must activate exactly one demand, and no demand twice")
	var no_demand: ContentDB = Fixtures.build_db()
	(no_demand.ages["test_age2"] as AgeDef).activates_demand = ""
	t.is_true(_has_error(no_demand, "no activates_demand"), "an age with no demand rejected")
	var twice: ContentDB = Fixtures.build_db()
	(twice.ages["test_age2"] as AgeDef).activates_demand = "supply"
	t.is_true(_has_error(twice, "is already activated by age"), "double activation rejected")

	t.label("every active demand needs an emergency and a catastrophe card per age")
	var uncovered: ContentDB = Fixtures.build_db()
	uncovered.events.erase("order_collapse_test_age2")
	t.is_true(_has_error(uncovered, "no catastrophe event in age test_age2"),
		"a demand with nowhere to send its pressure is rejected")
	# supply activates in test_age_chained and stays active into test_age2, so it
	# needs cards in BOTH ages: dropping the later age's pair is an error even
	# though the demand's own age is still covered.
	var uncovered_later: ContentDB = Fixtures.build_db()
	uncovered_later.events.erase("supply_shortage_test_age2")
	t.is_true(_has_error(uncovered_later,
			"demand supply: no emergency event in age test_age2 (active from test_age_chained)"),
		"coverage is required from the activating age onward")

	t.label("pressure fields come in pairs")
	var half_pressure: ContentDB = Fixtures.build_db()
	(half_pressure.events["always_event"] as EventDef).severity = "emergency"
	t.is_true(_has_error(half_pressure, "emergency severity without a demand"), "severity alone rejected")
	var lone_demand: ContentDB = Fixtures.build_db()
	(lone_demand.events["always_event"] as EventDef).demand = "supply"
	t.is_true(_has_error(lone_demand, "names a demand but no severity"), "demand alone rejected")

	t.label("pressure cards are never seeded into a base pool")
	var seeded: ContentDB = Fixtures.build_db()
	(seeded.ages["test_age"] as AgeDef).base_events.append("supply_shortage_test_age")
	t.is_true(_has_error(seeded, "is a emergency pressure card"), "seeding a crisis rejected")

	t.label("the rules table itself is checked")
	var bad_rules: ContentDB = Fixtures.build_db()
	bad_rules.rules = RulesDef.from_dict({
		"demand_threshold": 5, "demand_catastrophe": 4,
		"population_levels": [0, 900, 900],
		"demands": [{"id": "supply"}, {"id": "supply"}],
	})
	t.is_true(_has_error(bad_rules, "catastrophe value is not above its threshold"),
		"an unreachable catastrophe value is rejected")
	t.is_true(_has_error(bad_rules, "not strictly increasing"), "flat level boundaries rejected")
	t.is_true(_has_error(bad_rules, "duplicate demand"), "duplicate demand ids rejected")

	t.label("requires_development must name a real card, and cannot gate everything")
	var bad_option: ContentDB = Fixtures.build_db()
	bad_option.events["always_event"] = EventDef.from_dict({
		"id": "always_event", "title": "Always Event",
		"options": [{"text": "Ask the guild", "cost": 0,
			"requires_development": "no_such_card", "effects": []}],
	})
	t.is_true(_has_error(bad_option, "unknown card \"no_such_card\""),
		"dangling requires_development rejected")
	t.is_true(_has_error(bad_option, "every option is gated on a development"),
		"fully-gated event rejected")

	t.label("events may be announcements with one choice, but never zero choices")
	var one_choice: ContentDB = Fixtures.build_db()
	var one_event: EventDef = one_choice.events["always_event"]
	one_event.options.resize(1)
	t.is_true(not _has_error(one_choice, "needs at least one choice"),
		"one-choice announcement accepted")
	var no_choice: ContentDB = Fixtures.build_db()
	(no_choice.events["always_event"] as EventDef).options.clear()
	t.is_true(_has_error(no_choice, "needs at least one choice"),
		"event with no response rejected")
	return true



# --- helpers -----------------------------------------------------------------

## The fixture DB with one card replaced by the given definition.
func _db_with_card(card_dict: Dictionary) -> ContentDB:
	var db: ContentDB = Fixtures.build_db()
	var card: CardDef = CardDef.from_dict(card_dict)
	card.age_id = (db.cards[card.id] as CardDef).age_id
	db.cards[card.id] = card
	return db


func _has_error(db: ContentDB, fragment: String) -> bool:
	for error: String in db.validate():
		if error.contains(fragment):
			return true
	return false
