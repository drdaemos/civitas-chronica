class_name EffectText
extends RefCounted

## Turns simulation effects into player-readable consequences. Demand wording
## consistently describes unmet need: positive values increase a demand and
## negative values satisfy it.

const RESOURCE_NAMES: Dictionary = {
	"population_count": "Population",
	"population_level": "Population level",
	"budget": "Budget",
}


static func describe(effect: EffectDef, db: ContentDB) -> String:
	match effect.type:
		"resource_delta":
			var resource_amount: int = effect.amount_int()
			if resource_amount == 0:
				return ""
			return "%s %s by %d" % [
				"Increases" if resource_amount > 0 else "Reduces",
				_resource_name(effect.resource), absi(resource_amount),
			]
		"income":
			var income_amount: int = effect.amount_int()
			if income_amount == 0:
				return ""
			return "%s budget by %d each turn" % [
				"Increases" if income_amount > 0 else "Reduces", absi(income_amount),
			]
		"demand_delta":
			return _demand_change_text(effect.demand, effect.amount_int(), db)
		"demand_modifier":
			return _demand_change_text(effect.demand, effect.amount_int(), db, " each turn")
		"demand_modifier_per_tag":
			var tag_amount: int = effect.amount_int()
			if tag_amount == 0:
				return ""
			return "%s %s by %d each turn for every %s development" % [
				"Satisfies" if tag_amount < 0 else "Increases",
				_demand_name(effect.demand, db), absi(tag_amount), effect.tag,
			]
		"cost_modifier":
			var scope: String = "All cards" if effect.tag == "" \
					else _capitalize(effect.tag) + " developments"
			var text: String = "%s cost %s by %d" % [
				scope, "increases" if effect.amount_int() > 0 else "decreases",
				absi(effect.amount_int()),
			]
			if effect.min_cost >= 0:
				text += " (minimum %d)" % effect.min_cost
			return text
		"pop_growth_mult":
			var percentage: int = int(round(effect.amount * 100.0))
			return "%s population growth by %d%%" % [
				"Increases" if percentage > 0 else "Reduces", absi(percentage),
			]
		"unlock_policy":
			return ""  # policies are intentionally disabled in the current UI
		"inject_main":
			var count: int = effect.cards.size()
			return "Adds %d new card%s to the deck" % [
				count, "" if count == 1 else "s",
			]
		"inject_events":
			return "Adds new events to the city's future"
		"remove_events":
			return "Removes events: %s" % ", ".join(_event_titles(effect.events, db))
		_:
			return effect.type


static func describe_all(effects: Array[EffectDef], db: ContentDB) -> Array[String]:
	var lines: Array[String] = []
	for effect: EffectDef in effects:
		var line: String = describe(effect, db)
		if line != "":
			lines.append(line)
	return lines


static func describe_printed_demand(demand_id: String, amount: int, db: ContentDB) -> String:
	if amount == 0:
		return ""
	var verb: String = "Satisfies" if amount < 0 else "Increases"
	var growth_verb: String = "reduces" if amount < 0 else "increases"
	return "%s %s by %d · %s growth by %d/turn" % [
		verb, _demand_name(demand_id, db), absi(amount), growth_verb, absi(amount),
	]


static func describe_printed_demands(demands: Dictionary, db: ContentDB) -> Array[String]:
	var lines: Array[String] = []
	var ids: Array = demands.keys()
	ids.sort()
	for demand_id: String in ids:
		var amount: int = int(demands[demand_id])
		var line: String = describe_printed_demand(demand_id, amount, db)
		if line != "":
			lines.append(line)
	return lines


static func _resource_name(resource: String) -> String:
	return String(RESOURCE_NAMES.get(resource, _capitalize(resource)))


static func _capitalize(word: String) -> String:
	if word.is_empty():
		return word
	return word[0].to_upper() + word.substr(1)


static func _demand_name(demand_id: String, db: ContentDB) -> String:
	if db != null:
		var demand: DemandDef = db.rules.get_demand(demand_id)
		if demand != null:
			return demand.display_name
	return demand_id


static func _demand_change_text(demand_id: String, amount: int, db: ContentDB,
		suffix: String = "") -> String:
	if amount == 0:
		return ""
	return "%s %s by %d%s" % [
		"Satisfies" if amount < 0 else "Increases",
		_demand_name(demand_id, db), absi(amount), suffix,
	]


static func _event_titles(event_ids: Array[String], db: ContentDB) -> Array[String]:
	var titles: Array[String] = []
	for event_id: String in event_ids:
		if db != null and db.events.has(event_id):
			titles.append((db.events[event_id] as EventDef).title)
		else:
			titles.append(event_id)
	return titles
