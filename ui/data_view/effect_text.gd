class_name EffectText
extends RefCounted

## Static helper that turns any EffectDef into player-readable text.
## Used everywhere effects are surfaced: cards, the interactions panel,
## policies, event options, and the age-transition screen. Display names for
## referenced content ids are looked up in the ContentDB (null-safe).

const RESOURCE_NAMES: Dictionary = {
	"population_count": "Population",
	"population_level": "Population level",
	"budget": "Budget",
}


static func describe(effect: EffectDef, db: ContentDB) -> String:
	match effect.type:
		"resource_delta":
			return "%s %+d" % [_resource_name(effect.resource), effect.amount_int()]
		"income":
			return "%+d budget per turn" % effect.amount_int()
		"demand_delta":
			# One-time, and clamped at 0 — spending a reduction on a demand that
			# is already satisfied wastes it (GDD 4.0).
			return "%s %+d now" % [_demand_name(effect.demand, db), effect.amount_int()]
		"demand_modifier":
			return "%s grows %+d per turn" % [_demand_name(effect.demand, db), effect.amount_int()]
		"demand_modifier_per_tag":
			return "%s grows %+d per turn for every %s development" % [
				_demand_name(effect.demand, db), effect.amount_int(), effect.tag,
			]
		"cost_modifier":
			var scope: String = "All cards" if effect.tag == "" \
					else _capitalize(effect.tag) + " developments"
			var text: String = "%s cost %+d" % [scope, effect.amount_int()]
			if effect.min_cost >= 0:
				text += " (min %d)" % effect.min_cost
			return text
		"pop_growth_mult":
			return "Population growth %+d%%" % int(round(effect.amount * 100.0))
		"unlock_policy":
			return "Unlocks policy: %s" % _policy_name(effect.id, db)
		"inject_main":
			var count: int = effect.cards.size()
			if count == 1:
				return "Adds a card to your deck"
			return "Adds %d cards to your deck" % count
		"inject_events":
			return "Adds events"
		"remove_events":
			return "Removes events: %s" % ", ".join(_event_titles(effect.events, db))
		_:
			return effect.type


## Convenience: one line per effect, in definition order.
static func describe_all(effects: Array[EffectDef], db: ContentDB) -> Array[String]:
	var lines: Array[String] = []
	for effect: EffectDef in effects:
		lines.append(describe(effect, db))
	return lines


# --- private ----------------------------------------------------------------

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


## One printed demand value of a development: the number that both moves the
## meter now and feeds that demand's growth step for as long as it stands.
static func describe_printed_demand(demand_id: String, amount: int, db: ContentDB) -> String:
	return "%s %+d" % [_demand_name(demand_id, db), amount]


## Every printed value on a development, in stable order.
static func describe_printed_demands(demands: Dictionary, db: ContentDB) -> Array[String]:
	var lines: Array[String] = []
	var ids: Array = demands.keys()
	ids.sort()
	for demand_id: String in ids:
		var amount: int = int(demands[demand_id])
		if amount != 0:
			lines.append(describe_printed_demand(demand_id, amount, db))
	return lines


static func _policy_name(policy_id: String, db: ContentDB) -> String:
	if db != null and db.policies.has(policy_id):
		return (db.policies[policy_id] as PolicyDef).display_name
	return policy_id


static func _event_titles(event_ids: Array[String], db: ContentDB) -> Array[String]:
	var titles: Array[String] = []
	for event_id: String in event_ids:
		if db != null and db.events.has(event_id):
			titles.append((db.events[event_id] as EventDef).title)
		else:
			titles.append(event_id)
	return titles
