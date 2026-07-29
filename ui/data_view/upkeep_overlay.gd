class_name UpkeepOverlay
extends Control

signal dismissed

## Blocking turn report. It announces the new turn and translates automatic
## upkeep into a compact before/after ledger so no simulation change is hidden.

var _eyebrow: Label = null
var _title: Label = null
var _subtitle: Label = null
var _rows: VBoxContainer = null
var _continue: Button = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.022, 0.42)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#151b1e"), Color("#66767b"), 24.0, 10))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_eyebrow = UiStyle.heading("THE CITY MOVES", 11)
	column.add_child(_eyebrow)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 27)
	column.add_child(_title)
	_subtitle = UiStyle.muted("", 12)
	column.add_child(_subtitle)
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", UiStyle.BORDER)
	column.add_child(divider)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	column.add_child(_rows)
	_continue = Button.new()
	_continue.custom_minimum_size = Vector2(0, 44)
	_continue.pressed.connect(_dismiss)
	column.add_child(_continue)


func present(events: Array[Dictionary], state: GameState, db: ContentDB) -> void:
	var started: Dictionary = _first(events, "turn_started")
	if started.is_empty():
		visible = false
		return
	var age: AgeDef = db.get_age(state.age_id)
	var start_year: int = int(started.get("year", state.year))
	_title.text = "Turn %d begins" % int(started.get("turn", state.turn_number))
	_subtitle.text = "%s  ·  %d–%d" % [
		age.display_name if age != null else state.age_id, start_year, state.year,
	]
	_continue.text = "FACE THE EVENT" if state.pending_event != "" else "PLAN THE TURN"
	UiStyle.clear(_rows)

	_add_row("BUDGET", "Available budget refreshed to %d" % int(started.get("budget", 0)),
		UiStyle.GOLD_BRIGHT)
	var meaningful: bool = false
	for event: Dictionary in events:
		match String(event.get("type", "")):
			"population_grew":
				var delta: int = int(event.get("delta", 0))
				_add_row("POPULATION", "%s%d → %s" % [
					"+" if delta >= 0 else "", delta,
					_thousands(int(event.get("count", 0))),
				], UiStyle.GREEN if delta >= 0 else UiStyle.RED)
				meaningful = true
			"population_level_changed":
				_add_row("CITY LEVEL", "Level %d → %d · all demands now grow %s" % [
					int(event.get("from", 0)), int(event.get("to", 0)),
					"faster" if int(event.get("to", 0)) > int(event.get("from", 0)) else "slower",
				], UiStyle.AMBER)
				meaningful = true
			"demand_grew":
				var step: int = int(event.get("step", 0))
				_add_row(
					_demand_name(String(event.get("demand", "")), db).to_upper(),
					"%d → %d  ·  +%d unmet need" % [
						int(event.get("from", 0)), int(event.get("to", 0)), step,
					], UiStyle.AMBER if step > 0 else UiStyle.GREEN)
				meaningful = true
			"pressure_card_shuffled":
				var severe: bool = String(event.get("severity", "")) == EventDef.SEVERITY_CATASTROPHE
				_add_row(
					"WARNING",
					"%s added a %s to the event deck" % [
						_demand_name(String(event.get("demand", "")), db),
						"catastrophe" if severe else "new emergency",
					], UiStyle.RED if severe else UiStyle.AMBER)
				meaningful = true
			"cards_drawn":
				var cards: Array = event.get("cards", []) as Array
				_add_row("NEW DRAW", "%d card%s entered your hand" % [
					cards.size(), "" if cards.size() == 1 else "s",
				], UiStyle.INK)
	if not meaningful:
		_add_row("CITY STATUS", "No population or demand pressure changed.", UiStyle.GREEN)
	visible = true


func _add_row(label_text: String, detail_text: String, tint: Color) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#101618"), Color("#2c373b"), 9.0, 6))
	_rows.add_child(row)
	var line := HBoxContainer.new()
	row.add_child(line)
	var label := UiStyle.heading(label_text, 10)
	label.custom_minimum_size = Vector2(120, 0)
	label.add_theme_color_override("font_color", tint)
	line.add_child(label)
	var detail := Label.new()
	detail.text = detail_text
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(detail)


func _dismiss() -> void:
	visible = false
	dismissed.emit()


func _first(events: Array[Dictionary], type_name: String) -> Dictionary:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type_name:
			return event
	return {}


func _demand_name(demand_id: String, db: ContentDB) -> String:
	var demand: DemandDef = db.rules.get_demand(demand_id)
	return demand.display_name if demand != null else demand_id


func _thousands(value: int) -> String:
	var raw: String = str(value)
	var out: String = ""
	while raw.length() > 3:
		out = "," + raw.substr(raw.length() - 3) + out
		raw = raw.substr(0, raw.length() - 3)
	return raw + out
