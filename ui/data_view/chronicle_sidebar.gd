class_name ChronicleSidebar
extends PanelContainer

signal end_turn_requested
signal cancel_discard_requested

## Right-side status column. Population sits directly below the year/turn corner
## in the command bar; the chronicle keeps secondary history available without
## competing with the decision surface.

var _population_level: Label = null
var _population_count: Label = null
var _population_delta: Label = null
var _deck_label: Label = null
var _log: RichTextLabel = null
var _end_turn: Button = null
var _cancel_discard: Button = null
var _population_tween: Tween = null


func _init() -> void:
	custom_minimum_size = Vector2(330, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(UiStyle.BG_PANEL, UiStyle.BORDER, 14.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	column.add_child(UiStyle.heading("CITY POPULATION", 11))
	var population_panel := PanelContainer.new()
	population_panel.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#172126"), Color("#3b565e"), 12.0))
	column.add_child(population_panel)
	var population_box := VBoxContainer.new()
	population_box.add_theme_constant_override("separation", 0)
	population_panel.add_child(population_box)
	_population_level = Label.new()
	_population_level.add_theme_font_size_override("font_size", 12)
	_population_level.add_theme_color_override("font_color", UiStyle.GOLD)
	population_box.add_child(_population_level)
	_population_count = Label.new()
	_population_count.add_theme_font_size_override("font_size", 28)
	population_box.add_child(_population_count)
	_population_delta = UiStyle.muted("", 10)
	population_box.add_child(_population_delta)

	_deck_label = UiStyle.muted("", 11)
	column.add_child(_deck_label)
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", UiStyle.BORDER)
	column.add_child(divider)
	column.add_child(UiStyle.heading("CHRONICLE", 11))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 12)
	_log.add_theme_color_override("default_color", UiStyle.MUTED)
	column.add_child(_log)

	var turn_row := HBoxContainer.new()
	column.add_child(turn_row)
	_end_turn = Button.new()
	_end_turn.text = "END TURN"
	_end_turn.custom_minimum_size = Vector2(0, 48)
	_end_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_turn.add_theme_font_size_override("font_size", 15)
	_end_turn.pressed.connect(end_turn_requested.emit)
	turn_row.add_child(_end_turn)
	_cancel_discard = Button.new()
	_cancel_discard.text = "Cancel"
	_cancel_discard.visible = false
	_cancel_discard.pressed.connect(cancel_discard_requested.emit)
	turn_row.add_child(_cancel_discard)


func refresh(state: GameState, deck_size: int, overflow: int, discard_mode: bool,
		selected_count: int, blocked: bool, before: Dictionary = {}) -> void:
	_population_level.text = "LEVEL %d" % state.population_level
	var start_population: int = int(before.get("population", state.population_count))
	_set_population(start_population)
	if start_population != state.population_count:
		_population_delta.text = "%+d this turn" % (state.population_count - start_population)
		_population_delta.add_theme_color_override(
			"font_color", UiStyle.GREEN if state.population_count >= start_population else UiStyle.RED)
		_animate_population(start_population, state.population_count)
	else:
		_population_delta.text = "city residents"
		_population_delta.add_theme_color_override("font_color", UiStyle.MUTED)
	_deck_label.text = "%d cards remain in this age's deck" % deck_size

	_cancel_discard.visible = discard_mode
	_cancel_discard.disabled = blocked
	if discard_mode:
		_end_turn.text = "DISCARD %d OF %d" % [selected_count, overflow]
		_end_turn.disabled = blocked or selected_count != overflow
	elif overflow > 0:
		_end_turn.text = "DISCARD %d TO END TURN" % overflow
		_end_turn.disabled = blocked
	else:
		_end_turn.text = "END TURN"
		_end_turn.disabled = blocked


func append_log(text: String) -> void:
	_log.append_text(text + "\n")


func clear_log() -> void:
	_log.clear()


func _animate_population(from_value: int, to_value: int) -> void:
	if _population_tween != null and _population_tween.is_valid():
		_population_tween.kill()
	if not is_inside_tree():
		_set_population(to_value)
		return
	_population_tween = create_tween()
	_population_tween.tween_method(
		_set_population_float, float(from_value), float(to_value), 0.7) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_population_float(value: float) -> void:
	_set_population(int(round(value)))


func _set_population(value: int) -> void:
	_population_count.text = _thousands(value)


func _thousands(value: int) -> String:
	var raw: String = str(value)
	var out: String = ""
	while raw.length() > 3:
		out = "," + raw.substr(raw.length() - 3) + out
		raw = raw.substr(0, raw.length() - 3)
	return raw + out
