class_name MainMenu
extends Control

signal new_game_requested
signal continue_requested
signal quit_requested

var _continue: Button = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiStyle.BG_DEEP
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var accent := ColorRect.new()
	accent.color = Color("#9b7440")
	accent.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	accent.custom_minimum_size.y = 4
	add_child(accent)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#141a1d"), Color("#5d4b35"), 36.0, 12))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var eyebrow := UiStyle.heading("A CARD-BASED CITY CHRONICLE", 11)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(eyebrow)
	var title := Label.new()
	title.text = "CIVITAS\nCHRONICA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#f2e7d1"))
	column.add_child(title)
	var subtitle := UiStyle.muted(
		"Build one provincial city through five centuries of pressure, opportunity, and consequence.",
		13)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	column.add_child(spacer)
	var new_button := Button.new()
	new_button.text = "BEGIN A NEW CHRONICLE"
	new_button.custom_minimum_size.y = 48
	new_button.pressed.connect(new_game_requested.emit)
	column.add_child(new_button)
	_continue = Button.new()
	_continue.text = "CONTINUE"
	_continue.custom_minimum_size.y = 42
	_continue.pressed.connect(continue_requested.emit)
	column.add_child(_continue)
	var quit_button := Button.new()
	quit_button.text = "QUIT"
	quit_button.pressed.connect(quit_requested.emit)
	column.add_child(quit_button)


func set_continue_available(available: bool) -> void:
	_continue.disabled = not available
