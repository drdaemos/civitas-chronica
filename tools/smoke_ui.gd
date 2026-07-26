extends SceneTree

## Headless smoke test for the game glue layer (game/ autoloads + save +
## profile). Exercises GameController end to end: new_game, playing cards,
## ending turns, resolving events, hand-limit discards, automatic age
## transitions, and verifying the save snapshot and the account-level profile
## on disk.
## Run: godot --headless --path . --script res://tools/smoke_ui.gd

var _failures: int = 0
var _transitions_applied: int = 0


func _initialize() -> void:
	# Start from a clean slot so the "snapshot written" check is meaningful.
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	cleaner.free()

	var gc: GameController = load("res://game/game_controller.gd").new() as GameController
	get_root().add_child(gc)

	gc.new_game(12345)
	_check(gc.state != null, "new_game produced a state")
	_check(gc.state.turn_number == 1, "first turn started")
	# Events resolve before the player draws (GDD 3), so turn 1 may open on an
	# event screen instead of a hand.
	_check(not gc.state.hand.is_empty() or gc.state.pending_event != "",
			"turn 1 opens on a hand or an event")
	_check(FileAccess.file_exists(SaveManager.SAVE_PATH), "save snapshot written at TURN_START")

	var loaded: GameState = gc.saves.load_game()
	_check(loaded != null and loaded.turn_number == 1, "snapshot loads back as turn 1")

	var first_event: String = ""
	var interaction_seen: String = ""
	var save_existed_mid_run: bool = false
	var safety: int = 0
	gc.transition_completed.connect(_on_transition_completed)
	while gc.state != null and not gc.state.game_over and safety < 200:
		safety += 1
		if not save_existed_mid_run:
			save_existed_mid_run = FileAccess.file_exists(SaveManager.SAVE_PATH)
		# Events now arrive during upkeep, before the player acts (GDD 3), so a
		# pending event is answered at the top of the turn rather than the end.
		if gc.state.pending_event != "":
			if first_event == "":
				first_event = gc.state.pending_event
				_check(gc.profile.knows_event(first_event),
						"profile recorded fired event immediately (%s)" % first_event)
			gc.resolve_event(_first_available_option(gc))
			continue
		_play_affordable(gc)
		_discard_to_limit(gc)
		gc.end_turn()
		if interaction_seen == "" and not gc.state.active_interactions.is_empty():
			interaction_seen = gc.state.active_interactions[0]

	_check(gc.state.game_over, "run reached an outcome (outcome=%s, age=%s, turn %d, transitions=%d)" % [
		gc.state.outcome, gc.state.age_id, gc.state.turn_number, _transitions_applied,
	])
	_check(_transitions_applied == gc.state.completed_ages.size(),
			"every completed age emitted a transition report (%d reports, %d completed)" % [
				_transitions_applied, gc.state.completed_ages.size(),
			])
	var lost_early: bool = gc.state.outcome == GameState.OUTCOME_LOST_CATASTROPHE \
			or gc.state.outcome == GameState.OUTCOME_LOST_DEBT
	_check(not gc.state.completed_ages.is_empty() or lost_early,
			"completed an age transition or lost beforehand (completed_ages=%s, outcome=%s)" % [
				str(gc.state.completed_ages), gc.state.outcome,
			])
	_check(save_existed_mid_run, "save snapshot existed mid-run")
	_check(first_event != "", "at least one event fired during the run")
	if interaction_seen != "":
		_check(gc.profile.knows_interaction(interaction_seen),
				"profile recorded interaction discovery (%s)" % interaction_seen)
	_check(FileAccess.file_exists(ProfileManager.PROFILE_PATH), "profile.json exists on disk")

	# A fresh manager re-reads the file — discoveries persist beyond the run.
	var fresh := ProfileManager.new()
	fresh.load_profile()
	if first_event != "":
		_check(fresh.knows_event(first_event), "profile persists across reload from disk")
	fresh.free()

	if _failures == 0:
		print("smoke_ui: OK")
		quit(0)
	else:
		printerr("smoke_ui: %d failure(s)" % _failures)
		quit(1)


## The transition asks the player for nothing (GDD 4.8) — the controller runs
## it itself and the UI only receives the report.
func _on_transition_completed(report: TransitionReport) -> void:
	_transitions_applied += 1
	_check(report.to_age != "", "transition report names the new age (%s)" % report.to_age)


## The first option this city may actually pick — options gated on a
## development it does not have are hidden (GDD 4.4).
func _first_available_option(gc: GameController) -> int:
	var event: EventDef = gc.db.get_event(gc.state.pending_event)
	if event == null:
		return 0
	for i: int in event.options.size():
		if event.options[i].is_available(gc.state):
			return i
	return 0


## Mirrors the discard step the hand strip drives: dump the tail of the hand
## when it is over capacity, so the turn can actually end.
func _discard_to_limit(gc: GameController) -> void:
	var overflow: int = gc.hand_overflow()
	if overflow <= 0:
		return
	var doomed: Array[String] = gc.state.hand.slice(gc.state.hand.size() - overflow)
	var result: Dictionary = gc.discard_cards(doomed)
	if not bool(result.get("ok", false)):
		_check(false, "discard of %d over the hand limit refused: %s" % [
			overflow, String(result.get("reason", "")),
		])


## Greedily plays every card the current budget can afford (skipping cards
## whose play is refused, e.g. missing prerequisites).
func _play_affordable(gc: GameController) -> void:
	var refused: Array[String] = []
	var acted: bool = true
	while acted:
		acted = false
		var pipeline: ModifierPipeline = gc.current_pipeline()
		for card_id: String in gc.state.hand.duplicate():
			if card_id in refused:
				continue
			var card: CardDef = gc.db.get_card(card_id)
			if card == null:
				continue
			if pipeline.cost_of(card) > gc.state.current_budget:
				continue
			var result: Dictionary = gc.play_card(card_id)
			if bool(result.get("ok", false)):
				acted = true
				break
			refused.append(card_id)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok: " + label)
	else:
		_failures += 1
		printerr("  FAIL: " + label)
