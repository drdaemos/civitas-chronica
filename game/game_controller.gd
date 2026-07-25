class_name GameController
extends Node

## Autoload "Game". Owns the ContentDB, GameState and TurnEngine; exposes a
## small action API to the UI and re-emits sim results as signals. Also the
## glue to persistence: run snapshots (Saves) are written exactly once per
## turn, at TURN_START (TDD 4.2), and account-level discoveries (Profile)
## are recorded the moment they happen (GDD unified learning contract).
##
## Works both as an autoload and when instantiated directly (headless smoke
## tests): if the Saves/Profile autoloads are absent it creates its own
## manager children.

signal state_changed
signal domain_events(events: Array[Dictionary])
signal game_ended(outcome: String, score: Dictionary)
signal age_ended(from_age: String, to_age: String)

const DEFAULT_AGE_ID: String = "age1"

var db: ContentDB = null
var state: GameState = null
var engine: TurnEngine = null
var saves: SaveManager = null
var profile: ProfileManager = null
var last_score: Dictionary = {}

var _pending_event_first_sight: bool = true


func _ready() -> void:
	_ensure_setup()


## Idempotent bootstrap. Called from _ready, and lazily from every public
## entry point, because _ready does not fire for nodes added during a
## SceneTree script's _initialize (headless smoke tests).
func _ensure_setup() -> void:
	if db == null:
		db = ContentDB.load_from_dir()
		for error: String in db.load_errors:
			push_error("GameController: content load error: " + error)
	if saves == null:
		if is_inside_tree():
			saves = get_node_or_null("/root/Saves") as SaveManager
		if saves == null:
			saves = SaveManager.new()
			saves.name = "Saves"
			add_child(saves)
	if profile == null:
		if is_inside_tree():
			profile = get_node_or_null("/root/Profile") as ProfileManager
		if profile == null:
			profile = ProfileManager.new()
			profile.name = "Profile"
			add_child(profile)
			profile.load_profile()  # its _ready may not have fired yet


## Starts a fresh run and its first turn, then snapshots (save happens at
## TURN_START only).
func new_game(seed_value: int = 0) -> void:
	_ensure_setup()
	state = GameSetup.new_game(db, DEFAULT_AGE_ID, seed_value)
	engine = TurnEngine.new(db, state)
	last_score = {}
	_pending_event_first_sight = true
	var events: Array[Dictionary] = engine.start_turn()
	_process_domain_events(events)
	if not state.game_over:
		saves.save(state)
	domain_events.emit(events)
	state_changed.emit()
	_finish_if_over(events)


## Resumes from the slot-1 snapshot. Snapshots are taken at TURN_START, so
## the loaded state is already mid-turn (hand drawn, no pending event).
func continue_game() -> bool:
	_ensure_setup()
	var loaded: GameState = saves.load_game()
	if loaded == null:
		return false
	state = loaded
	engine = TurnEngine.new(db, state)
	last_score = {}
	_pending_event_first_sight = false
	state_changed.emit()
	return true


func has_save() -> bool:
	_ensure_setup()
	return saves.has_save()


## Plays a card; returns the engine result {ok, reason, events} so the UI
## can surface refusal reasons.
func play_card(card_id: String) -> Dictionary:
	if engine == null:
		return _no_game()
	var result: Dictionary = engine.play_card(card_id)
	if bool(result.get("ok", false)):
		var events: Array[Dictionary] = []
		events.assign(result.get("events", []) as Array)
		_process_domain_events(events)
		domain_events.emit(events)
		state_changed.emit()
	return result


func end_turn() -> void:
	if engine == null or state == null or state.game_over or state.pending_event != "":
		return
	_advance(engine.end_turn())


func resolve_event(option_index: int) -> void:
	if engine == null or state == null or state.pending_event == "":
		return
	_advance(engine.resolve_event(option_index))


func adopt_policy(policy_id: String) -> Dictionary:
	if engine == null:
		return _no_game()
	var result: Dictionary = engine.adopt_policy(policy_id)
	if bool(result.get("ok", false)):
		state_changed.emit()
	return result


## The pending age transition's per-development decision list (see
## AgeTransition.decisions). Empty when no transition is pending.
func transition_decisions() -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	if state == null or db == null or not state.transition_pending:
		return empty
	return AgeTransition.decisions(state, db)


## Applies the player's Preserve/Adapt/Demolish choices (card_id -> choice),
## starts the new age's first turn, snapshots, and re-emits everything.
func apply_transition(choices: Dictionary) -> void:
	if engine == null or state == null or not state.transition_pending:
		return
	var events: Array[Dictionary] = AgeTransition.apply(state, db, choices)
	_process_domain_events(events)
	var next_events: Array[Dictionary] = engine.start_turn()
	_process_domain_events(next_events)
	events.append_array(next_events)
	if not state.game_over:
		saves.save(state)
	domain_events.emit(events)
	state_changed.emit()
	_finish_if_over(events)


## Effective-cost view over the current state; the UI must use this instead
## of reimplementing cost rules.
func current_pipeline() -> ModifierPipeline:
	if state == null:
		return ModifierPipeline.new()
	return ModifierPipeline.collect(state, db)


## True while the pending event is being seen for the first time ever
## (across all saves) — the UI hides the "seen before" hint in that case.
func is_pending_event_first_sight() -> bool:
	return _pending_event_first_sight


# --- private ----------------------------------------------------------------

## Shared tail for end_turn/resolve_event: if the turn actually completed
## (no pending event, not game over) the next turn starts immediately and
## the once-per-turn snapshot is written.
func _advance(events: Array[Dictionary]) -> void:
	_process_domain_events(events)
	if not state.game_over and state.pending_event == "":
		if state.transition_pending:
			# The age just ended: snapshot immediately — the transition_pending
			# state is serializable, so a player can quit mid-transition and
			# resume straight into the transition screen.
			saves.save(state)
		else:
			var next_events: Array[Dictionary] = engine.start_turn()
			_process_domain_events(next_events)
			events.append_array(next_events)
			if not state.game_over:
				saves.save(state)
	domain_events.emit(events)
	state_changed.emit()
	_finish_if_over(events)
	for ev: Dictionary in events:
		if String(ev.get("type", "")) == "age_ended":
			age_ended.emit(String(ev.get("from", "")), String(ev.get("to", "")))


func _finish_if_over(events: Array[Dictionary]) -> void:
	if state == null or not state.game_over:
		return
	last_score = _extract_score(events)
	saves.delete_save()  # the run is finished; discoveries live on in Profile
	game_ended.emit(state.outcome, last_score)


func _extract_score(events: Array[Dictionary]) -> Dictionary:
	for ev: Dictionary in events:
		if String(ev.get("type", "")) == "game_over":
			return ev.get("score", {}) as Dictionary
	return Scoring.score(state, db)


## Feeds account-level discovery (Profile) from domain events, immediately.
func _process_domain_events(events: Array[Dictionary]) -> void:
	for ev: Dictionary in events:
		match String(ev.get("type", "")):
			"interaction_activated":
				if bool(ev.get("first_discovery", false)):
					profile.record_interaction(String(ev.get("id", "")))
			"event_fired":
				var event_id: String = String(ev.get("id", ""))
				_pending_event_first_sight = not profile.knows_event(event_id)
				profile.record_event(event_id)


func _no_game() -> Dictionary:
	var empty: Array[Dictionary] = []
	return {"ok": false, "reason": "no game in progress", "events": empty}
