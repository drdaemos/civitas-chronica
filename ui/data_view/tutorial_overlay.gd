class_name TutorialOverlay
extends Control

signal dismissed

const PAGES: Array[Dictionary] = [
	{
		"title": "Welcome to Civitas Chronica",
		"body": "Guide one city across centuries. Every turn the city changes first; then you answer an event and choose which opportunities become part of its history.\n\nThis opening turn is calm. No random event will interrupt your first look at the city.",
	},
	{
		"title": "Build with a limited budget",
		"body": "Cards in your hand are opportunities. Developments remain in the city and shape its engine; actions solve a problem once and are consumed.\n\nBudget refreshes each turn. Unspent budget does not carry over, while event bills are deducted from the next refresh.",
	},
	{
		"title": "Meet needs before they become crises",
		"body": "The command bar tracks unmet city demands. Zero means satisfied. Each meter shows how much it will increase next turn and where emergencies begin.\n\nCards say plainly whether they increase or satisfy a demand. Sustained pressure adds dangerous events to the deck.",
	},
	{
		"title": "Write this city's history",
		"body": "Development tags combine into interactions that change the rules of the city. Unplayed cards remain in hand up to the limit.\n\nPlay what you can afford, study the consequences, then End Turn. Adaptation matters more than finding one perfect build.",
	},
]

var _title: Label = null
var _body: Label = null
var _counter: Label = null
var _back: Button = null
var _next: Button = null
var _page: int = 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.022, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	panel.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#171b1d"), Color("#987442"), 28.0, 10))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(UiStyle.heading("A MAYOR'S BRIEFING", 11))
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	column.add_child(_title)
	_body = Label.new()
	_body.custom_minimum_size = Vector2(620, 190)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 15)
	column.add_child(_body)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	_counter = UiStyle.muted("", 11)
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_counter)
	_back = Button.new()
	_back.text = "BACK"
	_back.pressed.connect(_previous)
	footer.add_child(_back)
	_next = Button.new()
	_next.pressed.connect(_advance)
	footer.add_child(_next)


func present() -> void:
	_page = 0
	visible = true
	_refresh()


func _refresh() -> void:
	var page: Dictionary = PAGES[_page]
	_title.text = String(page.get("title", ""))
	_body.text = String(page.get("body", ""))
	_counter.text = "%d / %d" % [_page + 1, PAGES.size()]
	_back.disabled = _page == 0
	_next.text = "ENTER THE CITY" if _page == PAGES.size() - 1 else "NEXT"


func _previous() -> void:
	if _page <= 0:
		return
	_page -= 1
	_refresh()


func _advance() -> void:
	if _page >= PAGES.size() - 1:
		visible = false
		dismissed.emit()
		return
	_page += 1
	_refresh()
