extends RefCounted
class_name UITheme
## Design tokens from docs/ART_BIBLE.md §2 (light theme) and small factory helpers so every
## screen builds its widgets the same way. Fonts: the engine default with system fallback until
## Noto Sans JP is bundled (see game/assets/ASSETS.md).

# --- palette (ART_BIBLE §2.4)
const BG := Color("#FBF6EC")
const SURFACE := Color("#FFFDF8")
const SURFACE_ALT := Color("#F3EBDC")
const BORDER := Color("#E3D8C3")
const TEXT_PRIMARY := Color("#2B2520")
const TEXT_SECONDARY := Color("#6B6159")
const TEXT_DISABLED := Color("#A69C91")
const PRIMARY := Color("#C4521F")
const PRIMARY_HOVER := Color("#A8441A")
const PRIMARY_TINT := Color("#FBE9DD")
const CORRECT := Color("#2F7D5B")
const CORRECT_TINT := Color("#E1F1E8")
const INCORRECT := Color("#B83A4B")
const INCORRECT_TINT := Color("#F7E2E5")
const NEUTRAL := Color("#3A6EA5")
const NEUTRAL_TINT := Color("#E2ECF6")
const WARNING := Color("#B8860B")
const ON_PRIMARY := Color("#FFFDF8")

# --- six skill colours (ART_BIBLE §2.5): fill for bars, ink for text
const SKILL_FILL := {
	&"vocab": Color("#E0A526"), &"grammar": Color("#3A6EA5"), &"reading": Color("#2F7D5B"),
	&"listening": Color("#7B5EA7"), &"conversation": Color("#D65D7A"), &"kanji": Color("#8B5E3C"),
}
const SKILL_INK := {
	&"vocab": Color("#7A5A0E"), &"grammar": Color("#2A5280"), &"reading": Color("#245F45"),
	&"listening": Color("#5C4580"), &"conversation": Color("#A23A54"), &"kanji": Color("#67432A"),
}

# --- type scale (ART_BIBLE §2.3)
const SIZE_DISPLAY := 44
const SIZE_H1 := 36
const SIZE_H2 := 30
const SIZE_BODY_L := 26
const SIZE_BODY := 24
const SIZE_LABEL := 22
const SIZE_CAPTION := 20

# --- spacing / shape (ART_BIBLE §2.7)
const PAD_CARD := 24
const GAP := 16
const GAP_SECTION := 32
const RADIUS_CARD := 12
const RADIUS_BUTTON := 10
const COLUMN_WIDTH := 960
const BUTTON_HEIGHT := 48


## Build the project Theme once; main.gd assigns it to the root Control.
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = SIZE_BODY

	t.set_color("font_color", "Label", TEXT_PRIMARY)
	t.set_font_size("font_size", "Label", SIZE_BODY)

	# Buttons: primary look by default; secondary via set_secondary().
	t.set_stylebox("normal", "Button", _flat(PRIMARY, RADIUS_BUTTON))
	t.set_stylebox("hover", "Button", _flat(PRIMARY_HOVER, RADIUS_BUTTON))
	t.set_stylebox("pressed", "Button", _flat(PRIMARY_HOVER, RADIUS_BUTTON))
	t.set_stylebox("disabled", "Button", _flat(SURFACE_ALT, RADIUS_BUTTON))
	t.set_stylebox("focus", "Button", _outline(NEUTRAL, RADIUS_BUTTON, 2))
	t.set_color("font_color", "Button", ON_PRIMARY)
	t.set_color("font_hover_color", "Button", ON_PRIMARY)
	t.set_color("font_pressed_color", "Button", ON_PRIMARY)
	t.set_color("font_focus_color", "Button", ON_PRIMARY)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_font_size("font_size", "Button", SIZE_LABEL)

	t.set_stylebox("panel", "PanelContainer", _card())
	t.set_stylebox("panel", "Panel", _flat(BG, 0))

	t.set_stylebox("normal", "LineEdit", _flat(SURFACE, RADIUS_BUTTON, BORDER, 1))
	t.set_stylebox("focus", "LineEdit", _flat(SURFACE, RADIUS_BUTTON, NEUTRAL, 2))
	t.set_color("font_color", "LineEdit", TEXT_PRIMARY)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DISABLED)
	t.set_font_size("font_size", "LineEdit", SIZE_BODY)

	t.set_stylebox("panel", "ItemList", _flat(SURFACE, RADIUS_CARD, BORDER, 1))
	t.set_stylebox("selected", "ItemList", _flat(PRIMARY_TINT, 6))
	t.set_stylebox("selected_focus", "ItemList", _flat(PRIMARY_TINT, 6))
	t.set_stylebox("hovered", "ItemList", _flat(SURFACE_ALT, 6))
	t.set_color("font_color", "ItemList", TEXT_PRIMARY)
	t.set_color("font_selected_color", "ItemList", TEXT_PRIMARY)
	t.set_color("font_hovered_color", "ItemList", TEXT_PRIMARY)
	t.set_font_size("font_size", "ItemList", SIZE_BODY)
	t.set_constant("v_separation", "ItemList", 8)

	t.set_stylebox("background", "ProgressBar", _flat(SURFACE_ALT, 6))
	t.set_stylebox("fill", "ProgressBar", _flat(PRIMARY, 6))

	t.set_stylebox("normal", "OptionButton", _flat(SURFACE, RADIUS_BUTTON, BORDER, 1))
	t.set_stylebox("hover", "OptionButton", _flat(SURFACE_ALT, RADIUS_BUTTON, BORDER, 1))
	t.set_stylebox("pressed", "OptionButton", _flat(SURFACE_ALT, RADIUS_BUTTON, BORDER, 1))
	t.set_stylebox("focus", "OptionButton", _outline(NEUTRAL, RADIUS_BUTTON, 2))
	t.set_color("font_color", "OptionButton", TEXT_PRIMARY)
	t.set_color("font_hover_color", "OptionButton", TEXT_PRIMARY)
	t.set_color("font_pressed_color", "OptionButton", TEXT_PRIMARY)
	t.set_color("font_focus_color", "OptionButton", TEXT_PRIMARY)
	t.set_font_size("font_size", "OptionButton", SIZE_CAPTION)
	t.set_stylebox("panel", "PopupMenu", _flat(SURFACE, RADIUS_BUTTON, BORDER, 1))
	t.set_color("font_color", "PopupMenu", TEXT_PRIMARY)
	t.set_font_size("font_size", "PopupMenu", SIZE_CAPTION)
	return t


static func _flat(bg: Color, radius: int, border: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func _outline(color: Color, radius: int, width: int) -> StyleBoxFlat:
	var sb := _flat(Color.TRANSPARENT, radius, color, width)
	sb.expand_margin_left = 2
	sb.expand_margin_right = 2
	sb.expand_margin_top = 2
	sb.expand_margin_bottom = 2
	return sb


static func _card(bg: Color = SURFACE, border: Color = BORDER) -> StyleBoxFlat:
	var sb := _flat(bg, RADIUS_CARD, border, 1)
	sb.content_margin_left = PAD_CARD
	sb.content_margin_right = PAD_CARD
	sb.content_margin_top = PAD_CARD
	sb.content_margin_bottom = PAD_CARD
	sb.shadow_color = Color(0.17, 0.145, 0.125, 0.08)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 2)
	return sb


# ---------------------------------------------------------------- factories

## A card panel. Pass a tint (CORRECT_TINT etc.) for feedback cards.
static func card(bg: Color = SURFACE, border: Color = BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _card(bg, border))
	return p


static func vbox(gap: int = GAP) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	return v


static func hbox(gap: int = GAP) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	return h


## Plain (kana / Latin / digits) label. Never use for text containing kanji; use ja() instead.
static func label(text: String, size: int = SIZE_BODY, color: Color = TEXT_PRIMARY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## English support text: 0.83x the Japanese base, secondary colour (ART_BIBLE §2.2 rule 8).
static func en(text: String, base_size: int = SIZE_BODY) -> Label:
	return label(text, maxi(18, roundi(base_size * 0.83)), TEXT_SECONDARY)


## Japanese text with furigana markup ("{漢字|かんじ}").
static func ja(markup: String, size: int = SIZE_BODY, color: Color = TEXT_PRIMARY) -> FuriganaLabel:
	var f := FuriganaLabel.new()
	f.text = markup
	f.font_size = size
	f.color = color
	return f


static func button(text: String, primary: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = BUTTON_HEIGHT
	if not primary:
		set_secondary(b)
	return b


## Secondary look: surface fill, primary border and text.
static func set_secondary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _flat(SURFACE, RADIUS_BUTTON, PRIMARY, 2))
	b.add_theme_stylebox_override("hover", _flat(PRIMARY_TINT, RADIUS_BUTTON, PRIMARY, 2))
	b.add_theme_stylebox_override("pressed", _flat(PRIMARY_TINT, RADIUS_BUTTON, PRIMARY_HOVER, 2))
	b.add_theme_color_override("font_color", PRIMARY)
	b.add_theme_color_override("font_hover_color", PRIMARY_HOVER)
	b.add_theme_color_override("font_pressed_color", PRIMARY_HOVER)
	b.add_theme_color_override("font_focus_color", PRIMARY)


## Quiet look used for option tiles: surface fill, hairline border, dark text.
static func set_tile(b: Button, fill: Color = SURFACE, border: Color = BORDER) -> void:
	b.add_theme_stylebox_override("normal", _flat(fill, RADIUS_BUTTON, border, 2))
	b.add_theme_stylebox_override("hover", _flat(fill, RADIUS_BUTTON, PRIMARY, 2))
	b.add_theme_stylebox_override("pressed", _flat(PRIMARY_TINT, RADIUS_BUTTON, PRIMARY, 2))
	b.add_theme_stylebox_override("disabled", _flat(SURFACE_ALT, RADIUS_BUTTON, BORDER, 2))
	b.add_theme_color_override("font_color", TEXT_PRIMARY)
	b.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	b.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	b.add_theme_color_override("font_focus_color", TEXT_PRIMARY)


static func progress_bar(fill: Color, value: float) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 100
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, 14)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("fill", _flat(fill, 6))
	return p


static func spacer(height: int = GAP) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func hspacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
