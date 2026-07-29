class_name GameOverPanel
extends Control

signal menu_requested

var _title: Label = null
var _subtitle: Label = null
var _score: Label = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.014, 0.016, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	panel.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#151a1c"), Color("#756040"), 30.0, 10))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(UiStyle.heading("THE CHRONICLE CLOSES", 11))
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	column.add_child(_title)
	_subtitle = UiStyle.muted("", 13)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_subtitle)
	_score = Label.new()
	_score.add_theme_font_size_override("font_size", 15)
	column.add_child(_score)
	var back := Button.new()
	back.text = "RETURN TO MENU"
	back.custom_minimum_size.y = 44
	back.pressed.connect(menu_requested.emit)
	column.add_child(back)


func present(outcome: String, score: Dictionary, age_name: String) -> void:
	match outcome:
		GameState.OUTCOME_WON:
			_title.text = "The city endures"
			_subtitle.text = "%s is complete. The city carries its history into the present." % age_name
		GameState.OUTCOME_LOST_CATASTROPHE:
			_title.text = "The city could not answer"
			_subtitle.text = "A demand left beyond tolerance became a catastrophe the city could no longer contain."
		GameState.OUTCOME_LOST_DEBT:
			_title.text = "The treasury governs now"
			_subtitle.text = "Three consecutive turns in the red ended the city's freedom to act."
		_:
			_title.text = "The chronicle ends"
			_subtitle.text = age_name
	_score.text = "POPULATION  %d     SPECIALIZATION  %d     HERITAGE  %d\n\nFINAL SCORE  %d" % [
		int(score.get("population", 0)), int(score.get("specialization", 0)),
		int(score.get("heritage", 0)), int(score.get("total", 0)),
	]
	visible = true
