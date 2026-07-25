extends SceneTree

## Headless smoke test for the game glue layer (game/ autoloads + save +
## profile). Exercises GameController end to end: new_game, playing cards,
## ending turns, resolving events, age transitions (exercising all three of
## preserve/adapt/demolish), and verifying the save snapshot and the
## account-level profile on disk.
## Run: godot --headless --path . --script res://tools/smoke_ui.gd

var _failures: int = 0


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
	_check(not gc.state.hand.is_empty(), "opening hand drawn")
	_check(FileAccess.file_exists(SaveManager.SAVE_PATH), "save snapshot written at TURN_START")

	var loaded: GameState = gc.saves.load_game()
	_check(loaded != null and loaded.turn_number == 1, "snapshot loads back as turn 1")

	var first_event: String = ""
	var interaction_seen: String = ""
	var transitions_applied: int = 0
	var save_existed_mid_run: bool = false
	var safety: int = 0
	while gc.state != null and not gc.state.game_over and safety < 120:
		safety += 1
		if gc.state.transition_pending:
			save_existed_mid_run = save_existed_mid_run \
					or FileAccess.file_exists(SaveManager.SAVE_PATH)
			_apply_transition(gc)
			transitions_applied += 1
			continue
		_play_affordable(gc)
		gc.end_turn()
		if gc.state.pending_event != "":
			if first_event == "":
				first_event = gc.state.pending_event
				_check(gc.profile.knows_event(first_event),
						"profile recorded fired event immediately (%s)" % first_event)
			gc.resolve_event(0)
		if interaction_seen == "" and not gc.state.active_interactions.is_empty():
			interaction_seen = gc.state.active_interactions[0]
		if not save_existed_mid_run:
			save_existed_mid_run = FileAccess.file_exists(SaveManager.SAVE_PATH)

	_check(gc.state.game_over, "run reached an outcome (outcome=%s, age=%s, turn %d, transitions=%d)" % [
		gc.state.outcome, gc.state.age_id, gc.state.turn_number, transitions_applied,
	])
	var lost_early: bool = gc.state.outcome == GameState.OUTCOME_LOST_APPROVAL \
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


## Drives the pending age transition the way the transition screen would:
## builds choices from transition_decisions() exercising all three options —
## the LAST development is demolished, even-indexed developments adapt where
## a variant allows it, everything else is preserved.
func _apply_transition(gc: GameController) -> void:
	var decisions: Array[Dictionary] = gc.transition_decisions()
	var choices: Dictionary = {}
	for i: int in decisions.size():
		var decision: Dictionary = decisions[i]
		var card_id: String = String(decision.get("card_id", ""))
		if i == decisions.size() - 1:
			choices[card_id] = AgeTransition.CHOICE_DEMOLISH
		elif i % 2 == 0 and decision.get("adapt") is Dictionary:
			choices[card_id] = AgeTransition.CHOICE_ADAPT
		else:
			choices[card_id] = AgeTransition.CHOICE_PRESERVE
	var from_age: String = gc.state.age_id
	gc.apply_transition(choices)
	_check(not gc.state.transition_pending, "transition applied (from %s)" % from_age)
	_check(from_age in gc.state.completed_ages, "completed_ages records %s" % from_age)


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
