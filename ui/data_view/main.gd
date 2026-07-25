extends Control

## Data-view MVP UI (GDD 6 accessibility note): the plain-stats skin over
## the sim. Every panel is built in code; screens (MENU / GAME / GAME OVER)
## are swapped by toggling visibility, with modal EVENT and AGE TRANSITION
## overlays on top of the game screen. The UI never computes rules itself —
## all values come from the Game autoload (GameState / ContentDB /
## ModifierPipeline), and the hand is rendered as real cards (CardView).

const APPROVAL_DANGER: int = 20
const DANGER_TINT: Color = Color(1.0, 0.45, 0.45)
const HAND_STRIP_HEIGHT: float = 300.0

var _menu: CenterContainer = null
var _continue_button: Button = null

var _game_panel: VBoxContainer = null
var _turn_label: Label = null
var _deck_label: Label = null
var _pop_label: Label = null
var _approval_label: Label = null
var _migration_label: Label = null
var _budget_label: Label = null
var _policy_label: Label = null
var _hand_strip: HBoxContainer = null
var _city_list: VBoxContainer = null
var _log_text: RichTextLabel = null
var _end_turn_button: Button = null

var _event_overlay: Control = null
var _event_box: VBoxContainer = null

var _transition_overlay: Control = null
var _transition_title: Label = null
var _transition_rows: VBoxContainer = null
var _transition_bill_label: Label = null
var _transition_warn_label: Label = null
var _transition_choices: Dictionary = {}     # card_id -> "preserve"|"adapt"|"demolish"
var _transition_adapt_costs: Dictionary = {} # card_id -> int
var _transition_built: bool = false

var _gameover_panel: CenterContainer = null
var _outcome_label: Label = null
var _outcome_sub_label: Label = null
var _score_label: Label = null


func _ready() -> void:
	_build_game()
	_build_menu()
	_build_event_overlay()
	_build_transition_overlay()
	_build_gameover()
	Game.state_changed.connect(_on_state_changed)
	Game.domain_events.connect(_on_domain_events)
	Game.game_ended.connect(_on_game_ended)
	Game.age_ended.connect(_on_age_ended)
	_show_menu()


# --- screen construction ------------------------------------------------------

func _build_menu() -> void:
	_menu = CenterContainer.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_menu.add_child(box)
	var title := Label.new()
	title.text = "Civitas Chronica"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A chronicle of a city, told in cards."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.7)
	box.add_child(subtitle)
	var new_button := Button.new()
	new_button.text = "New Game"
	new_button.pressed.connect(_on_new_game)
	box.add_child(new_button)
	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.pressed.connect(_on_continue)
	box.add_child(_continue_button)
	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(_on_quit)
	box.add_child(quit_button)


func _build_game() -> void:
	_game_panel = VBoxContainer.new()
	_game_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_panel.offset_left = 10.0
	_game_panel.offset_top = 8.0
	_game_panel.offset_right = -10.0
	_game_panel.offset_bottom = -8.0
	_game_panel.add_theme_constant_override("separation", 8)
	add_child(_game_panel)

	# top resource bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	_game_panel.add_child(top)
	_turn_label = Label.new()
	_deck_label = Label.new()
	_pop_label = Label.new()
	_approval_label = Label.new()
	_migration_label = Label.new()
	_budget_label = Label.new()
	_policy_label = Label.new()
	var bar_labels: Array[Label] = [
		_turn_label, _deck_label, _pop_label, _approval_label,
		_migration_label, _budget_label, _policy_label,
	]
	for label: Label in bar_labels:
		label.add_theme_font_size_override("font_size", 16)
		top.add_child(label)

	# middle: city / log columns
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	_game_panel.add_child(columns)

	var city_col := VBoxContainer.new()
	city_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_col.size_flags_stretch_ratio = 1.1
	columns.add_child(city_col)
	city_col.add_child(_header("CITY"))
	var city_scroll := ScrollContainer.new()
	city_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	city_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	city_col.add_child(city_scroll)
	_city_list = VBoxContainer.new()
	_city_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_city_list.add_theme_constant_override("separation", 4)
	city_scroll.add_child(_city_list)

	var log_col := VBoxContainer.new()
	log_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_col.size_flags_stretch_ratio = 1.0
	columns.add_child(log_col)
	log_col.add_child(_header("LOG"))
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_col.add_child(_log_text)
	_end_turn_button = Button.new()
	_end_turn_button.text = "End Turn"
	_end_turn_button.pressed.connect(_on_end_turn)
	log_col.add_child(_end_turn_button)

	# bottom: the hand as a horizontal card strip, cards anchored like a fan
	_game_panel.add_child(_header("HAND"))
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, HAND_STRIP_HEIGHT)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_game_panel.add_child(hand_scroll)
	_hand_strip = HBoxContainer.new()
	_hand_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hand_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_strip.add_theme_constant_override("separation", 10)
	hand_scroll.add_child(_hand_strip)


func _build_event_overlay() -> void:
	_event_overlay = Control.new()
	_event_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_event_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	_event_box = VBoxContainer.new()
	_event_box.custom_minimum_size = Vector2(520, 0)
	_event_box.add_theme_constant_override("separation", 10)
	margin.add_child(_event_box)


func _build_transition_overlay() -> void:
	_transition_overlay = Control.new()
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_transition_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_transition_title = Label.new()
	_transition_title.add_theme_font_size_override("font_size", 24)
	box.add_child(_transition_title)
	var subtitle := _muted_label("Decide the fate of every development your city inherits.")
	box.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_transition_rows = VBoxContainer.new()
	_transition_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transition_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_transition_rows)

	_transition_warn_label = Label.new()
	_transition_warn_label.modulate = DANGER_TINT
	_transition_warn_label.text = "Warning: this will start the age in debt."
	_transition_warn_label.visible = false
	box.add_child(_transition_warn_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	_transition_bill_label = Label.new()
	_transition_bill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transition_bill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_transition_bill_label)
	var confirm := Button.new()
	confirm.text = "Confirm — begin the new age"
	confirm.pressed.connect(_on_confirm_transition)
	footer.add_child(confirm)


func _build_gameover() -> void:
	_gameover_panel = CenterContainer.new()
	_gameover_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_gameover_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_gameover_panel.add_child(box)
	_outcome_label = Label.new()
	_outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_label.add_theme_font_size_override("font_size", 30)
	box.add_child(_outcome_label)
	_outcome_sub_label = Label.new()
	_outcome_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_sub_label.modulate = Color(1, 1, 1, 0.8)
	box.add_child(_outcome_sub_label)
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_score_label)
	var back := Button.new()
	back.text = "Back to Menu"
	back.pressed.connect(_show_menu)
	box.add_child(back)


# --- screen switching --------------------------------------------------------

func _show_menu() -> void:
	_menu.visible = true
	_game_panel.visible = false
	_event_overlay.visible = false
	_transition_overlay.visible = false
	_transition_built = false
	_gameover_panel.visible = false
	_continue_button.disabled = not Game.has_save()


func _show_game() -> void:
	_menu.visible = false
	_game_panel.visible = true
	_gameover_panel.visible = false


func _show_game_over(outcome: String, score: Dictionary) -> void:
	_menu.visible = false
	_game_panel.visible = false
	_event_overlay.visible = false
	_transition_overlay.visible = false
	_transition_built = false
	_gameover_panel.visible = true
	var age: AgeDef = null
	if Game.state != null:
		age = Game.db.get_age(Game.state.age_id)
	var age_name: String = age.display_name if age != null else "The age"
	match outcome:
		GameState.OUTCOME_WON:
			_outcome_label.text = "The city endures"
			_outcome_sub_label.text = "%s complete — your city carries its chronicle into the next century." % age_name
		GameState.OUTCOME_LOST_APPROVAL:
			_outcome_label.text = "The people turn against you"
			_outcome_sub_label.text = "Approval stayed critically low for too long; the council removes you from office."
		GameState.OUTCOME_LOST_DEBT:
			_outcome_label.text = "The treasury collapses"
			_outcome_sub_label.text = "Three consecutive turns in the red — the city's creditors govern now."
		_:
			_outcome_label.text = "The chronicle closes"
			_outcome_sub_label.text = ""
	_score_label.text = "Population: %d\nSpecialization: %d\nHeritage: %d\nTotal score: %d" % [
		int(score.get("population", 0)),
		int(score.get("specialization", 0)),
		int(score.get("heritage", 0)),
		int(score.get("total", 0)),
	]


# --- refresh -----------------------------------------------------------------

func _refresh_all() -> void:
	var state: GameState = Game.state
	if state == null:
		return
	_refresh_top_bar(state)
	_refresh_hand(state)
	_refresh_city(state)
	_refresh_event_overlay(state)
	_refresh_transition_overlay(state)
	_end_turn_button.disabled = state.pending_event != "" or state.game_over \
			or state.transition_pending


func _refresh_top_bar(state: GameState) -> void:
	var age: AgeDef = Game.db.get_age(state.age_id)
	if age != null:
		_turn_label.text = "%s — Year %d (turn %d/%d)" % [
			age.display_name, state.year, state.turn_number, age.total_turns(),
		]
	_deck_label.text = "Deck: %d" % state.main_deck.size()
	_pop_label.text = "Population: %d" % state.population
	_approval_label.text = "Approval: %d" % state.approval
	_approval_label.modulate = DANGER_TINT if state.approval < APPROVAL_DANGER else Color.WHITE
	_migration_label.text = "Migration appeal: %d/%d" % [state.migration_appeal, GameState.MIGRATION_MAX]
	var budget_text: String = "Budget: %d" % state.current_budget
	if state.pending_bill > 0:
		budget_text += " (bill %d due next turn)" % state.pending_bill
	_budget_label.text = budget_text
	_budget_label.modulate = DANGER_TINT if state.current_budget < 0 else Color.WHITE
	_policy_label.text = "Policies: %d/%d" % [state.active_policies.size(), state.policy_slots]


func _refresh_hand(state: GameState) -> void:
	_clear_children(_hand_strip)
	if state.hand.is_empty():
		var empty := _muted_label("(no cards in hand)")
		empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hand_strip.add_child(empty)
		return
	var pipeline: ModifierPipeline = Game.current_pipeline()
	for card_id: String in state.hand:
		var card: CardDef = Game.db.get_card(card_id)
		if card == null:
			continue
		var view := CardView.new()
		view.setup(card, Game.db, pipeline.cost_of(card))
		var reason: String = _play_block_reason(state, card, pipeline)
		if reason != "":
			view.set_disabled(true, reason)
		view.card_clicked.connect(_on_play_card)
		_hand_strip.add_child(view)


## Mirror of the engine's play_card gates, for disabled-card tooltips only.
## Values come from state helpers and the ModifierPipeline — no rules are
## re-derived here; the engine remains the authority on an actual play.
func _play_block_reason(state: GameState, card: CardDef, pipeline: ModifierPipeline) -> String:
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
				return "Requires %s." % _card_name(prereq_id)
	var cost: int = pipeline.cost_of(card)
	if cost > state.current_budget:
		return "Not enough budget (cost %d, budget %d)." % [cost, state.current_budget]
	return ""


func _refresh_city(state: GameState) -> void:
	_clear_children(_city_list)
	var db: ContentDB = Game.db

	var counts := Label.new()
	var tag_bits: Array[String] = []
	for tag: String in ContentDB.CANONICAL_TAGS:
		var n: int = state.tag_count(tag)
		if n > 0:
			tag_bits.append("%s %d" % [tag, n])
	counts.text = "Developments: %d" % state.developments.size()
	if not tag_bits.is_empty():
		counts.text += "  (" + ", ".join(tag_bits) + ")"
	counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_list.add_child(counts)

	# One line per built development, showing its LIVE tags (era
	# reinterpretation can change them) with effect lines as tooltip.
	for dev: DevelopmentState in state.developments:
		var line := Label.new()
		var display: String = _card_name(dev.card_id)
		var bits: Array[String] = ["  - " + display]
		if not dev.tags.is_empty():
			bits.append("[" + ", ".join(dev.tags) + "]")
		if dev.adapted:
			bits.append("(adapted)")
		line.text = " ".join(bits)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var effect_lines: Array[String] = EffectText.describe_all(dev.effects, db)
		if not effect_lines.is_empty():
			line.tooltip_text = "\n".join(effect_lines)
			line.mouse_filter = Control.MOUSE_FILTER_STOP
		_city_list.add_child(line)

	_city_list.add_child(_header("INTERACTIONS"))
	if state.active_interactions.is_empty():
		_city_list.add_child(_muted_label("(none active)"))
	for interaction_id: String in state.active_interactions:
		var interaction: InteractionDef = db.get_interaction(interaction_id)
		if interaction == null:
			continue
		var name_label := Label.new()
		name_label.text = interaction.display_name
		_city_list.add_child(name_label)
		var desc := _muted_label("  " + interaction.description)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_city_list.add_child(desc)
		for effect_line: String in EffectText.describe_all(interaction.effects, db):
			var el := _muted_label("    • " + effect_line)
			el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_city_list.add_child(el)

	_city_list.add_child(_header("POLICIES"))
	if state.unlocked_policies.is_empty():
		_city_list.add_child(_muted_label("(none unlocked)"))
	for policy_id: String in state.unlocked_policies:
		var policy: PolicyDef = db.get_policy(policy_id)
		if policy == null:
			continue
		if policy_id in state.active_policies:
			var active_label := Label.new()
			active_label.text = "%s (active)" % policy.display_name
			active_label.tooltip_text = policy.description
			active_label.mouse_filter = Control.MOUSE_FILTER_STOP
			_city_list.add_child(active_label)
			var desc := _muted_label("  " + policy.description)
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_city_list.add_child(desc)
		else:
			var row := HBoxContainer.new()
			var adopt := Button.new()
			adopt.text = "Adopt"
			adopt.disabled = state.game_over or state.transition_pending
			adopt.pressed.connect(_on_adopt_policy.bind(policy_id))
			row.add_child(adopt)
			var name_label := Label.new()
			name_label.text = policy.display_name
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.tooltip_text = policy.description
			name_label.mouse_filter = Control.MOUSE_FILTER_STOP
			row.add_child(name_label)
			_city_list.add_child(row)
		for effect_line: String in EffectText.describe_all(policy.effects, db):
			var el := _muted_label("    • " + effect_line)
			el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_city_list.add_child(el)


func _refresh_event_overlay(state: GameState) -> void:
	var active: bool = state.pending_event != "" and _game_panel.visible \
			and not state.transition_pending
	_event_overlay.visible = active
	if not active:
		return
	_clear_children(_event_box)
	var event: EventDef = Game.db.get_event(state.pending_event)
	if event == null:
		return
	var title := Label.new()
	title.text = event.title
	title.add_theme_font_size_override("font_size", 22)
	_event_box.add_child(title)
	if not Game.is_pending_event_first_sight():
		var seen := _muted_label("You have seen this before.")
		seen.modulate = Color(0.85, 0.8, 0.5)
		_event_box.add_child(seen)
	var body := Label.new()
	body.text = event.text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	_event_box.add_child(body)
	for i: int in event.options.size():
		var option: EventOptionDef = event.options[i]
		var button := Button.new()
		var text: String = option.text
		if option.cost > 0:
			text += "  (costs %d next turn)" % option.cost
		button.text = text
		button.pressed.connect(_on_resolve_event.bind(i))
		_event_box.add_child(button)
		var effect_lines: Array[String] = EffectText.describe_all(option.effects, Game.db)
		if not effect_lines.is_empty():
			var el := _muted_label("    → " + "; ".join(effect_lines))
			el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_event_box.add_child(el)


# --- age transition screen -----------------------------------------------------

func _refresh_transition_overlay(state: GameState) -> void:
	var active: bool = state.transition_pending and _game_panel.visible and not state.game_over
	_transition_overlay.visible = active
	if not active:
		_transition_built = false
		return
	if _transition_built:
		return
	_build_transition_contents(state)
	_transition_built = true


func _build_transition_contents(state: GameState) -> void:
	_transition_choices.clear()
	_transition_adapt_costs.clear()
	_clear_children(_transition_rows)
	_transition_title.text = "The world turns: %s gives way to %s" % [
		_age_name(state.age_id), _age_name(state.pending_transition_to),
	]
	var decisions: Array[Dictionary] = Game.transition_decisions()
	if decisions.is_empty():
		_transition_rows.add_child(_muted_label("The city carries nothing forward — a fresh start."))
	for decision: Dictionary in decisions:
		if not _transition_rows.get_children().is_empty():
			_transition_rows.add_child(HSeparator.new())
		_transition_rows.add_child(_make_transition_row(state, decision))
	_update_transition_bill(state)


func _make_transition_row(state: GameState, decision: Dictionary) -> HBoxContainer:
	var card_id: String = String(decision.get("card_id", ""))
	var current_tags: Array[String] = []
	current_tags.assign(decision.get("current_tags", []) as Array)
	_transition_choices[card_id] = AgeTransition.CHOICE_PRESERVE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# compact card of the development as it stands today (live tags/effects)
	var card: CardDef = Game.db.get_card(card_id)
	var dev: DevelopmentState = _development_for(state, card_id)
	if card != null and dev != null:
		var view := CardView.new()
		view.setup_development(card, Game.db, dev)
		view.set_interactive(false)
		view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(view)

	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	options.add_theme_constant_override("separation", 4)
	row.add_child(options)
	var group := ButtonGroup.new()

	var preserve: Dictionary = decision.get("preserve", {}) as Dictionary
	var preserve_tags: Array[String] = []
	preserve_tags.assign(preserve.get("tags", []) as Array)
	var preserve_text: String = "Preserve — unchanged" if preserve_tags == current_tags \
			else "Preserve — becomes [%s]" % ", ".join(preserve_tags)
	var preserve_button := _transition_option_button(preserve_text, group)
	preserve_button.button_pressed = true
	preserve_button.toggled.connect(
			_on_transition_choice.bind(card_id, AgeTransition.CHOICE_PRESERVE))
	options.add_child(preserve_button)

	var adapt_variant: Variant = decision.get("adapt")
	if adapt_variant is Dictionary:
		var adapt: Dictionary = adapt_variant
		var adapt_cost: int = int(adapt.get("cost", 0))
		var adapt_tags: Array[String] = []
		adapt_tags.assign(adapt.get("tags", []) as Array)
		_transition_adapt_costs[card_id] = adapt_cost
		var adapt_button := _transition_option_button(
				"Adapt (cost %d) — becomes [%s]" % [adapt_cost, ", ".join(adapt_tags)], group)
		adapt_button.toggled.connect(
				_on_transition_choice.bind(card_id, AgeTransition.CHOICE_ADAPT))
		options.add_child(adapt_button)

	var demolish: Dictionary = decision.get("demolish", {}) as Dictionary
	var demolish_button := _transition_option_button(
			"Demolish — approval %+d" % int(demolish.get("approval", 0)), group)
	demolish_button.toggled.connect(
			_on_transition_choice.bind(card_id, AgeTransition.CHOICE_DEMOLISH))
	options.add_child(demolish_button)
	return row


func _transition_option_button(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button


func _on_transition_choice(pressed: bool, card_id: String, choice: String) -> void:
	if not pressed:
		return
	_transition_choices[card_id] = choice
	if Game.state != null:
		_update_transition_bill(Game.state)


func _update_transition_bill(state: GameState) -> void:
	var bill: int = 0
	for card_id: String in _transition_choices:
		if String(_transition_choices[card_id]) == AgeTransition.CHOICE_ADAPT:
			bill += int(_transition_adapt_costs.get(card_id, 0))
	_transition_bill_label.text = "Adaptation bill: %d (charged at the start of the new age)" % bill
	var to_age: AgeDef = null
	if Game.db.ages.has(state.pending_transition_to):
		to_age = Game.db.ages[state.pending_transition_to] as AgeDef
	_transition_warn_label.visible = to_age != null and bill > to_age.base_budget


func _on_confirm_transition() -> void:
	Game.apply_transition(_transition_choices.duplicate())


# --- signal handlers ---------------------------------------------------------

func _on_new_game() -> void:
	_log_text.clear()
	_show_game()
	Game.new_game()


func _on_continue() -> void:
	_log_text.clear()
	if Game.continue_game():
		_show_game()
		var state: GameState = Game.state
		if state.transition_pending:
			_log_line("[b]Chronicle resumed mid-transition — the world is turning.[/b]")
		else:
			_log_line("[b]Chronicle resumed — turn %d, year %d.[/b]" % [state.turn_number, state.year])
		_refresh_all()
	else:
		_continue_button.disabled = true


func _on_quit() -> void:
	get_tree().quit()


func _on_end_turn() -> void:
	Game.end_turn()


func _on_play_card(card_id: String) -> void:
	var result: Dictionary = Game.play_card(card_id)
	if not bool(result.get("ok", false)):
		_log_line("[color=#e08080]Cannot play %s: %s[/color]" % [
			_card_name(card_id), String(result.get("reason", "")),
		])


func _on_adopt_policy(policy_id: String) -> void:
	var result: Dictionary = Game.adopt_policy(policy_id)
	if not bool(result.get("ok", false)):
		var policy: PolicyDef = Game.db.get_policy(policy_id)
		var display: String = policy.display_name if policy != null else policy_id
		_log_line("[color=#e08080]Cannot adopt %s: %s[/color]" % [display, String(result.get("reason", ""))])


func _on_resolve_event(option_index: int) -> void:
	Game.resolve_event(option_index)


func _on_state_changed() -> void:
	if _game_panel.visible:
		_refresh_all()


func _on_age_ended(_from_age: String, _to_age: String) -> void:
	if _game_panel.visible:
		_refresh_all()


func _on_domain_events(events: Array[Dictionary]) -> void:
	for ev: Dictionary in events:
		var line: String = _describe_event(ev)
		if line != "":
			_log_line(line)


func _on_game_ended(outcome: String, score: Dictionary) -> void:
	_show_game_over(outcome, score)


# --- log ---------------------------------------------------------------------

func _log_line(text: String) -> void:
	_log_text.append_text(text + "\n")


## Translates a domain event Dictionary into a human-readable log line.
## Returns "" for events that need no line of their own.
func _describe_event(ev: Dictionary) -> String:
	var db: ContentDB = Game.db
	match String(ev.get("type", "")):
		"turn_started":
			return "\n[b]Turn %d, year %d — budget %d[/b]" % [
				int(ev.get("turn", 0)), int(ev.get("year", 0)), int(ev.get("budget", 0)),
			]
		"cards_drawn":
			var names: Array[String] = []
			for card_id: Variant in ev.get("cards", []) as Array:
				names.append(_card_name(String(card_id)))
			if names.is_empty():
				return "The deck is empty — nothing drawn."
			return "Drew: " + ", ".join(names)
		"card_played":
			return "Played %s." % _card_name(String(ev.get("card", "")))
		"cards_injected":
			if String(ev.get("deck", "")) == "main":
				return "Cards were added to your deck."
			return "Something stirs — new events entered the city's future."
		"interaction_activated":
			var interaction: InteractionDef = db.get_interaction(String(ev.get("id", "")))
			var display: String = interaction.display_name if interaction != null else String(ev.get("id", ""))
			if bool(ev.get("first_discovery", false)):
				var desc: String = interaction.description if interaction != null else ""
				return "[color=#e6c65a]NEW: %s active — first discovery! %s[/color]" % [display, desc]
			return "%s is now active." % display
		"interaction_deactivated":
			var interaction: InteractionDef = db.get_interaction(String(ev.get("id", "")))
			var display: String = interaction.display_name if interaction != null else String(ev.get("id", ""))
			return "[color=#c9a0a0]%s no longer holds — the new era has moved past it.[/color]" % display
		"policy_unlocked":
			var policy: PolicyDef = db.get_policy(String(ev.get("id", "")))
			var display: String = policy.display_name if policy != null else String(ev.get("id", ""))
			return "Policy unlocked: %s." % display
		"event_fired":
			var event: EventDef = db.get_event(String(ev.get("id", "")))
			var display: String = event.title if event != null else String(ev.get("id", ""))
			return "[color=#d9975f]Event: %s[/color]" % display
		"event_resolved":
			var event: EventDef = db.get_event(String(ev.get("id", "")))
			var index: int = int(ev.get("option", 0))
			if event != null and index >= 0 and index < event.options.size():
				return "You chose: %s" % event.options[index].text
			return "The event was resolved."
		"turn_ended":
			return "Turn ended — population %d, approval %d." % [
				int(ev.get("population", 0)), int(ev.get("approval", 0)),
			]
		"age_ended":
			return "[b]The %s draws to a close — the world turns toward the %s.[/b]" % [
				_age_name(String(ev.get("from", ""))), _age_name(String(ev.get("to", ""))),
			]
		"development_preserved":
			return "%s stands preserved into the new age." % _card_name(String(ev.get("card", "")))
		"development_adapted":
			return "[color=#a0c9a0]%s is adapted for the new age.[/color]" % _card_name(String(ev.get("card", "")))
		"development_demolished":
			return "[color=#c9a0a0]%s is demolished.[/color]" % _card_name(String(ev.get("card", "")))
		"age_transitioned":
			return "[b]The %s begins.[/b]" % _age_name(String(ev.get("to", "")))
		"age_completed":
			return "[b]The age draws to a close.[/b]"
		"game_over":
			var score: Dictionary = ev.get("score", {}) as Dictionary
			return "[b]GAME OVER — final score %d.[/b]" % int(score.get("total", 0))
		_:
			return ""


# --- helpers -----------------------------------------------------------------

func _card_name(card_id: String) -> String:
	if Game.db != null and Game.db.cards.has(card_id):
		return (Game.db.cards[card_id] as CardDef).display_name
	return card_id


func _age_name(age_id: String) -> String:
	if Game.db != null and Game.db.ages.has(age_id):
		return (Game.db.ages[age_id] as AgeDef).display_name
	return age_id


func _development_for(state: GameState, card_id: String) -> DevelopmentState:
	for dev: DevelopmentState in state.developments:
		if dev.card_id == card_id:
			return dev
	return null


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label


func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.65)
	return label


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
