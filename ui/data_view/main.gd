extends Control

## Thin coordinator for the data-view screen. Major UI responsibilities live
## in focused components; this script only routes game state, domain events,
## and player intent between them and the Game autoload.

var _menu: MainMenu = null
var _game_layout: VBoxContainer = null
var _command_bar: CommandBar = null
var _workspace: CityWorkspace = null
var _sidebar: ChronicleSidebar = null
var _hand: HandPanel = null
var _event_overlay: EventOverlay = null
var _upkeep_overlay: UpkeepOverlay = null
var _tutorial_overlay: TutorialOverlay = null
var _transition_overlay: TransitionOverlay = null
var _game_over: GameOverPanel = null

var _discard_mode: bool = false
var _discard_selection: Array[String] = []
var _starting_new_game: bool = false
var _upkeep_before: Dictionary = {}
var _pending_upkeep_events: Array[Dictionary] = []


func _ready() -> void:
	UiStyle.install(self)
	_build_screen()
	_connect_ui()
	Game.state_changed.connect(_on_state_changed)
	Game.domain_events.connect(_on_domain_events)
	Game.game_ended.connect(_on_game_ended)
	Game.transition_completed.connect(_on_transition_completed)
	_show_menu()


func _build_screen() -> void:
	var background := ColorRect.new()
	background.color = UiStyle.BG_DEEP
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	_game_layout = VBoxContainer.new()
	_game_layout.add_theme_constant_override("separation", 10)
	margin.add_child(_game_layout)

	_command_bar = CommandBar.new()
	_game_layout.add_child(_command_bar)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	_game_layout.add_child(middle)
	_workspace = CityWorkspace.new()
	middle.add_child(_workspace)
	_sidebar = ChronicleSidebar.new()
	middle.add_child(_sidebar)
	_hand = HandPanel.new()
	_game_layout.add_child(_hand)

	_menu = MainMenu.new()
	add_child(_menu)
	_event_overlay = EventOverlay.new()
	add_child(_event_overlay)
	_upkeep_overlay = UpkeepOverlay.new()
	add_child(_upkeep_overlay)
	_tutorial_overlay = TutorialOverlay.new()
	add_child(_tutorial_overlay)
	_transition_overlay = TransitionOverlay.new()
	add_child(_transition_overlay)
	_game_over = GameOverPanel.new()
	add_child(_game_over)


func _connect_ui() -> void:
	_menu.new_game_requested.connect(_on_new_game)
	_menu.continue_requested.connect(_on_continue)
	_menu.quit_requested.connect(_on_quit)
	_sidebar.end_turn_requested.connect(_on_end_turn)
	_sidebar.cancel_discard_requested.connect(_on_cancel_discard)
	_hand.play_requested.connect(_on_play_card)
	_hand.discard_toggled.connect(_on_toggle_discard)
	_event_overlay.option_selected.connect(_on_resolve_event)
	_upkeep_overlay.dismissed.connect(_on_upkeep_dismissed)
	_game_over.menu_requested.connect(_show_menu)


func _show_menu() -> void:
	_menu.visible = true
	_menu.set_continue_available(Game.has_save())
	_game_layout.visible = false
	_hide_overlays()
	_discard_mode = false
	_discard_selection.clear()


func _show_game() -> void:
	_menu.visible = false
	_game_layout.visible = true
	_game_over.visible = false


func _hide_overlays() -> void:
	_event_overlay.visible = false
	_upkeep_overlay.visible = false
	_tutorial_overlay.visible = false
	_transition_overlay.visible = false
	_game_over.visible = false


func _refresh_all() -> void:
	var state: GameState = Game.state
	if state == null:
		return
	var pipeline: ModifierPipeline = Game.current_pipeline()
	var animate_before: Dictionary = (
		_upkeep_before if not _pending_upkeep_events.is_empty() else {}
	)
	_command_bar.refresh(state, Game.db, pipeline, animate_before)
	_workspace.refresh(state, Game.db)
	_hand.refresh(
		state, Game.db, pipeline, Game.hand_limit(), _discard_mode, _discard_selection)
	var blocked: bool = state.pending_event != "" or state.game_over \
			or state.transition_pending
	_sidebar.refresh(
		state, state.main_deck.size(), Game.hand_overflow(), _discard_mode,
		_discard_selection.size(), blocked, animate_before)
	var upkeep_waiting: bool = not _pending_upkeep_events.is_empty()
	if state.pending_event != "" and not state.transition_pending \
			and not state.game_over and not upkeep_waiting:
		_event_overlay.present(state, Game.db, Game.is_pending_event_first_sight())
	else:
		_event_overlay.dismiss()

	if not _pending_upkeep_events.is_empty():
		_upkeep_overlay.present(_pending_upkeep_events, state, Game.db)
		_pending_upkeep_events.clear()
	_upkeep_before.clear()


func _on_new_game() -> void:
	_sidebar.clear_log()
	_discard_mode = false
	_discard_selection.clear()
	_pending_upkeep_events.clear()
	_upkeep_before.clear()
	_show_game()
	_starting_new_game = true
	Game.new_game()
	_starting_new_game = false
	_tutorial_overlay.present()


func _on_continue() -> void:
	_sidebar.clear_log()
	if not Game.continue_game():
		_menu.set_continue_available(false)
		return
	_show_game()
	_sidebar.append_log("[color=#d1a85a][b]CHRONICLE RESUMED[/b][/color]")
	_refresh_all()


func _on_quit() -> void:
	get_tree().quit()


func _on_end_turn() -> void:
	if _discard_mode:
		var result: Dictionary = Game.discard_cards(_discard_selection.duplicate())
		if not bool(result.get("ok", false)):
			_sidebar.append_log("[color=#d9676e]Cannot discard: %s[/color]" % String(
				result.get("reason", "")))
			return
		_discard_mode = false
		_discard_selection.clear()
		_capture_upkeep_before()
		Game.end_turn()
		return
	if Game.hand_overflow() > 0:
		_discard_mode = true
		_discard_selection.clear()
		_refresh_all()
		return
	_capture_upkeep_before()
	Game.end_turn()


func _capture_upkeep_before() -> void:
	if Game.state == null:
		_upkeep_before.clear()
		return
	_upkeep_before = {
		"budget": Game.state.current_budget,
		"population": Game.state.population_count,
		"population_level": Game.state.population_level,
		"demands": Game.state.demands.duplicate(),
	}


func _on_cancel_discard() -> void:
	_discard_mode = false
	_discard_selection.clear()
	_refresh_all()


func _on_toggle_discard(card_id: String) -> void:
	if card_id in _discard_selection:
		_discard_selection.erase(card_id)
	elif _discard_selection.size() < Game.hand_overflow():
		_discard_selection.append(card_id)
	_refresh_all()


func _on_play_card(card_id: String) -> void:
	var result: Dictionary = Game.play_card(card_id)
	if not bool(result.get("ok", false)):
		_sidebar.append_log("[color=#d9676e]Cannot play card: %s[/color]" % String(
			result.get("reason", "")))


func _on_resolve_event(option_index: int) -> void:
	Game.resolve_event(option_index)


func _on_upkeep_dismissed() -> void:
	if Game.state != null and Game.state.pending_event != "":
		_event_overlay.present(Game.state, Game.db, Game.is_pending_event_first_sight())


func _on_state_changed() -> void:
	if _game_layout.visible:
		_refresh_all()


func _on_domain_events(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		var line: String = EventLogFormatter.describe(event, Game.db)
		if line != "":
			_sidebar.append_log(line)
	if not _starting_new_game and _has_type(events, "turn_started") \
			and not _has_type(events, "age_transitioned"):
		_pending_upkeep_events = events.duplicate(true)


func _on_transition_completed(report: TransitionReport) -> void:
	_discard_mode = false
	_discard_selection.clear()
	_transition_overlay.present(report, Game.db)


func _on_game_ended(outcome: String, score: Dictionary) -> void:
	var age_name: String = "The city"
	if Game.state != null:
		var age: AgeDef = Game.db.get_age(Game.state.age_id)
		if age != null:
			age_name = age.display_name
	_game_over.present(outcome, score, age_name)


func _has_type(events: Array[Dictionary], type_name: String) -> bool:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			return true
	return false
