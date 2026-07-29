class_name EventLogFormatter
extends RefCounted

## Converts domain events into terse secondary-history lines. Automatic upkeep
## is presented primarily by UpkeepOverlay; the chronicle remains a record.

static func describe(event: Dictionary, db: ContentDB) -> String:
	match String(event.get("type", "")):
		"turn_started":
			return "\n[color=#d1a85a][b]TURN %d · %d[/b][/color]" % [
				int(event.get("turn", 0)), int(event.get("year", 0)),
			]
		"cards_drawn":
			var names: Array[String] = []
			for card_id: Variant in event.get("cards", []) as Array:
				names.append(_card_name(String(card_id), db))
			return "Drew %s." % ", ".join(names) if not names.is_empty() else "The deck is empty."
		"card_played":
			return "Built %s." % _card_name(String(event.get("card", "")), db)
		"cards_discarded":
			var discarded: Array[String] = []
			for card_id: Variant in event.get("cards", []) as Array:
				discarded.append(_card_name(String(card_id), db))
			return "[color=#d9676e]Discarded: %s.[/color]" % ", ".join(discarded)
		"interaction_activated":
			var interaction: InteractionDef = db.get_interaction(String(event.get("id", "")))
			var name: String = interaction.display_name if interaction != null else String(event.get("id", ""))
			return "[color=#66ad93]Interaction active: %s.[/color]" % name
		"interaction_deactivated":
			var interaction: InteractionDef = db.get_interaction(String(event.get("id", "")))
			var name: String = interaction.display_name if interaction != null else String(event.get("id", ""))
			return "[color=#d9676e]Interaction lost: %s.[/color]" % name
		"policy_unlocked":
			return ""  # policies are intentionally disabled in the current UI
		"event_fired":
			var fired: EventDef = db.get_event(String(event.get("id", "")))
			return "[color=#d7a94f]Event: %s.[/color]" % (
				fired.title if fired != null else String(event.get("id", "")))
		"event_resolved":
			var resolved: EventDef = db.get_event(String(event.get("id", "")))
			var index: int = int(event.get("option", -1))
			if resolved != null and index >= 0 and index < resolved.options.size():
				return "Decision: %s." % resolved.options[index].text
			return "The event was resolved."
		"hazard_cancelled":
			return "[color=#66ad93]%s prevented %s damage.[/color]" % [
				_card_name(String(event.get("by", "")), db), String(event.get("hazard", "")),
			]
		"population_grew":
			return "Population %+d → %s." % [
				int(event.get("delta", 0)), _thousands(int(event.get("count", 0))),
			]
		"population_level_changed":
			return "[color=#d7a94f]Population level %d → %d.[/color]" % [
				int(event.get("from", 0)), int(event.get("to", 0)),
			]
		"demand_grew":
			return "%s unmet need %d → %d." % [
				_demand_name(String(event.get("demand", "")), db),
				int(event.get("from", 0)), int(event.get("to", 0)),
			]
		"demand_changed":
			return "%s unmet need %d → %d." % [
				_demand_name(String(event.get("demand", "")), db),
				int(event.get("from", 0)), int(event.get("to", 0)),
			]
		"pressure_card_shuffled":
			return "[color=#d7a94f]%s added danger to the event deck.[/color]" % \
				_demand_name(String(event.get("demand", "")), db)
		"development_superseded":
			return "%s became %s." % [
				_card_name(String(event.get("from", "")), db),
				_card_name(String(event.get("to", "")), db),
			]
		"age_ended":
			return "[b]The age draws to a close.[/b]"
		"age_transitioned":
			var age: AgeDef = db.get_age(String(event.get("to", "")))
			return "[b]%s begins.[/b]" % (
				age.display_name if age != null else String(event.get("to", "")))
		"game_over":
			return "[b]Final score: %d.[/b]" % int(
				(event.get("score", {}) as Dictionary).get("total", 0))
		_:
			return ""


static func _card_name(card_id: String, db: ContentDB) -> String:
	var card: CardDef = db.get_card(card_id)
	return card.display_name if card != null else card_id


static func _demand_name(demand_id: String, db: ContentDB) -> String:
	var demand: DemandDef = db.rules.get_demand(demand_id)
	return demand.display_name if demand != null else demand_id


static func _thousands(value: int) -> String:
	var raw: String = str(value)
	var out: String = ""
	while raw.length() > 3:
		out = "," + raw.substr(raw.length() - 3) + out
		raw = raw.substr(0, raw.length() - 3)
	return raw + out
