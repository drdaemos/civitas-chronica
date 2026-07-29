class_name CommandBar
extends PanelContainer

## Persistent macro-state bar: the spendable budget and every active demand
## remain visible while cards, events, and city details change below.

var _age_label: Label = null
var _budget_value: Label = null
var _budget_bill: Label = null
var _demand_row: HBoxContainer = null
var _year_label: Label = null
var _turn_label: Label = null
var _budget_tween: Tween = null


func _init() -> void:
	custom_minimum_size = Vector2(0, 112)
	add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#101719"), Color("#455259"), 14.0, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var identity := VBoxContainer.new()
	identity.custom_minimum_size = Vector2(220, 0)
	identity.add_theme_constant_override("separation", 2)
	row.add_child(identity)
	var game_name := UiStyle.heading("CIVITAS CHRONICA", 12)
	identity.add_child(game_name)
	_age_label = Label.new()
	_age_label.add_theme_font_size_override("font_size", 19)
	identity.add_child(_age_label)
	var subtitle := UiStyle.muted("THE CITY'S CHRONICLE", 10)
	identity.add_child(subtitle)

	var budget_panel := PanelContainer.new()
	budget_panel.custom_minimum_size = Vector2(150, 0)
	budget_panel.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#20271e"), Color("#657047"), 10.0))
	row.add_child(budget_panel)
	var budget_box := VBoxContainer.new()
	budget_box.add_theme_constant_override("separation", 0)
	budget_panel.add_child(budget_box)
	budget_box.add_child(UiStyle.heading("BUDGET", 10))
	_budget_value = Label.new()
	_budget_value.add_theme_font_size_override("font_size", 27)
	_budget_value.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	budget_box.add_child(_budget_value)
	_budget_bill = UiStyle.muted("refreshes each turn", 10)
	budget_box.add_child(_budget_bill)

	_demand_row = HBoxContainer.new()
	_demand_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_demand_row.add_theme_constant_override("separation", 8)
	row.add_child(_demand_row)

	var time_panel := PanelContainer.new()
	time_panel.custom_minimum_size = Vector2(152, 0)
	time_panel.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#171d21"), Color("#465158"), 10.0))
	row.add_child(time_panel)
	var time_box := VBoxContainer.new()
	time_box.alignment = BoxContainer.ALIGNMENT_CENTER
	time_panel.add_child(time_box)
	_year_label = Label.new()
	_year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_year_label.add_theme_font_size_override("font_size", 26)
	time_box.add_child(_year_label)
	_turn_label = UiStyle.muted("", 11)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_box.add_child(_turn_label)


func refresh(state: GameState, db: ContentDB, pipeline: ModifierPipeline,
		before: Dictionary = {}) -> void:
	var age: AgeDef = db.get_age(state.age_id)
	_age_label.text = age.display_name if age != null else state.age_id
	_year_label.text = str(state.year)
	_turn_label.text = "TURN %d / %d" % [
		state.turn_number, age.total_turns() if age != null else 0,
	]
	_budget_bill.text = (
		"%d due next turn" % state.pending_bill
		if state.pending_bill > 0 else "refreshes each turn"
	)
	var start_budget: int = int(before.get("budget", state.current_budget))
	_set_budget(start_budget)
	if start_budget != state.current_budget:
		_animate_budget(start_budget, state.current_budget)

	UiStyle.clear(_demand_row)
	var before_demands: Dictionary = before.get("demands", {}) as Dictionary
	for demand_id: String in state.active_demands:
		var demand: DemandDef = db.rules.get_demand(demand_id)
		if demand == null:
			continue
		var value: int = state.demand_value(demand_id)
		var start_value: int = int(before_demands.get(demand_id, value))
		var meter := DemandMeter.new()
		meter.setup(
			demand, start_value, value, pipeline.demand_growth_step(demand_id),
			db.rules.threshold_for(demand_id), db.rules.catastrophe_for(demand_id))
		_demand_row.add_child(meter)
	if state.active_demands.is_empty():
		var empty := UiStyle.muted("No city-wide demands are active yet.", 12)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_demand_row.add_child(empty)


func _animate_budget(from_value: int, to_value: int) -> void:
	if _budget_tween != null and _budget_tween.is_valid():
		_budget_tween.kill()
	if not is_inside_tree():
		_set_budget(to_value)
		return
	_budget_tween = create_tween()
	_budget_tween.tween_method(_set_budget_float, float(from_value), float(to_value), 0.7) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_budget_float(value: float) -> void:
	_set_budget(int(round(value)))


func _set_budget(value: int) -> void:
	_budget_value.text = "%d" % value
	_budget_value.add_theme_color_override(
		"font_color", UiStyle.RED if value < 0 else UiStyle.GOLD_BRIGHT)
