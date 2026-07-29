class_name TransitionOverlay
extends Control

signal dismissed

var _title: Label = null
var _rows: VBoxContainer = null
var _db: ContentDB = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.022, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 600)
	panel.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#151a1c"), Color("#877047"), 24.0, 10))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UiStyle.heading("THE WORLD TURNS", 11))
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 25)
	column.add_child(_title)
	var subtitle := UiStyle.muted(
		"The old age settles its accounts. These changes are the legacy of the city you built.",
		12)
	column.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)
	var confirm := Button.new()
	confirm.text = "BEGIN THE NEW AGE"
	confirm.custom_minimum_size.y = 44
	confirm.pressed.connect(_dismiss)
	column.add_child(confirm)


func present(report: TransitionReport, db: ContentDB) -> void:
	_db = db
	UiStyle.clear(_rows)
	_title.text = "%s gives way to %s" % [
		_age_name(report.from_age), _age_name(report.to_age),
	]
	_section("INHERITED CITY")
	if report.supersessions.is_empty():
		_detail("Every development carries forward in its current form.", UiStyle.MUTED)
	for entry: Dictionary in report.supersessions:
		_detail("%s  →  %s" % [
			_card_name(String(entry.get("from", ""))),
			_card_name(String(entry.get("to", ""))),
		], UiStyle.GOLD_BRIGHT)

	_section("INTERACTIONS")
	if report.interactions_gained.is_empty() and report.interactions_lost.is_empty():
		_detail("The city's active interactions are unchanged.", UiStyle.MUTED)
	for interaction_id: String in report.interactions_lost:
		_detail("Lost · %s" % _interaction_name(interaction_id), UiStyle.RED)
	for interaction_id: String in report.interactions_gained:
		_detail("Gained · %s" % _interaction_name(interaction_id), UiStyle.GREEN)

	_section("DEMAND PRESSURE")
	if report.activated_demand != "":
		_detail("%s becomes a city-wide responsibility, beginning at %d." % [
			_demand_name(report.activated_demand), report.activated_demand_value,
		], UiStyle.AMBER if report.activated_demand_value > 0 else UiStyle.GREEN)
	for row: Dictionary in report.demand_rows:
		_detail("%s · %d unmet · increases by %d next turn · emergencies at %d" % [
			_demand_name(String(row.get("demand", ""))),
			int(row.get("value", 0)), int(row.get("growth", 0)),
			int(row.get("threshold", 0)),
		], UiStyle.INK)

	_section("THE NEW AGE")
	_detail("Budget %d per turn · Hand limit %d · %d old-age card%s discarded" % [
		report.base_budget, report.hand_limit, report.hand_discarded,
		"" if report.hand_discarded == 1 else "s",
	], UiStyle.INK)
	visible = true


func _section(text: String) -> void:
	var heading := UiStyle.heading(text, 10)
	heading.custom_minimum_size.y = 26
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_rows.add_child(heading)


func _detail(text: String, tint: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", tint)
	_rows.add_child(label)


func _dismiss() -> void:
	visible = false
	dismissed.emit()


func _card_name(card_id: String) -> String:
	var card: CardDef = _db.get_card(card_id)
	return card.display_name if card != null else card_id


func _age_name(age_id: String) -> String:
	var age: AgeDef = _db.get_age(age_id)
	return age.display_name if age != null else age_id


func _interaction_name(interaction_id: String) -> String:
	var interaction: InteractionDef = _db.get_interaction(interaction_id)
	return interaction.display_name if interaction != null else interaction_id


func _demand_name(demand_id: String) -> String:
	var demand: DemandDef = _db.rules.get_demand(demand_id)
	return demand.display_name if demand != null else demand_id
