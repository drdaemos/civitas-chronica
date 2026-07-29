class_name HandPanel
extends PanelContainer

signal play_requested(card_id: String)
signal discard_toggled(card_id: String)

## Contextual action surface. It owns card rendering and explanatory disabled
## states, while the main coordinator remains the authority for actions.

var _count_label: Label = null
var _hint_label: Label = null
var _strip: HBoxContainer = null


func _init() -> void:
	custom_minimum_size = Vector2(0, 318)
	add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#101518"), Color("#3e494e"), 12.0, 0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := UiStyle.heading("OPPORTUNITIES IN HAND", 12)
	header.add_child(title)
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 12)
	header.add_child(_count_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_hint_label = UiStyle.muted("Click an affordable card to commit it to the city.", 11)
	header.add_child(_hint_label)

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_strip = HBoxContainer.new()
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.add_theme_constant_override("separation", 12)
	scroll.add_child(_strip)


func refresh(state: GameState, db: ContentDB, pipeline: ModifierPipeline,
		hand_limit: int, discard_mode: bool, selection: Array[String]) -> void:
	UiStyle.clear(_strip)
	_count_label.text = "%d / %d" % [state.hand.size(), hand_limit]
	_count_label.add_theme_color_override(
		"font_color", UiStyle.RED if state.hand.size() > hand_limit else UiStyle.MUTED)
	_hint_label.text = (
		"Select the cards to discard permanently."
		if discard_mode else "Click an affordable card to commit it to the city."
	)
	if state.hand.is_empty():
		var empty := UiStyle.muted("No cards in hand.", 13)
		empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_strip.add_child(empty)
		return
	for card_id: String in state.hand:
		var card: CardDef = db.get_card(card_id)
		if card == null:
			continue
		var view := CardView.new()
		view.setup(card, db, pipeline.cost_of(card))
		if discard_mode:
			view.set_marked(card_id in selection, "Discarded cards are gone for good.")
			view.card_clicked.connect(discard_toggled.emit)
		else:
			var reason: String = _play_block_reason(state, card, pipeline, db)
			if reason != "":
				view.set_disabled(true, reason)
			view.card_clicked.connect(play_requested.emit)
		_strip.add_child(view)


func _play_block_reason(state: GameState, card: CardDef,
		pipeline: ModifierPipeline, db: ContentDB) -> String:
	if state.game_over:
		return "The game is over."
	if state.transition_pending:
		return "An age transition is pending."
	if state.pending_event != "":
		return "An event is awaiting resolution."
	if card.is_development():
		if state.has_development(card.id):
			return "Already built."
		for prereq_id: String in card.prerequisites:
			if not state.has_development(prereq_id):
				var prerequisite: CardDef = db.get_card(prereq_id)
				return "Requires %s." % (
					prerequisite.display_name if prerequisite != null else prereq_id)
	var cost: int = pipeline.cost_of(card)
	if cost > state.current_budget:
		return "Not enough budget (cost %d, budget %d)." % [cost, state.current_budget]
	return ""
