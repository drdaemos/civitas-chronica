class_name DemandMeter
extends PanelContainer

## Compact, persistent demand readout for the command bar. A demand is an
## unmet need: low is good, the tolerance mark is where emergencies begin,
## and the far-right end is catastrophe territory.

const BG_CALM: Color = Color("#182825")
const BG_WARNING: Color = Color("#332b1d")
const BG_DANGER: Color = Color("#381f22")
const BORDER_CALM: Color = Color("#335c53")
const BORDER_WARNING: Color = Color("#a47d35")
const BORDER_DANGER: Color = Color("#b94f58")
const FILL_CALM: Color = Color("#58a38f")
const FILL_WARNING: Color = Color("#d6a64a")
const FILL_DANGER: Color = Color("#dc6269")
const TEXT_PRIMARY: Color = Color("#f1eadb")
const TEXT_MUTED: Color = Color("#aaa394")

var demand_id: String = ""

var _style: StyleBoxFlat = null
var _name_label: Label = null
var _value_label: Label = null
var _growth_label: Label = null
var _status_label: Label = null
var _bar: ProgressBar = null
var _target_value: int = 0
var _threshold: int = 0
var _catastrophe: int = 0
var _tween: Tween = null


func _init() -> void:
	custom_minimum_size = Vector2(190, 82)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style = StyleBoxFlat.new()
	_style.bg_color = BG_CALM
	_style.set_corner_radius_all(8)
	_style.set_border_width_all(1)
	_style.border_color = BORDER_CALM
	_style.content_margin_left = 12.0
	_style.content_margin_right = 12.0
	_style.content_margin_top = 8.0
	_style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", _style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	top.add_child(_name_label)
	_value_label = Label.new()
	_value_label.add_theme_font_size_override("font_size", 18)
	_value_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	top.add_child(_value_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("#0b1110")
	bar_bg.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bar_bg)
	column.add_child(_bar)

	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", TEXT_MUTED)
	bottom.add_child(_status_label)
	_growth_label = Label.new()
	_growth_label.add_theme_font_size_override("font_size", 11)
	bottom.add_child(_growth_label)


func setup(demand: DemandDef, start_value: int, target_value: int, growth: int,
		threshold: int, catastrophe: int) -> void:
	demand_id = demand.id
	_name_label.text = demand.display_name.to_upper()
	_target_value = target_value
	_threshold = threshold
	_catastrophe = catastrophe
	_bar.min_value = 0
	_bar.max_value = maxi(catastrophe, threshold + 1)
	_set_value(start_value)
	_growth_label.text = "stable" if growth == 0 else "+%d / turn" % growth
	_growth_label.add_theme_color_override(
		"font_color", Color("#72b69f") if growth == 0 else Color("#e2b65e"))
	tooltip_text = "%s\nCurrent unmet need: %d\nIncreases by %d next turn\nEmergencies begin at %d; catastrophe at %d." % [
		demand.description, target_value, growth, threshold, catastrophe,
	]
	if start_value != target_value:
		call_deferred("_animate_to_target")


func _animate_to_target() -> void:
	if not is_inside_tree():
		_set_value(_target_value)
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var start: float = _bar.value
	_tween = create_tween()
	_tween.tween_method(_set_animated_value, start, float(_target_value), 0.7) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_animated_value(value: float) -> void:
	_set_value(int(round(value)))


func _set_value(value: int) -> void:
	_bar.value = value
	_value_label.text = "%d / %d" % [value, _threshold]
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(4)
	if value >= _catastrophe:
		_style.bg_color = BG_DANGER
		_style.border_color = BORDER_DANGER
		fill.bg_color = FILL_DANGER
		_status_label.text = "CATASTROPHE RISK"
		_status_label.add_theme_color_override("font_color", FILL_DANGER)
	elif value >= _threshold:
		_style.bg_color = BG_WARNING
		_style.border_color = BORDER_WARNING
		fill.bg_color = FILL_WARNING
		_status_label.text = "EMERGENCIES"
		_status_label.add_theme_color_override("font_color", FILL_WARNING)
	elif value == 0:
		_style.bg_color = BG_CALM
		_style.border_color = BORDER_CALM
		fill.bg_color = FILL_CALM
		_status_label.text = "SATISFIED"
		_status_label.add_theme_color_override("font_color", FILL_CALM)
	else:
		_style.bg_color = BG_CALM
		_style.border_color = BORDER_CALM
		fill.bg_color = FILL_CALM
		_status_label.text = "MANAGEABLE"
		_status_label.add_theme_color_override("font_color", TEXT_MUTED)
	_bar.add_theme_stylebox_override("fill", fill)
