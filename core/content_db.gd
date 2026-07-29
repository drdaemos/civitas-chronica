class_name ContentDB
extends RefCounted

## Loads all content JSON under a root directory into typed defs and
## cross-validates references. See docs/content-schema.md.

const CANONICAL_TAGS: Array[String] = [
	"trade", "military", "religious", "industrial", "cultural", "science", "infrastructure",
]
## One per event; cancelled by developments listing them in `cancels` (GDD 4.4).
const CANONICAL_HAZARDS: Array[String] = [
	"flood", "fire", "disease", "famine", "riot", "raid", "pollution", "collapse",
]
## The whole resource vocabulary (GDD 3): two resources plus one meter per
## active demand, and nothing else. The population LEVEL is derived from the
## count, so content may read it but never write it.
const READABLE_RESOURCES: Array[String] = ["population_count", "population_level", "budget"]
const WRITABLE_RESOURCES: Array[String] = ["population_count", "budget"]

var cards: Dictionary = {}         # id -> CardDef
var events: Dictionary = {}        # id -> EventDef
var interactions: Dictionary = {}  # id -> InteractionDef
var policies: Dictionary = {}      # id -> PolicyDef
var ages: Dictionary = {}          # id -> AgeDef
## Global tuning, including the set of demands itself (content-schema.md).
## Never null: falls back to RulesDef.defaults() so in-code fixtures work.
var rules: RulesDef = RulesDef.defaults()
var load_errors: Array[String] = []


static func load_from_dir(root: String = "res://content") -> ContentDB:
	var db := ContentDB.new()
	db._load_rules(root.path_join("rules.json"))
	for path: String in db._scan_json(root.path_join("cards")):
		db._load_one(path, "card")
	for path: String in db._scan_json(root.path_join("events")):
		db._load_one(path, "event")
	for path: String in db._scan_json(root.path_join("interactions")):
		db._load_one(path, "interaction")
	for path: String in db._scan_json(root.path_join("policies")):
		db._load_one(path, "policy")
	for path: String in db._scan_json(root.path_join("ages")):
		db._load_one(path, "age")
	return db


func get_card(id: String) -> CardDef:
	if not cards.has(id):
		push_error("Unknown card id: " + id)
		return null
	return cards[id]


func get_event(id: String) -> EventDef:
	if not events.has(id):
		push_error("Unknown event id: " + id)
		return null
	return events[id]


func get_interaction(id: String) -> InteractionDef:
	if not interactions.has(id):
		push_error("Unknown interaction id: " + id)
		return null
	return interactions[id]


func get_policy(id: String) -> PolicyDef:
	if not policies.has(id):
		push_error("Unknown policy id: " + id)
		return null
	return policies[id]


func get_age(id: String) -> AgeDef:
	if not ages.has(id):
		push_error("Unknown age id: " + id)
		return null
	return ages[id]


## Candidate pressure events for a demand at one severity, restricted to the
## events authored for an age so an era's crises stay era-appropriate
## (GDD 4.0 Consequences). Sorted for determinism — the caller picks with the
## `events` RNG stream.
func pressure_events(demand_id: String, severity: String, age_id: String) -> Array[String]:
	var result: Array[String] = []
	for event_id: String in events:
		var event: EventDef = events[event_id]
		if event.demand == demand_id and event.severity == severity and event.age_id == age_id:
			result.append(event_id)
	result.sort()
	return result


## Full content validation. Returns a list of human-readable errors
## (empty = content is consistent). Includes load errors.
func validate() -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(load_errors)
	_validate_rules(errors)
	_validate_cards(errors)
	_validate_events(errors)
	_validate_interactions(errors)
	_validate_policies(errors)
	_validate_ages(errors)
	_validate_age_chains(errors)
	_validate_reachability(errors)
	_validate_prereq_cycles(errors)
	_validate_supersession_cycles(errors)
	_validate_demand_coverage(errors)
	return errors


## The demand vocabulary and the population/growth tables (content-schema.md).
func _validate_rules(errors: Array[String]) -> void:
	var ctx: String = "rules.json"
	if rules.demands.is_empty():
		errors.append("%s: no demands defined" % ctx)
	var seen: Dictionary = {}
	for demand: DemandDef in rules.demands:
		if demand.id == "":
			errors.append("%s: demand with no id" % ctx)
		if seen.has(demand.id):
			errors.append("%s: duplicate demand \"%s\"" % [ctx, demand.id])
		seen[demand.id] = true
		if rules.catastrophe_for(demand.id) <= rules.threshold_for(demand.id):
			errors.append("%s: demand \"%s\" catastrophe value is not above its threshold" % [
				ctx, demand.id,
			])
	if rules.population_levels.is_empty():
		errors.append("%s: population_levels is empty" % ctx)
	for i: int in range(1, rules.population_levels.size()):
		if rules.population_levels[i] <= rules.population_levels[i - 1]:
			errors.append("%s: population_levels is not strictly increasing at index %d" % [ctx, i])
	if rules.growth_by_demands_over_threshold.is_empty():
		errors.append("%s: growth_by_demands_over_threshold is empty" % ctx)


## Every demand must have somewhere to send its pressure: from the age that
## activates it onward, each age needs at least one emergency and one
## catastrophe event for it (content-schema.md), or upkeep would silently have
## nothing to shuffle when the city goes into the red.
##
## Checked per age CHAIN, since a demand stays active for the rest of the save
## it appears in and a save only ever plays one chain.
func _validate_demand_coverage(errors: Array[String]) -> void:
	for chain: Array in _age_chains():
		for i: int in chain.size():
			var demand_id: String = (ages[chain[i]] as AgeDef).activates_demand
			if demand_id == "" or not rules.has_demand(demand_id):
				continue  # already reported against the age
			for j: int in range(i, chain.size()):
				var age_id: String = chain[j]
				for severity: String in [EventDef.SEVERITY_EMERGENCY, EventDef.SEVERITY_CATASTROPHE]:
					if pressure_events(demand_id, severity, age_id).is_empty():
						errors.append("demand %s: no %s event in age %s (active from %s)" % [
							demand_id, severity, age_id, chain[i],
						])


## Every age chain in the content, each as an ordered array of age ids. A chain
## starts at an age no other age names as its `next_age`.
func _age_chains() -> Array[Array]:
	var has_predecessor: Dictionary = {}
	for age_id: String in ages:
		var next_id: String = (ages[age_id] as AgeDef).next_age
		if next_id != "":
			has_predecessor[next_id] = true
	var chains: Array[Array] = []
	for age_id: String in ages:
		if has_predecessor.has(age_id):
			continue
		var chain: Array[String] = []
		var current: String = age_id
		while current != "" and ages.has(current) and current not in chain:
			chain.append(current)
			current = (ages[current] as AgeDef).next_age
		chains.append(chain)
	return chains


## Cards that are only ever reached by supersession (GDD 4.6): they are placed
## in the city by a predecessor, never drawn, so they are exempt from the
## reachability check and must not sit in any base deck.
func _supersession_targets() -> Dictionary:
	var targets: Dictionary = {}
	for card_id: String in cards:
		for successor_id: String in (cards[card_id] as CardDef).superseded_by.values():
			targets[successor_id] = true
	return targets


# --- loading ---------------------------------------------------------------

func _load_rules(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		load_errors.append("%s: missing or unreadable (global rules)" % path)
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		load_errors.append("%s: invalid JSON" % path)
		return
	rules = RulesDef.from_dict(parsed)


func _scan_json(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				result.append_array(_scan_json(full))
		elif entry.ends_with(".json"):
			result.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()  # deterministic load order
	return result


func _load_one(path: String, kind: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		load_errors.append("%s: empty or unreadable" % path)
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		load_errors.append("%s: invalid JSON" % path)
		return
	var d: Dictionary = parsed
	var expected_id: String = path.get_file().get_basename()
	var actual_id: String = String(d.get("id", ""))
	if actual_id != expected_id:
		load_errors.append("%s: id \"%s\" does not match filename" % [path, actual_id])
		return
	match kind:
		"card":
			var card: CardDef = CardDef.from_dict(d)
			card.age_id = path.get_base_dir().get_file()
			if cards.has(card.id):
				load_errors.append("%s: duplicate card id" % path)
			cards[card.id] = card
		"event":
			var event: EventDef = EventDef.from_dict(d)
			event.age_id = path.get_base_dir().get_file()
			if events.has(event.id):
				load_errors.append("%s: duplicate event id" % path)
			events[event.id] = event
		"interaction":
			if interactions.has(actual_id):
				load_errors.append("%s: duplicate interaction id" % path)
			interactions[actual_id] = InteractionDef.from_dict(d)
		"policy":
			if policies.has(actual_id):
				load_errors.append("%s: duplicate policy id" % path)
			policies[actual_id] = PolicyDef.from_dict(d)
		"age":
			if ages.has(actual_id):
				load_errors.append("%s: duplicate age id" % path)
			ages[actual_id] = AgeDef.from_dict(d)


# --- validation ------------------------------------------------------------

func _new_refs() -> Dictionary:
	return {"interactions": [], "policies": [], "cards": [], "events": []}


func _check_refs(refs: Dictionary, context: String, errors: Array[String]) -> void:
	for interaction_id: String in refs["interactions"]:
		if not interactions.has(interaction_id):
			errors.append("%s: unknown interaction \"%s\"" % [context, interaction_id])
	for policy_id: String in refs["policies"]:
		if not policies.has(policy_id):
			errors.append("%s: unknown policy \"%s\"" % [context, policy_id])
	for card_id: String in refs["cards"]:
		if not cards.has(card_id):
			errors.append("%s: unknown card \"%s\"" % [context, card_id])
	for event_id: String in refs["events"]:
		if not events.has(event_id):
			errors.append("%s: unknown event \"%s\"" % [context, event_id])


func _effects_refs(effects: Array[EffectDef], refs: Dictionary) -> void:
	for effect: EffectDef in effects:
		effect.collect_refs(refs)


## Every `demand` field on an effect, and every resource an effect writes, must
## be one the engine can actually apply.
func _check_effect_vocabulary(effects: Array[EffectDef], ctx: String,
		errors: Array[String]) -> void:
	for effect: EffectDef in effects:
		if not effect.is_instant() and not effect.is_passive():
			errors.append("%s: unknown effect type \"%s\"" % [ctx, effect.type])
			continue
		match effect.type:
			"demand_delta", "demand_modifier", "demand_modifier_per_tag":
				if not rules.has_demand(effect.demand):
					errors.append("%s: %s names unknown demand \"%s\"" % [
						ctx, effect.type, effect.demand,
					])
				if effect.type == "demand_modifier_per_tag" and effect.tag not in CANONICAL_TAGS:
					errors.append("%s: demand_modifier_per_tag has non-canonical tag \"%s\"" % [
						ctx, effect.tag,
					])
			"resource_delta":
				if effect.resource not in WRITABLE_RESOURCES:
					errors.append("%s: resource_delta cannot write \"%s\"" % [ctx, effect.resource])


## Every `demand` a condition compares against must exist.
func _check_condition_vocabulary(condition: ConditionDef, ctx: String,
		errors: Array[String]) -> void:
	if condition == null:
		return
	match condition.type:
		"demand", "demand_growth":
			if not rules.has_demand(condition.demand):
				errors.append("%s: condition %s names unknown demand \"%s\"" % [
					ctx, condition.type, condition.demand,
				])
		"resource":
			if condition.resource not in READABLE_RESOURCES:
				errors.append("%s: condition reads unknown resource \"%s\"" % [
					ctx, condition.resource,
				])
		"all_of", "any_of":
			for sub: ConditionDef in condition.conditions:
				_check_condition_vocabulary(sub, ctx, errors)
		"not":
			_check_condition_vocabulary(condition.condition, ctx, errors)


func _validate_cards(errors: Array[String]) -> void:
	var successor_targets: Dictionary = _supersession_targets()
	for card_id: String in cards:
		var card: CardDef = cards[card_id]
		var ctx: String = "card " + card_id
		if card.display_name.strip_edges() == "":
			errors.append("%s: missing display name" % ctx)
		if card.flavor.strip_edges() == "":
			errors.append("%s: missing flavor text" % ctx)
		if card.cost < 0:
			errors.append("%s: negative cost" % ctx)
		if card.cost == 0 and not successor_targets.has(card_id):
			errors.append("%s: zero cost is reserved for automatic successor cards" % ctx)
		if card.cost > 12:
			errors.append("%s: cost %d exceeds the authored balance range" % [ctx, card.cost])
		if card.category != CardDef.CATEGORY_DEVELOPMENT and card.category != CardDef.CATEGORY_ACTION:
			errors.append("%s: invalid category \"%s\"" % [ctx, card.category])
		for tag: String in card.tags:
			if tag not in CANONICAL_TAGS:
				errors.append("%s: non-canonical tag \"%s\"" % [ctx, tag])
		if card.category == CardDef.CATEGORY_ACTION:
			if card.effects.is_empty():
				errors.append("%s: action card has no effects" % ctx)
			if not card.tags.is_empty():
				errors.append("%s: action cards must not have tags" % ctx)
			if not card.cancels.is_empty():
				errors.append("%s: only developments may cancel hazards" % ctx)
			if card.hand_limit_bonus != 0:
				errors.append("%s: only developments may carry hand_limit_bonus" % ctx)
			if not card.superseded_by.is_empty():
				errors.append("%s: superseded_by is for developments only" % ctx)
			for effect: EffectDef in card.effects:
				if effect.is_passive():
					errors.append("%s: action cards must not have passive effects (%s)" % [ctx, effect.type])
		for hazard: String in card.cancels:
			if hazard not in CANONICAL_HAZARDS:
				errors.append("%s: non-canonical cancelled hazard \"%s\"" % [ctx, hazard])
		if card.hand_limit_bonus < 0:
			errors.append("%s: negative hand_limit_bonus" % ctx)
		if card.category == CardDef.CATEGORY_ACTION and not card.demands.is_empty():
			errors.append("%s: action cards move demands with a demand_delta effect, not a demands map" % ctx)
		for demand_id: String in card.demands:
			if not rules.has_demand(demand_id):
				errors.append("%s: printed value for unknown demand \"%s\"" % [ctx, demand_id])
		if card.is_development() and card.tags.is_empty():
			errors.append("%s: development has no interaction tags" % ctx)
		var refs: Dictionary = _new_refs()
		(refs["cards"] as Array).append_array(card.prerequisites)
		(refs["cards"] as Array).append_array(card.inject_main)
		(refs["events"] as Array).append_array(card.inject_events)
		_effects_refs(card.effects, refs)
		for successor_age_id: String in card.superseded_by:
			var successor_id: String = card.successor_for(successor_age_id)
			var sctx: String = "%s superseded_by \"%s\"" % [ctx, successor_age_id]
			if not ages.has(successor_age_id):
				errors.append("%s: unknown age id" % sctx)
			(refs["cards"] as Array).append(successor_id)
			if successor_id == card.id:
				errors.append("%s: card supersedes itself" % sctx)
			elif cards.has(successor_id):
				var successor: CardDef = cards[successor_id]
				if not successor.is_development():
					errors.append("%s: successor \"%s\" is not a development" % [sctx, successor_id])
				if ages.has(successor_age_id) and successor.age_id != successor_age_id:
					errors.append("%s: successor \"%s\" lives in age \"%s\"" % [
						sctx, successor_id, successor.age_id,
					])
		_check_refs(refs, ctx, errors)
		_check_effect_vocabulary(card.effects, ctx, errors)
		for injected_id: String in card.inject_main:
			if cards.has(injected_id) and (cards[injected_id] as CardDef).age_id != card.age_id:
				errors.append("%s: injects cross-age card \"%s\"" % [ctx, injected_id])


func _validate_events(errors: Array[String]) -> void:
	for event_id: String in events:
		var event: EventDef = events[event_id]
		var ctx: String = "event " + event_id
		if event.title.strip_edges() == "":
			errors.append("%s: missing title" % ctx)
		if event.text.strip_edges() == "":
			errors.append("%s: missing situation text" % ctx)
		if event.options.is_empty():
			errors.append("%s: needs at least one choice" % ctx)
		if event.hazard != "" and event.hazard not in CANONICAL_HAZARDS:
			errors.append("%s: non-canonical hazard \"%s\"" % [ctx, event.hazard])
		_validate_pressure_fields(event, ctx, errors)
		var refs: Dictionary = _new_refs()
		if event.trigger != null:
			event.trigger.collect_refs(refs)
		var unconditional: int = 0
		for option: EventOptionDef in event.options:
			if option.requires_development == "":
				unconditional += 1
			else:
				(refs["cards"] as Array).append(option.requires_development)
			_effects_refs(option.effects, refs)
			_check_effect_vocabulary(option.effects, ctx, errors)
			for effect: EffectDef in option.effects:
				if effect.is_passive():
					errors.append("%s: event options must use instant effects only (%s)" % [ctx, effect.type])
		if not event.options.is_empty() and unconditional == 0:
			# Conditional options are strictly additional (GDD 4.4) — an event
			# whose every option needs a development can become unresolvable.
			errors.append("%s: every option is gated on a development" % ctx)
		_check_refs(refs, ctx, errors)
		_check_condition_vocabulary(event.trigger, ctx, errors)


## `demand` + `severity` are the pair that makes an event a pressure card
## (content-schema.md). One without the other is always an authoring slip.
func _validate_pressure_fields(event: EventDef, ctx: String, errors: Array[String]) -> void:
	var severities: Array[String] = [EventDef.SEVERITY_EMERGENCY, EventDef.SEVERITY_CATASTROPHE]
	if event.severity != "" and event.severity not in severities:
		errors.append("%s: unknown severity \"%s\"" % [ctx, event.severity])
	if event.demand != "" and not rules.has_demand(event.demand):
		errors.append("%s: names unknown demand \"%s\"" % [ctx, event.demand])
	if event.severity != "" and event.demand == "":
		errors.append("%s: %s severity without a demand" % [ctx, event.severity])
	if event.demand != "" and event.severity == "":
		errors.append("%s: names a demand but no severity" % ctx)


func _validate_interactions(errors: Array[String]) -> void:
	for interaction_id: String in interactions:
		var interaction: InteractionDef = interactions[interaction_id]
		var ctx: String = "interaction " + interaction_id
		if interaction.display_name.strip_edges() == "":
			errors.append("%s: missing display name" % ctx)
		if interaction.description.strip_edges() == "":
			errors.append("%s: missing description" % ctx)
		if interaction.threshold == null:
			errors.append("%s: missing threshold" % ctx)
		var refs: Dictionary = _new_refs()
		if interaction.threshold != null:
			interaction.threshold.collect_refs(refs)
		_effects_refs(interaction.effects, refs)
		_check_refs(refs, ctx, errors)
		_check_effect_vocabulary(interaction.effects, ctx, errors)
		_check_condition_vocabulary(interaction.threshold, ctx, errors)


func _validate_policies(errors: Array[String]) -> void:
	for policy_id: String in policies:
		var policy: PolicyDef = policies[policy_id]
		var ctx: String = "policy " + policy_id
		if policy.display_name.strip_edges() == "":
			errors.append("%s: missing display name" % ctx)
		if policy.description.strip_edges() == "":
			errors.append("%s: missing description" % ctx)
		var refs: Dictionary = _new_refs()
		if policy.unlock != null:
			policy.unlock.collect_refs(refs)
		_effects_refs(policy.effects, refs)
		_check_refs(refs, ctx, errors)
		_check_effect_vocabulary(policy.effects, ctx, errors)
		_check_condition_vocabulary(policy.unlock, ctx, errors)
		for demand_id: String in policy.swap_cost_demands:
			if not rules.has_demand(demand_id):
				errors.append("%s: swap cost names unknown demand \"%s\"" % [ctx, demand_id])


func _validate_ages(errors: Array[String]) -> void:
	if ages.is_empty():
		errors.append("no age definitions found")
	# One demand activates per age and never deactivates (GDD 4.0) — activating
	# the same demand twice in one chain would silently do nothing the second
	# time. Separate chains are alternative saves and may reuse a demand.
	for chain: Array in _age_chains():
		var activated_by: Dictionary = {}
		for age_id: String in chain:
			var demand_id: String = (ages[age_id] as AgeDef).activates_demand
			if demand_id == "":
				continue
			if activated_by.has(demand_id):
				errors.append("age %s: demand \"%s\" is already activated by age %s" % [
					age_id, demand_id, activated_by[demand_id],
				])
			activated_by[demand_id] = age_id
	for age_id: String in ages:
		var age: AgeDef = ages[age_id]
		var ctx: String = "age " + age_id
		if age.total_turns() <= 0:
			errors.append("%s: non-positive turn count" % ctx)
		if age.activates_demand == "":
			errors.append("%s: no activates_demand" % ctx)
		elif not rules.has_demand(age.activates_demand):
			errors.append("%s: activates unknown demand \"%s\"" % [ctx, age.activates_demand])
		if age.population_growth_base <= 0:
			errors.append("%s: non-positive population_growth_base" % ctx)
		var age_cards: Array[CardDef] = []
		var action_count: int = 0
		var mitigating_count: int = 0
		var aggravating_count: int = 0
		for card_id: String in cards:
			var candidate: CardDef = cards[card_id]
			if candidate.age_id != age_id:
				continue
			age_cards.append(candidate)
			if candidate.category == CardDef.CATEGORY_ACTION:
				action_count += 1
			elif age.activates_demand != "":
				var contribution: int = int(candidate.demands.get(age.activates_demand, 0))
				if contribution < 0:
					mitigating_count += 1
				elif contribution > 0:
					aggravating_count += 1
		if age_cards.size() < 50:
			errors.append("%s: only %d cards; authored target is at least 50" % [
				ctx, age_cards.size(),
			])
		if action_count < 5:
			errors.append("%s: only %d action cards; needs at least 5" % [ctx, action_count])
		if mitigating_count < 6:
			errors.append("%s: only %d developments mitigate its activated demand \"%s\"" % [
				ctx, mitigating_count, age.activates_demand,
			])
		if aggravating_count < 3:
			errors.append("%s: only %d developments aggravate its activated demand \"%s\"" % [
				ctx, aggravating_count, age.activates_demand,
			])
		if age.base_deck.size() < 20 or age.base_deck.size() > 45:
			errors.append("%s: base_deck size %d is outside the authored range 20..45" % [
				ctx, age.base_deck.size(),
			])
		if age.base_events.size() < 10:
			errors.append("%s: needs at least 10 ordinary base events" % ctx)
		if age.forced_events.size() < 2:
			errors.append("%s: needs at least 2 forced historical pressures" % ctx)
		var successors: Dictionary = _supersession_targets()
		var seen_deck: Dictionary = {}
		for card_id: String in age.base_deck:
			if not cards.has(card_id):
				errors.append("%s: unknown base_deck card \"%s\"" % [ctx, card_id])
			if seen_deck.has(card_id):
				errors.append("%s: duplicate base_deck card \"%s\"" % [ctx, card_id])
			if successors.has(card_id):
				errors.append("%s: base_deck card \"%s\" is a supersession successor and is never drawn" % [
					ctx, card_id,
				])
			seen_deck[card_id] = true
		if age.next_age != "" and not ages.has(age.next_age):
			errors.append("%s: unknown next_age \"%s\"" % [ctx, age.next_age])
		for event_id: String in age.base_events:
			if not events.has(event_id):
				errors.append("%s: unknown base_event \"%s\"" % [ctx, event_id])
			elif (events[event_id] as EventDef).severity != "":
				# Pressure cards enter the deck through demand pressure only
				# (GDD 4.0) — seeding one would hand out a crisis for free.
				errors.append("%s: base_event \"%s\" is a %s pressure card" % [
					ctx, event_id, (events[event_id] as EventDef).severity,
				])
		for entry: Dictionary in age.forced_events:
			var event_id: String = String(entry.get("event", ""))
			var turn: int = int(entry.get("turn", -1))
			if not events.has(event_id):
				errors.append("%s: unknown forced event \"%s\"" % [ctx, event_id])
			if turn < 1 or turn > age.total_turns():
				errors.append("%s: forced event \"%s\" scheduled outside age (turn %d)" % [ctx, event_id, turn])


## Walks the next_age chain from every age and rejects any revisit (cycle).
func _validate_age_chains(errors: Array[String]) -> void:
	for age_id: String in ages:
		var visited: Dictionary = {}
		var current: String = age_id
		while current != "" and ages.has(current):
			if visited.has(current):
				errors.append("age %s: next_age chain revisits \"%s\" (cycle)" % [age_id, current])
				break
			visited[current] = true
			current = (ages[current] as AgeDef).next_age


## Every card and event must be reachable: present in an age's base pools,
## or injected by something itself reachable (cards, event options), or
## injected by an interaction/policy effect (statically assumed reachable).
func _validate_reachability(errors: Array[String]) -> void:
	var reachable_cards: Dictionary = {}
	var reachable_events: Dictionary = {}
	var frontier_cards: Array[String] = []
	var frontier_events: Array[String] = []

	for age_id: String in ages:
		var age: AgeDef = ages[age_id]
		frontier_cards.append_array(age.base_deck)
		frontier_events.append_array(age.base_events)
		for entry: Dictionary in age.forced_events:
			frontier_events.append(String(entry.get("event", "")))

	# Pressure cards reach the deck through demand pressure rather than a pool
	# (GDD 4.0); _validate_demand_coverage is what checks they exist.
	for event_id: String in events:
		if (events[event_id] as EventDef).severity != "":
			frontier_events.append(event_id)

	# Interactions and policies can inject regardless of state; count their
	# injections as reachable sources.
	var ambient_effects: Array[EffectDef] = []
	for interaction_id: String in interactions:
		ambient_effects.append_array((interactions[interaction_id] as InteractionDef).effects)
	for policy_id: String in policies:
		ambient_effects.append_array((policies[policy_id] as PolicyDef).effects)
	for effect: EffectDef in ambient_effects:
		if effect.type == "inject_main":
			frontier_cards.append_array(effect.cards)
		elif effect.type == "inject_events":
			frontier_events.append_array(effect.events)

	while not frontier_cards.is_empty() or not frontier_events.is_empty():
		if not frontier_cards.is_empty():
			var card_id: String = frontier_cards.pop_back()
			if reachable_cards.has(card_id) or not cards.has(card_id):
				continue
			reachable_cards[card_id] = true
			var card: CardDef = cards[card_id]
			frontier_cards.append_array(card.inject_main)
			frontier_events.append_array(card.inject_events)
			# A successor is reached by supersession rather than by draw.
			for successor_id: String in card.superseded_by.values():
				frontier_cards.append(successor_id)
			for effect: EffectDef in card.effects:
				if effect.type == "inject_main":
					frontier_cards.append_array(effect.cards)
				elif effect.type == "inject_events":
					frontier_events.append_array(effect.events)
		else:
			var event_id: String = frontier_events.pop_back()
			if reachable_events.has(event_id) or not events.has(event_id):
				continue
			reachable_events[event_id] = true
			var event: EventDef = events[event_id]
			for option: EventOptionDef in event.options:
				for effect: EffectDef in option.effects:
					if effect.type == "inject_main":
						frontier_cards.append_array(effect.cards)
					elif effect.type == "inject_events":
						frontier_events.append_array(effect.events)

	for card_id: String in cards:
		if not reachable_cards.has(card_id):
			errors.append("card %s: unreachable (not in any base deck and never injected)" % card_id)
	for event_id: String in events:
		if not reachable_events.has(event_id):
			errors.append("event %s: unreachable (not in any base pool and never injected)" % event_id)


## Walks the supersession chain from every card and rejects any revisit — a
## cycle would make a structure loop between forms forever (GDD 4.6).
func _validate_supersession_cycles(errors: Array[String]) -> void:
	for card_id: String in cards:
		var visited: Dictionary = {card_id: true}
		var frontier: Array[String] = []
		frontier.append_array((cards[card_id] as CardDef).superseded_by.values())
		while not frontier.is_empty():
			var next_id: String = frontier.pop_back()
			if visited.has(next_id):
				errors.append("card %s: supersession chain revisits \"%s\" (cycle)" % [
					card_id, next_id,
				])
				break
			visited[next_id] = true
			if cards.has(next_id):
				frontier.append_array((cards[next_id] as CardDef).superseded_by.values())


func _validate_prereq_cycles(errors: Array[String]) -> void:
	const UNVISITED: int = 0
	const IN_PROGRESS: int = 1
	const DONE: int = 2
	var mark: Dictionary = {}
	for card_id: String in cards:
		mark[card_id] = UNVISITED
	for card_id: String in cards:
		if mark[card_id] == UNVISITED:
			_prereq_dfs(card_id, mark, errors)


func _prereq_dfs(card_id: String, mark: Dictionary, errors: Array[String]) -> void:
	mark[card_id] = 1  # IN_PROGRESS
	var card: CardDef = cards[card_id]
	for prereq_id: String in card.prerequisites:
		if not cards.has(prereq_id):
			continue  # dangling ref already reported
		if int(mark[prereq_id]) == 1:
			errors.append("card %s: prerequisite cycle involving \"%s\"" % [card_id, prereq_id])
		elif int(mark[prereq_id]) == 0:
			_prereq_dfs(prereq_id, mark, errors)
	mark[card_id] = 2  # DONE
