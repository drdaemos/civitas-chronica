class_name EventOverlay
extends Control

signal option_selected(option_index: int)

## Event decision modal. Every authored option is shown; unavailable specialist
## choices remain visible as locked information instead of disappearing.

var _kicker: Label = null
var _title: Label = null
var _body: Label = null
var _seen: Label = null
var _protection: Label = null
var _options: VBoxContainer = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.022, 0.76)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	panel.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#17191a"), Color("#9d7440"), 24.0, 10))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	_kicker = UiStyle.heading("AN EVENT DEMANDS A DECISION", 11)
	column.add_child(_kicker)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	column.add_child(_title)
	_seen = UiStyle.muted("Recorded previously in the chronicle.", 10)
	_seen.add_theme_color_override("font_color", UiStyle.GOLD)
	column.add_child(_seen)
	_body = Label.new()
	_body.custom_minimum_size = Vector2(720, 76)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 15)
	_body.add_theme_color_override("font_color", Color("#d8d0c1"))
	column.add_child(_body)
	_protection = Label.new()
	_protection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_protection.add_theme_color_override("font_color", UiStyle.GREEN)
	column.add_child(_protection)
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color("#5d4931"))
	column.add_child(divider)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 8)
	column.add_child(_options)


func present(state: GameState, db: ContentDB, first_sight: bool) -> void:
	var event: EventDef = db.get_event(state.pending_event)
	if event == null:
		visible = false
		return
	visible = true
	_title.text = event.title
	_body.text = event.text
	_seen.visible = not first_sight
	var severity: String = event.severity
	_kicker.text = "CATASTROPHE" if severity == EventDef.SEVERITY_CATASTROPHE \
			else "EMERGENCY" if severity == EventDef.SEVERITY_EMERGENCY \
			else "AN EVENT DEMANDS A DECISION"
	_kicker.add_theme_color_override(
		"font_color", UiStyle.RED if severity == EventDef.SEVERITY_CATASTROPHE else UiStyle.GOLD)

	var cancelled_by: String = EventMatcher.hazard_cancelled_by(state, db, event)
	_protection.visible = cancelled_by != ""
	if cancelled_by != "":
		_protection.text = "%s protects the city: %s damage will be prevented." % [
			_card_name(cancelled_by, db), event.hazard,
		]

	UiStyle.clear(_options)
	for index: int in event.options.size():
		var option: EventOptionDef = event.options[index]
		var available: bool = option.is_available(state)
		var option_panel := PanelContainer.new()
		option_panel.add_theme_stylebox_override(
			"panel", UiStyle.padded_panel_style(Color("#111718"), Color("#343f42"), 8.0))
		_options.add_child(option_panel)
		var option_box := VBoxContainer.new()
		option_box.add_theme_constant_override("separation", 3)
		option_panel.add_child(option_box)
		var button := Button.new()
		button.text = option.text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 42)
		button.disabled = not available
		if available:
			button.pressed.connect(option_selected.emit.bind(index))
		option_box.add_child(button)

		if not available:
			var locked := UiStyle.muted(
				"LOCKED · Requires %s" % _card_name(option.requires_development, db), 11)
			locked.add_theme_color_override("font_color", UiStyle.RED)
			option_box.add_child(locked)
		var consequences: Array[String] = EffectText.describe_all(
			EventMatcher.effects_after_cancellation(option, cancelled_by != ""), db)
		if option.cost > 0:
			consequences.push_front("Costs %d from next turn's budget" % option.cost)
		if consequences.is_empty():
			consequences.append("No immediate mechanical change")
		var effect_label := UiStyle.muted("  " + "  ·  ".join(consequences), 11)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option_box.add_child(effect_label)


func dismiss() -> void:
	visible = false


func _card_name(card_id: String, db: ContentDB) -> String:
	var card: CardDef = db.get_card(card_id)
	return card.display_name if card != null else card_id
