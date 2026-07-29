class_name CityWorkspace
extends PanelContainer

## Main tableau: the durable engine the player has built and the interactions
## currently produced by its tags. Policies are deliberately absent.

var _summary_label: Label = null
var _development_grid: HFlowContainer = null
var _interaction_box: VBoxContainer = null


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(UiStyle.BG_PANEL, UiStyle.BORDER, 14.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var heading_box := VBoxContainer.new()
	heading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_box.add_theme_constant_override("separation", 0)
	header.add_child(heading_box)
	heading_box.add_child(UiStyle.heading("CITY ENGINE", 12))
	var title := Label.new()
	title.text = "Built across the years"
	title.add_theme_font_size_override("font_size", 20)
	heading_box.add_child(title)
	_summary_label = UiStyle.muted("", 11)
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	header.add_child(_summary_label)

	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", UiStyle.BORDER)
	column.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_development_grid = HFlowContainer.new()
	_development_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_development_grid.add_theme_constant_override("h_separation", 10)
	_development_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_development_grid)

	var interaction_panel := PanelContainer.new()
	interaction_panel.add_theme_stylebox_override(
		"panel", UiStyle.padded_panel_style(Color("#11191a"), Color("#31413f"), 10.0))
	column.add_child(interaction_panel)
	_interaction_box = VBoxContainer.new()
	_interaction_box.add_theme_constant_override("separation", 3)
	interaction_panel.add_child(_interaction_box)


func refresh(state: GameState, db: ContentDB) -> void:
	var tag_bits: Array[String] = []
	for tag: String in ContentDB.CANONICAL_TAGS:
		var count: int = state.tag_count(tag)
		if count > 0:
			tag_bits.append("%s %d" % [tag.capitalize(), count])
	_summary_label.text = "%d developments" % state.developments.size()
	if not tag_bits.is_empty():
		_summary_label.text += "  ·  " + "  ·  ".join(tag_bits)

	UiStyle.clear(_development_grid)
	if state.developments.is_empty():
		var empty := UiStyle.muted(
			"Your city is still unwritten.\nPlay a development card to establish its first enduring institution.",
			14)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(500, 90)
		_development_grid.add_child(empty)
	for dev: DevelopmentState in state.developments:
		var card: CardDef = db.get_card(dev.card_id)
		if card == null:
			continue
		var view := CardView.new()
		view.setup_development(card, db, dev)
		view.set_interactive(false)
		_development_grid.add_child(view)

	UiStyle.clear(_interaction_box)
	var interaction_heading := UiStyle.heading("ACTIVE INTERACTIONS", 10)
	_interaction_box.add_child(interaction_heading)
	if state.active_interactions.is_empty():
		_interaction_box.add_child(UiStyle.muted(
			"None yet — matching development tags can change how the city works.", 11))
	for interaction_id: String in state.active_interactions:
		var interaction: InteractionDef = db.get_interaction(interaction_id)
		if interaction == null:
			continue
		var row := HBoxContainer.new()
		_interaction_box.add_child(row)
		var name_label := Label.new()
		name_label.text = interaction.display_name
		name_label.custom_minimum_size = Vector2(170, 0)
		name_label.add_theme_color_override("font_color", UiStyle.GREEN)
		row.add_child(name_label)
		var description := UiStyle.muted(interaction.description, 11)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
