class_name UiStyle
extends RefCounted

## Shared visual language for the data-view UI. Components own their layouts;
## this file owns color, spacing primitives, and the application-wide theme.

const INK: Color = Color("#eee7d8")
const MUTED: Color = Color("#aaa394")
const FAINT: Color = Color("#777267")
const GOLD: Color = Color("#d1a85a")
const GOLD_BRIGHT: Color = Color("#efcb7a")
const GREEN: Color = Color("#66ad93")
const AMBER: Color = Color("#d7a94f")
const RED: Color = Color("#d9676e")
const BG_DEEP: Color = Color("#0c1012")
const BG_PANEL: Color = Color("#141a1d")
const BG_RAISED: Color = Color("#1a2225")
const BG_HOVER: Color = Color("#253137")
const BORDER: Color = Color("#364247")
const BORDER_LIGHT: Color = Color("#526167")


static func install(root: Control) -> void:
	var app_theme := Theme.new()
	app_theme.default_font_size = 15
	app_theme.set_color("font_color", "Label", INK)
	app_theme.set_color("font_color", "Button", INK)
	app_theme.set_color("font_hover_color", "Button", Color.WHITE)
	app_theme.set_color("font_pressed_color", "Button", GOLD_BRIGHT)
	app_theme.set_color("font_disabled_color", "Button", FAINT)
	app_theme.set_color("default_color", "RichTextLabel", INK)
	app_theme.set_color("font_color", "RichTextLabel", INK)
	app_theme.set_constant("outline_size", "Label", 0)
	app_theme.set_constant("separation", "VBoxContainer", 8)
	app_theme.set_constant("separation", "HBoxContainer", 8)

	app_theme.set_stylebox("normal", "Button", button_style(BG_RAISED, BORDER))
	app_theme.set_stylebox("hover", "Button", button_style(BG_HOVER, GOLD))
	app_theme.set_stylebox("pressed", "Button", button_style(Color("#101719"), GOLD_BRIGHT))
	app_theme.set_stylebox("disabled", "Button", button_style(Color("#111619"), Color("#2a3235")))
	app_theme.set_stylebox("focus", "Button", button_style(Color.TRANSPARENT, GOLD_BRIGHT, 2))
	app_theme.set_stylebox("panel", "PanelContainer", panel_style(BG_PANEL, BORDER))
	root.theme = app_theme


static func panel_style(background: Color = BG_PANEL, border: Color = BORDER,
		radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


static func padded_panel_style(background: Color = BG_PANEL, border: Color = BORDER,
		padding: float = 14.0, radius: int = 8) -> StyleBoxFlat:
	var style: StyleBoxFlat = panel_style(background, border, radius)
	style.set_content_margin_all(padding)
	return style


static func button_style(background: Color, border: Color,
		border_width: int = 1) -> StyleBoxFlat:
	var style: StyleBoxFlat = padded_panel_style(background, border, 10.0, 6)
	style.set_border_width_all(border_width)
	return style


static func heading(text: String, size: int = 12) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD)
	return label


static func muted(text: String, size: int = 12) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", MUTED)
	return label


static func clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
