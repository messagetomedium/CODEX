extends RefCounted
## Shared blockout styling; layout and text stay in configuration.

const INK := Color("#183746")
const PAPER := Color("#faf6ed")
const ACCENT := Color("#edc55c")

static func style(fill: Color, border: Color = Color.TRANSPARENT, radius: int = 20) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2 if border.a > 0 else 0)
	box.set_corner_radius_all(radius)
	return box

static func label(parent: Node, content: String, rect: Rect2, font_size: int, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = content
	node.position = rect.position
	node.size = rect.size
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

static func button(parent: Node, content: String, rect: Rect2, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = content
	node.position = rect.position
	node.size = rect.size
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 26)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	node.add_theme_color_override("font_disabled_color", INK)
	var fill := ACCENT if primary else PAPER
	node.add_theme_stylebox_override("normal", style(fill, INK))
	node.add_theme_stylebox_override("hover", style(fill.lightened(0.1), INK))
	node.add_theme_stylebox_override("pressed", style(fill.darkened(0.08), INK))
	node.add_theme_stylebox_override("disabled", style(PAPER.darkened(0.08), INK))
	parent.add_child(node)
	return node
