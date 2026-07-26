class_name CardView
extends PanelContainer

## A card rendered as a card (GDD 6): fixed proportions, category-tinted
## header with a cost badge, tag chips, human-readable effect lines and
## flavor text. Built entirely in code — no scene file. Emits card_clicked
## when the player clicks it (unless disabled or non-interactive).

signal card_clicked(card_id: String)

const BASE_SIZE: Vector2 = Vector2(180, 260)
const COMPACT_SIZE: Vector2 = Vector2(150, 200)
const HOVER_SCALE: Vector2 = Vector2(1.05, 1.05)
const HOVER_TIME: float = 0.08

const TAG_TINTS: Dictionary = {
	"trade": Color(0.72, 0.54, 0.16),
	"military": Color(0.52, 0.34, 0.34),
	"religious": Color(0.5, 0.36, 0.6),
	"industrial": Color(0.62, 0.36, 0.22),
	"cultural": Color(0.22, 0.52, 0.52),
	"science": Color(0.28, 0.44, 0.66),
	"infrastructure": Color(0.42, 0.46, 0.5),
}
const ACTION_TINT: Color = Color(0.56, 0.5, 0.38)  # neutral parchment
const BODY_BG: Color = Color(0.14, 0.13, 0.12)
const BORDER_NORMAL: Color = Color(0.42, 0.4, 0.36)
const BORDER_HOVER: Color = Color(0.85, 0.8, 0.65)
const BORDER_MARKED: Color = Color(0.85, 0.45, 0.4)  # picked for discard
const BADGE_NEUTRAL: Color = Color(0.24, 0.23, 0.21)
const BADGE_CHEAPER: Color = Color(0.2, 0.42, 0.24)
const BADGE_DEARER: Color = Color(0.5, 0.2, 0.18)
const DISABLED_MODULATE: Color = Color(0.55, 0.55, 0.55, 0.85)
const DEMAND_MITIGATE: Color = Color(0.62, 0.85, 0.66)  # a need this card answers
const DEMAND_AGGRAVATE: Color = Color(0.92, 0.66, 0.55)  # a need this card worsens

var card_id: String = ""

var _disabled: bool = false
var _interactive: bool = true
var _marked: bool = false
var _style: StyleBoxFlat = null
var _header_style: StyleBoxFlat = null
var _badge_style: StyleBoxFlat = null
var _name_label: Label = null
var _badge_panel: PanelContainer = null
var _badge_label: Label = null
var _chips_row: HFlowContainer = null
var _body_box: VBoxContainer = null
var _flavor_label: Label = null
var _hover_tween: Tween = null
var _tooltip_lines: Array[String] = []


func _init() -> void:
	custom_minimum_size = BASE_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style = StyleBoxFlat.new()
	_style.bg_color = BODY_BG
	_style.set_corner_radius_all(8)
	_style.set_border_width_all(1)
	_style.border_color = BORDER_NORMAL
	_style.set_content_margin_all(3.0)
	add_theme_stylebox_override("panel", _style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	# --- header strip: name + cost badge ---
	var header := PanelContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_style = StyleBoxFlat.new()
	_header_style.bg_color = ACTION_TINT
	_header_style.set_corner_radius_all(6)
	_header_style.content_margin_left = 7.0
	_header_style.content_margin_right = 5.0
	_header_style.content_margin_top = 5.0
	_header_style.content_margin_bottom = 5.0
	header.add_theme_stylebox_override("panel", _header_style)
	column.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_row)
	_name_label = Label.new()
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	header_row.add_child(_name_label)
	_badge_panel = PanelContainer.new()
	_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_badge_style = StyleBoxFlat.new()
	_badge_style.bg_color = BADGE_NEUTRAL
	_badge_style.set_corner_radius_all(13)
	_badge_style.set_border_width_all(1)
	_badge_style.border_color = Color(0.9, 0.88, 0.8, 0.5)
	_badge_style.set_content_margin_all(2.0)
	_badge_panel.add_theme_stylebox_override("panel", _badge_style)
	_badge_panel.custom_minimum_size = Vector2(26, 26)
	header_row.add_child(_badge_panel)
	_badge_label = Label.new()
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.add_theme_font_size_override("font_size", 15)
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_panel.add_child(_badge_label)

	# --- body: chips, effects, paths hint, flavor ---
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 6)
	body_margin.add_theme_constant_override("margin_right", 6)
	body_margin.add_theme_constant_override("margin_bottom", 6)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body_margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_margin.add_child(body)
	_chips_row = HFlowContainer.new()
	_chips_row.add_theme_constant_override("h_separation", 3)
	_chips_row.add_theme_constant_override("v_separation", 3)
	_chips_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_chips_row)
	_body_box = VBoxContainer.new()
	_body_box.add_theme_constant_override("separation", 2)
	_body_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_body_box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(spacer)
	_flavor_label = Label.new()
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_font_size_override("font_size", 10)
	_flavor_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65, 0.7))
	_flavor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_flavor_label)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## Full card view for a card in hand / a deck listing. `effective_cost` is
## the ModifierPipeline cost; pass -1 to show the printed cost unmodified.
func setup(card: CardDef, db: ContentDB, effective_cost: int = -1) -> void:
	_populate(card, db, card.tags, card.demands, card.effects, effective_cost, true)


## Compact view of a BUILT development: live DevelopmentState tags/effects
## (which may differ from the printed card after a supersession), no cost
## badge, no flavor.
func setup_development(card: CardDef, db: ContentDB, dev: DevelopmentState) -> void:
	custom_minimum_size = COMPACT_SIZE
	_populate(card, db, dev.tags, dev.demands, dev.effects, -1, false)
	_flavor_label.visible = false
	if dev.superseded_count > 0:
		_tooltip_lines.append("Took this form at an age boundary.")
		_apply_tooltip()


## Marks a card as picked for discard: tinted border, no grey-out (the card is
## still perfectly playable — the player chose it).
func set_marked(marked: bool, hint: String = "") -> void:
	_marked = marked
	_style.border_color = BORDER_MARKED if marked else BORDER_NORMAL
	_style.set_border_width_all(2 if marked else 1)
	if hint != "":
		_tooltip_lines.append(hint)
		_apply_tooltip()


## Greys the card out and disables hover/click; `reason` becomes the tooltip.
func set_disabled(disabled: bool, reason: String = "") -> void:
	_disabled = disabled
	modulate = DISABLED_MODULATE if disabled else Color.WHITE
	if disabled and reason != "":
		tooltip_text = reason
	else:
		_apply_tooltip()


## Non-interactive cards (e.g. on the transition screen) keep their normal
## colors but never hover or emit clicks.
func set_interactive(interactive: bool) -> void:
	_interactive = interactive


# --- private ----------------------------------------------------------------

func _populate(card: CardDef, db: ContentDB, tags: Array[String],
		demands: Dictionary, effects: Array[EffectDef], effective_cost: int,
		show_badge: bool) -> void:
	card_id = card.id
	_tooltip_lines.clear()
	_name_label.text = card.display_name
	_header_style.bg_color = _header_tint(card, tags)

	_badge_panel.visible = show_badge
	if show_badge:
		var shown_cost: int = card.cost if effective_cost < 0 else effective_cost
		_badge_label.text = str(shown_cost)
		_badge_style.bg_color = BADGE_NEUTRAL
		if effective_cost >= 0 and effective_cost != card.cost:
			_badge_style.bg_color = BADGE_CHEAPER if effective_cost < card.cost else BADGE_DEARER
			_tooltip_lines.append("base %d" % card.cost)

	_clear_children(_chips_row)
	for tag: String in tags:
		_chips_row.add_child(_make_chip(tag))
	if card.category == CardDef.CATEGORY_ACTION:
		_chips_row.add_child(_make_chip("action"))

	_clear_children(_body_box)
	# Printed demand values first: they are the card's real price, and the
	# cross-demand cost has to be visible before the card is played (GDD 4.0).
	var demand_ids: Array = demands.keys()
	demand_ids.sort()
	for demand_id: String in demand_ids:
		var amount: int = int(demands[demand_id])
		if amount == 0:
			continue
		var demand_label := Label.new()
		demand_label.text = EffectText.describe_printed_demand(demand_id, amount, db)
		demand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		demand_label.add_theme_font_size_override("font_size", 12)
		demand_label.add_theme_color_override("font_color",
			DEMAND_MITIGATE if amount < 0 else DEMAND_AGGRAVATE)
		demand_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body_box.add_child(demand_label)
	for line: String in EffectText.describe_all(effects, db):
		var effect_label := Label.new()
		effect_label.text = line
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_label.add_theme_font_size_override("font_size", 11)
		effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body_box.add_child(effect_label)
	# Printed protection (GDD 4.4): a hazard type the player can plan around
	# without knowing which specific events exist.
	if not card.cancels.is_empty():
		var protects := Label.new()
		protects.text = "⛨ Prevents %s damage" % ", ".join(card.cancels)
		protects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		protects.add_theme_font_size_override("font_size", 11)
		protects.add_theme_color_override("font_color", Color(0.6, 0.82, 0.66))
		protects.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body_box.add_child(protects)
	if card.hand_limit_bonus != 0:
		var capacity := Label.new()
		capacity.text = "Hand limit %+d" % card.hand_limit_bonus
		capacity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		capacity.add_theme_font_size_override("font_size", 11)
		capacity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body_box.add_child(capacity)
	if card.opens_paths():
		var paths_label := Label.new()
		paths_label.text = "✦ Opens new paths"
		paths_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		paths_label.add_theme_font_size_override("font_size", 11)
		paths_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.35))
		paths_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body_box.add_child(paths_label)

	_flavor_label.visible = card.flavor != ""
	_flavor_label.text = card.flavor
	_apply_tooltip()


func _header_tint(card: CardDef, tags: Array[String]) -> Color:
	if card.category == CardDef.CATEGORY_ACTION or tags.is_empty():
		return ACTION_TINT
	return TAG_TINTS.get(tags[0], ACTION_TINT) as Color


func _make_chip(tag: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_style := StyleBoxFlat.new()
	var tint: Color = TAG_TINTS.get(tag, ACTION_TINT) as Color
	chip_style.bg_color = Color(tint.r, tint.g, tint.b, 0.55)
	chip_style.set_corner_radius_all(5)
	chip_style.content_margin_left = 5.0
	chip_style.content_margin_right = 5.0
	chip_style.content_margin_top = 1.0
	chip_style.content_margin_bottom = 1.0
	chip.add_theme_stylebox_override("panel", chip_style)
	var chip_label := Label.new()
	chip_label.text = tag
	chip_label.add_theme_font_size_override("font_size", 10)
	chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(chip_label)
	return chip


func _apply_tooltip() -> void:
	tooltip_text = "\n".join(_tooltip_lines)


func _gui_input(event: InputEvent) -> void:
	if _disabled or not _interactive:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		card_clicked.emit(card_id)


func _on_mouse_entered() -> void:
	if _disabled or not _interactive:
		return
	pivot_offset = Vector2(size.x * 0.5, size.y)
	z_index = 1
	_style.border_color = BORDER_HOVER
	_style.set_border_width_all(2)
	_start_scale_tween(HOVER_SCALE)


func _on_mouse_exited() -> void:
	z_index = 0
	_style.border_color = BORDER_MARKED if _marked else BORDER_NORMAL
	_style.set_border_width_all(2 if _marked else 1)
	_start_scale_tween(Vector2.ONE)


func _start_scale_tween(target: Vector2) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	if not is_inside_tree():
		scale = target
		return
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", target, HOVER_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
