class_name ContentDB
extends RefCounted

## Loads all content JSON under a root directory into typed defs and
## cross-validates references. See docs/content-schema.md.

const CANONICAL_TAGS: Array[String] = [
	"trade", "military", "religious", "industrial", "cultural", "science", "infrastructure",
]

var cards: Dictionary = {}         # id -> CardDef
var events: Dictionary = {}        # id -> EventDef
var interactions: Dictionary = {}  # id -> InteractionDef
var policies: Dictionary = {}      # id -> PolicyDef
var ages: Dictionary = {}          # id -> AgeDef
var load_errors: Array[String] = []


static func load_from_dir(root: String = "res://content") -> ContentDB:
	var db := ContentDB.new()
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


## Full content validation. Returns a list of human-readable errors
## (empty = content is consistent). Includes load errors.
func validate() -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(load_errors)
	_validate_cards(errors)
	_validate_events(errors)
	_validate_interactions(errors)
	_validate_policies(errors)
	_validate_ages(errors)
	_validate_age_chains(errors)
	_validate_reachability(errors)
	_validate_prereq_cycles(errors)
	return errors


# --- loading ---------------------------------------------------------------

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


func _validate_cards(errors: Array[String]) -> void:
	for card_id: String in cards:
		var card: CardDef = cards[card_id]
		var ctx: String = "card " + card_id
		if card.category != CardDef.CATEGORY_DEVELOPMENT and card.category != CardDef.CATEGORY_ACTION:
			errors.append("%s: invalid category \"%s\"" % [ctx, card.category])
		for tag: String in card.tags:
			if tag not in CANONICAL_TAGS:
				errors.append("%s: non-canonical tag \"%s\"" % [ctx, tag])
		if card.category == CardDef.CATEGORY_ACTION:
			if not card.tags.is_empty():
				errors.append("%s: action cards must not have tags" % ctx)
			for effect: EffectDef in card.effects:
				if effect.is_passive():
					errors.append("%s: action cards must not have passive effects (%s)" % [ctx, effect.type])
		var refs: Dictionary = _new_refs()
		(refs["cards"] as Array).append_array(card.prerequisites)
		(refs["cards"] as Array).append_array(card.inject_main)
		(refs["events"] as Array).append_array(card.inject_events)
		_effects_refs(card.effects, refs)
		for variant_age_id: String in card.age_variants:
			_validate_age_variant(card, variant_age_id, ctx, refs, errors)
		_check_refs(refs, ctx, errors)
		for effect: EffectDef in card.effects:
			if not effect.is_instant() and not effect.is_passive():
				errors.append("%s: unknown effect type \"%s\"" % [ctx, effect.type])


func _validate_age_variant(card: CardDef, variant_age_id: String, ctx: String,
		refs: Dictionary, errors: Array[String]) -> void:
	var vctx: String = "%s age_variant \"%s\"" % [ctx, variant_age_id]
	if not ages.has(variant_age_id):
		errors.append("%s: unknown age id" % vctx)
	if card.category != CardDef.CATEGORY_DEVELOPMENT:
		errors.append("%s: age_variants are for developments only" % vctx)
	var variant: AgeVariantDef = card.age_variants[variant_age_id]
	for tag: String in variant.preserved_tags:
		if tag not in CANONICAL_TAGS:
			errors.append("%s: non-canonical preserved tag \"%s\"" % [vctx, tag])
	for tag: String in variant.adapted_tags:
		if tag not in CANONICAL_TAGS:
			errors.append("%s: non-canonical adapted tag \"%s\"" % [vctx, tag])
	var variant_effects: Array[EffectDef] = []
	variant_effects.append_array(variant.preserved_effects)
	variant_effects.append_array(variant.adapted_effects)
	for effect: EffectDef in variant_effects:
		if not effect.is_instant() and not effect.is_passive():
			errors.append("%s: unknown effect type \"%s\"" % [vctx, effect.type])
	_effects_refs(variant_effects, refs)


func _validate_events(errors: Array[String]) -> void:
	for event_id: String in events:
		var event: EventDef = events[event_id]
		var ctx: String = "event " + event_id
		if event.options.is_empty():
			errors.append("%s: has no options" % ctx)
		var refs: Dictionary = _new_refs()
		if event.trigger != null:
			event.trigger.collect_refs(refs)
		for option: EventOptionDef in event.options:
			_effects_refs(option.effects, refs)
			for effect: EffectDef in option.effects:
				if not effect.is_instant() and not effect.is_passive():
					errors.append("%s: unknown effect type \"%s\"" % [ctx, effect.type])
				elif effect.is_passive():
					errors.append("%s: event options must use instant effects only (%s)" % [ctx, effect.type])
		_check_refs(refs, ctx, errors)


func _validate_interactions(errors: Array[String]) -> void:
	for interaction_id: String in interactions:
		var interaction: InteractionDef = interactions[interaction_id]
		var ctx: String = "interaction " + interaction_id
		if interaction.threshold == null:
			errors.append("%s: missing threshold" % ctx)
		var refs: Dictionary = _new_refs()
		if interaction.threshold != null:
			interaction.threshold.collect_refs(refs)
		_effects_refs(interaction.effects, refs)
		_check_refs(refs, ctx, errors)
		for effect: EffectDef in interaction.effects:
			if not effect.is_instant() and not effect.is_passive():
				errors.append("%s: unknown effect type \"%s\"" % [ctx, effect.type])


func _validate_policies(errors: Array[String]) -> void:
	for policy_id: String in policies:
		var policy: PolicyDef = policies[policy_id]
		var ctx: String = "policy " + policy_id
		var refs: Dictionary = _new_refs()
		if policy.unlock != null:
			policy.unlock.collect_refs(refs)
		_effects_refs(policy.effects, refs)
		_check_refs(refs, ctx, errors)
		for effect: EffectDef in policy.effects:
			if not effect.is_instant() and not effect.is_passive():
				errors.append("%s: unknown effect type \"%s\"" % [ctx, effect.type])


func _validate_ages(errors: Array[String]) -> void:
	if ages.is_empty():
		errors.append("no age definitions found")
	for age_id: String in ages:
		var age: AgeDef = ages[age_id]
		var ctx: String = "age " + age_id
		if age.total_turns() <= 0:
			errors.append("%s: non-positive turn count" % ctx)
		var seen_deck: Dictionary = {}
		for card_id: String in age.base_deck:
			if not cards.has(card_id):
				errors.append("%s: unknown base_deck card \"%s\"" % [ctx, card_id])
			if seen_deck.has(card_id):
				errors.append("%s: duplicate base_deck card \"%s\"" % [ctx, card_id])
			seen_deck[card_id] = true
		if age.next_age != "" and not ages.has(age.next_age):
			errors.append("%s: unknown next_age \"%s\"" % [ctx, age.next_age])
		for event_id: String in age.base_events:
			if not events.has(event_id):
				errors.append("%s: unknown base_event \"%s\"" % [ctx, event_id])
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
