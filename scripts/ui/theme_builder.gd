class_name ThemeBuilder
extends RefCounted
## The game's dark UI theme, built in code. Tweak colours here.

const BG := Color(0.07, 0.063, 0.085, 0.94)
const BG_SOLID := Color(0.07, 0.063, 0.085)
const PANEL := Color(0.11, 0.10, 0.13)
const PANEL_HI := Color(0.15, 0.135, 0.18)
const BORDER := Color(0.20, 0.18, 0.24)
const TEXT := Color(0.87, 0.83, 0.76)
const DIM := Color(0.55, 0.52, 0.5)
const ACCENT := Color(0.95, 0.70, 0.30)
const MONEY := Color(0.56, 0.89, 0.53)
const APPROVAL := Color(1.0, 0.82, 0.38)
const BAD := Color(0.85, 0.42, 0.38)

static var body_font: Font = preload("res://assets/fonts/PixelifySans.ttf")
static var title_font: Font = preload("res://assets/fonts/Silkscreen-Regular.ttf")


static func box(bg: Color, border := BORDER, width := 1, margin := 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = false
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font
	t.default_font_size = 16

	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("normal", "Button", box(PANEL))
	t.set_stylebox("hover", "Button", box(PANEL_HI, ACCENT))
	t.set_stylebox("pressed", "Button", box(Color(0.2, 0.17, 0.12), ACCENT))
	t.set_stylebox("hover_pressed", "Button", box(Color(0.22, 0.19, 0.13), ACCENT))
	t.set_stylebox("disabled", "Button", box(Color(0.08, 0.072, 0.095)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", DIM)

	t.set_stylebox("panel", "PanelContainer", box(BG))
	t.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4.0))
	var tab_sel := box(PANEL, ACCENT, 0, 6.0)
	tab_sel.border_width_bottom = 2
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6.0))
	t.set_stylebox("tab_hovered", "TabContainer", box(PANEL_HI, Color(0, 0, 0, 0), 0, 6.0))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_font("font", "TabContainer", title_font)
	t.set_font_size("font_size", "TabContainer", 12)

	t.set_stylebox("background", "ProgressBar", box(PANEL, BORDER, 1, 0.0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, ACCENT, 0, 0.0))

	t.set_stylebox("panel", "TooltipPanel", box(Color(0.05, 0.045, 0.06, 0.97), ACCENT, 1, 8.0))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 15)

	var grab := box(BORDER, BORDER, 0, 0.0)
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0.0))
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(DIM, DIM, 0, 0.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, ACCENT, 0, 0.0))

	t.set_stylebox("slider", "HSlider", box(PANEL, BORDER, 1, 2.0))
	t.set_stylebox("separator", "HSeparator", box(BORDER, BORDER, 0, 0.0))
	return t
