extends RefCounted
class_name UITheme
## Design tokens from docs/ART_BIBLE.md §2 with light and dark palettes, bundled fonts, and small
## factory helpers so every screen builds widgets the same way. Tokens are static vars:
## apply(dark, accessible_font) switches them, then main.gd rebuilds the theme and the screen.

const FONT_NOTO := "res://assets/fonts/NotoSansJP-Variable.ttf"
const FONT_BIZ_REGULAR := "res://assets/fonts/BIZUDPGothic-Regular.ttf"
const FONT_BIZ_BOLD := "res://assets/fonts/BIZUDPGothic-Bold.ttf"

const LIGHT := {
	"bg": "#FBF6EC", "surface": "#FFFDF8", "surface_alt": "#F3EBDC", "border": "#E3D8C3",
	"text_primary": "#2B2520", "text_secondary": "#6B6159", "text_disabled": "#A69C91",
	"primary": "#C4521F", "primary_hover": "#A8441A", "primary_tint": "#FBE9DD", "on_primary": "#FFFDF8",
	"correct": "#2F7D5B", "correct_tint": "#E1F1E8", "incorrect": "#B83A4B", "incorrect_tint": "#F7E2E5",
	"neutral": "#3A6EA5", "neutral_tint": "#E2ECF6", "warning": "#B8860B", "shadow_alpha": 0.08,
	"skill_fill": {"vocab": "#E0A526", "grammar": "#3A6EA5", "reading": "#2F7D5B", "listening": "#7B5EA7", "conversation": "#D65D7A", "kanji": "#8B5E3C"},
	"skill_ink": {"vocab": "#7A5A0E", "grammar": "#2A5280", "reading": "#245F45", "listening": "#5C4580", "conversation": "#A23A54", "kanji": "#67432A"},
}
const DARK := {
	"bg": "#1C1917", "surface": "#26221F", "surface_alt": "#302B27", "border": "#3E3733",
	"text_primary": "#F3EDE4", "text_secondary": "#B5ABA0", "text_disabled": "#6E655D",
	"primary": "#E8824F", "primary_hover": "#F09A6E", "primary_tint": "#3F2A1E", "on_primary": "#1C1917",
	"correct": "#5BBF8A", "correct_tint": "#1E3A2C", "incorrect": "#E26A79", "incorrect_tint": "#3F2228",
	"neutral": "#7FA7D9", "neutral_tint": "#1F2D3E", "warning": "#E0B341", "shadow_alpha": 0.0,
	"skill_fill": {"vocab": "#F0BE4A", "grammar": "#6A9AD0", "reading": "#5BBF8A", "listening": "#A58BD0", "conversation": "#E8809A", "kanji": "#B88A64"},
	"skill_ink": {"vocab": "#F0BE4A", "grammar": "#6A9AD0", "reading": "#5BBF8A", "listening": "#A58BD0", "conversation": "#E8809A", "kanji": "#B88A64"},
}

# --- palette (ART_BIBLE §2.4 / §2.6), switched by apply()
static var BG := Color("#FBF6EC")
static var SURFACE := Color("#FFFDF8")
static var SURFACE_ALT := Color("#F3EBDC")
static var BORDER := Color("#E3D8C3")
static var TEXT_PRIMARY := Color("#2B2520")
static var TEXT_SECONDARY := Color("#6B6159")
static var TEXT_DISABLED := Color("#A69C91")
static var PRIMARY := Color("#C4521F")
static var PRIMARY_HOVER := Color("#A8441A")
static var PRIMARY_TINT := Color("#FBE9DD")
static var ON_PRIMARY := Color("#FFFDF8")
static var CORRECT := Color("#2F7D5B")
static var CORRECT_TINT := Color("#E1F1E8")
static var INCORRECT := Color("#B83A4B")
static var INCORRECT_TINT := Color("#F7E2E5")
static var NEUTRAL := Color("#3A6EA5")
static var NEUTRAL_TINT := Color("#E2ECF6")
static var WARNING := Color("#B8860B")
static var SHADOW_ALPHA := 0.08
static var SKILL_FILL := {}
static var SKILL_INK := {}
static var dark := false

# --- fonts
static var _fonts := {}  # weight int -> Font
static var accessible_font := false

# --- type scale (ART_BIBLE §2.3)
const SIZE_DISPLAY := 44
const SIZE_H1 := 36
const SIZE_H2 := 30
const SIZE_BODY_L := 26
const SIZE_BODY := 24
const SIZE_LABEL := 22
const SIZE_CAPTION := 20
const SIZE_EN_SUB := 17   # English subtitles under Japanese labels (beginner help)

# --- spacing / shape (ART_BIBLE §2.7)
const PAD_CARD := 24
const GAP := 16
const GAP_SECTION := 32
const RADIUS_CARD := 12
const RADIUS_BUTTON := 10
const COLUMN_WIDTH := 960
const BUTTON_HEIGHT := 48

# --- motion (ART_BIBLE §2.9): short, no bounce
const ANIM_IN := 0.16
const ANIM_CELEBRATE := 0.32


## Switch palette and font family. Call before build_theme(); screens must be rebuilt after.
static func apply(use_dark: bool, use_accessible_font: bool) -> void:
	dark = use_dark
	accessible_font = use_accessible_font
	var p: Dictionary = DARK if use_dark else LIGHT
	BG = Color(p["bg"])
	SURFACE = Color(p["surface"])
	SURFACE_ALT = Color(p["surface_alt"])
	BORDER = Color(p["border"])
	TEXT_PRIMARY = Color(p["text_primary"])
	TEXT_SECONDARY = Color(p["text_secondary"])
	TEXT_DISABLED = Color(p["text_disabled"])
	PRIMARY = Color(p["primary"])
	PRIMARY_HOVER = Color(p["primary_hover"])
	PRIMARY_TINT = Color(p["primary_tint"])
	ON_PRIMARY = Color(p["on_primary"])
	CORRECT = Color(p["correct"])
	CORRECT_TINT = Color(p["correct_tint"])
	INCORRECT = Color(p["incorrect"])
	INCORRECT_TINT = Color(p["incorrect_tint"])
	NEUTRAL = Color(p["neutral"])
	NEUTRAL_TINT = Color(p["neutral_tint"])
	WARNING = Color(p["warning"])
	SHADOW_ALPHA = float(p["shadow_alpha"])
	SKILL_FILL = {}
	SKILL_INK = {}
	for key: String in p["skill_fill"]:
		SKILL_FILL[StringName(key)] = Color(p["skill_fill"][key])
		SKILL_INK[StringName(key)] = Color(p["skill_ink"][key])
	_fonts.clear()


## The UI font at a weight (400 regular, 500 medium, 700 bold). Falls back to the engine
## default when the bundled font is missing (e.g. a stripped test checkout).
static func font(weight: int = 400) -> Font:
	if SKILL_FILL.is_empty():
		apply(dark, accessible_font)
	if _fonts.has(weight):
		return _fonts[weight]
	var f: Font
	if accessible_font:
		var path := FONT_BIZ_BOLD if weight >= 600 else FONT_BIZ_REGULAR
		f = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	elif ResourceLoader.exists(FONT_NOTO):
		var v := FontVariation.new()
		v.base_font = load(FONT_NOTO)
		# Keys must be OpenType tags as integers; a String key is ignored and the font falls
		# back to its default (thinnest) instance.
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		f = v
	else:
		f = ThemeDB.fallback_font
	_fonts[weight] = f
	return f


## Weight for a size on the type scale (display/h1 bold, h2/label medium, body regular).
static func weight_for(size: int) -> int:
	if size >= SIZE_H1:
		return 700
	if size == SIZE_H2 or size == SIZE_LABEL:
		return 500
	return 400


static func build_theme() -> Theme:
	if SKILL_FILL.is_empty():
		apply(dark, accessible_font)
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = SIZE_BODY

	t.set_color("font_color", "Label", TEXT_PRIMARY)
	t.set_font_size("font_size", "Label", SIZE_BODY)

	t.set_stylebox("normal", "Button", _flat(PRIMARY, RADIUS_BUTTON))
	t.set_stylebox("hover", "Button", _flat(PRIMARY_HOVER, RADIUS_BUTTON))
	t.set_stylebox("pressed", "Button", _flat(PRIMARY_HOVER, RADIUS_BUTTON))
	t.set_stylebox("disabled", "Button", _flat(SURFACE_ALT, RADIUS_BUTTON))
	t.set_stylebox("focus", "Button", _outline(NEUTRAL, RADIUS_BUTTON, 2))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", ON_PRIMARY)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_font_size("font_size", "Button", SIZE_LABEL)
	t.set_font("font", "Button", font(500))

	t.set_stylebox("panel", "PanelContainer", _card())
	t.set_stylebox("panel", "Panel", _flat(BG, 0))

	t.set_stylebox("normal", "LineEdit", _flat(SURFACE, RADIUS_BUTTON, BORDER, 1))
	t.set_stylebox("focus", "LineEdit", _flat(SURFACE, RADIUS_BUTTON, NEUTRAL, 2))
	t.set_color("font_color", "LineEdit", TEXT_PRIMARY)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DISABLED)
	t.set_color("caret_color", "LineEdit", TEXT_PRIMARY)
	t.set_font_size("font_size", "LineEdit", SIZE_BODY)

	t.set_stylebox("panel", "ItemList", _flat(SURFACE, RADIUS_CARD, BORDER, 1))
	t.set_stylebox("focus", "ItemList", _outline(NEUTRAL, RADIUS_CARD, 2))
	t.set_stylebox("selected", "ItemList", _flat(PRIMARY_TINT, 6))
	t.set_stylebox("selected_focus", "ItemList", _flat(PRIMARY_TINT, 6))
	t.set_stylebox("hovered", "ItemList", _flat(SURFACE_ALT, 6))
	for state in ["font_color", "font_selected_color", "font_hovered_color"]:
		t.set_color(state, "ItemList", TEXT_PRIMARY)
	t.set_font_size("font_size", "ItemList", SIZE_BODY)
	t.set_constant("v_separation", "ItemList", 8)

	t.set_stylebox("background", "ProgressBar", _flat(SURFACE_ALT, 6))
	t.set_stylebox("fill", "ProgressBar", _flat(PRIMARY, 6))

	for cls in ["OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, _flat(SURFACE, RADIUS_BUTTON, BORDER, 1))
		t.set_stylebox("hover", cls, _flat(SURFACE_ALT, RADIUS_BUTTON, BORDER, 1))
		t.set_stylebox("pressed", cls, _flat(SURFACE_ALT, RADIUS_BUTTON, BORDER, 1))
		t.set_stylebox("hover_pressed", cls, _flat(SURFACE_ALT, RADIUS_BUTTON, BORDER, 1))
		t.set_stylebox("focus", cls, _outline(NEUTRAL, RADIUS_BUTTON, 2))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(state, cls, TEXT_PRIMARY)
		t.set_font_size("font_size", cls, SIZE_LABEL)
	t.set_stylebox("panel", "PopupMenu", _flat(SURFACE, RADIUS_BUTTON, BORDER, 1))
	t.set_stylebox("hover", "PopupMenu", _flat(PRIMARY_TINT, 6))
	t.set_color("font_color", "PopupMenu", TEXT_PRIMARY)
	t.set_color("font_hover_color", "PopupMenu", TEXT_PRIMARY)
	t.set_font_size("font_size", "PopupMenu", SIZE_LABEL)

	t.set_stylebox("slider", "HSlider", _flat(SURFACE_ALT, 4))
	t.set_stylebox("grabber_area", "HSlider", _flat(PRIMARY, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(PRIMARY_HOVER, 4))

	t.set_stylebox("panel", "PopupPanel", _flat(SURFACE, RADIUS_CARD, BORDER, 1))
	t.set_stylebox("panel", "AcceptDialog", _flat(SURFACE, RADIUS_CARD, BORDER, 1))
	t.set_color("font_color", "TooltipLabel", TEXT_PRIMARY)
	t.set_stylebox("panel", "TooltipPanel", _flat(SURFACE, 6, BORDER, 1))
	t.set_font_size("font_size", "TooltipLabel", SIZE_CAPTION)

	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _thin(Color.TRANSPARENT))
		t.set_stylebox("scroll_focus", bar, _thin(Color.TRANSPARENT))
		t.set_stylebox("grabber", bar, _thin(BORDER))
		t.set_stylebox("grabber_highlight", bar, _thin(TEXT_DISABLED))
		t.set_stylebox("grabber_pressed", bar, _thin(TEXT_SECONDARY))
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


## Slim style for scrollbars: no content margins, 8 px wide.
static func _thin(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## Square icon-only button (▶ speak, etc.): small margins so the icon has room.
static func set_icon_button(b: Button, tint: Color = PRIMARY) -> void:
	set_tile(b)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := b.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if sb:
			sb.content_margin_left = 8
			sb.content_margin_right = 8
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			b.add_theme_stylebox_override(state, sb)
	for state in ["icon_normal_color", "icon_focus_color"]:
		b.add_theme_color_override(state, tint)
	for state in ["icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(state, PRIMARY_HOVER)


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
	if SHADOW_ALPHA > 0.0:
		sb.shadow_color = Color(0.17, 0.145, 0.125, SHADOW_ALPHA)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 2)
	return sb


# ---------------------------------------------------------------- factories

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
	l.add_theme_font_override("font", font(weight_for(size)))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## English support text: 0.83× the Japanese base, secondary colour (ART_BIBLE §2.2 rule 8).
static func en(text: String, base_size: int = SIZE_BODY) -> Label:
	var l := label(text, maxi(18, roundi(base_size * 0.83)), TEXT_SECONDARY)
	l.add_theme_font_override("font", font(400))
	return l


## Japanese text with furigana markup ("{漢字|かんじ}").
static func ja(markup: String, size: int = SIZE_BODY, color: Color = Color(0, 0, 0, 0)) -> FuriganaLabel:
	var f := FuriganaLabel.new()
	f.font_size = size
	f.weight = weight_for(size)
	f.color = TEXT_PRIMARY if color.a == 0.0 else color
	f.ruby_color = TEXT_SECONDARY
	f.text = markup
	return f


## Readings for the fixed UI vocabulary, so button labels written as plain text still get
## furigana (the game's rule: no kanji without its reading). Longest entries match first.
const UI_RUBY := {
	"模擬試験": "もぎしけん", "昇級試験": "しょうきゅうしけん", "選択肢": "せんたくし", "入力": "にゅうりょく",
	"確認": "かくにん", "一回": "いっかい", "一度": "いちど", "辞書": "じしょ", "練習": "れんしゅう",
	"試験": "しけん", "毎日": "まいにち", "学習": "がくしゅう", "報告": "ほうこく", "一覧": "いちらん",
	"選択": "せんたく", "順番": "じゅんばん", "自然": "しぜん", "録音": "ろくおん", "自分": "じぶん",
	"自動": "じどう", "会話": "かいわ", "標準": "ひょうじゅん", "日本語": "にほんご", "説明": "せつめい",
	"英語": "えいご", "表示": "ひょうじ", "読": "よ", "方": "かた", "次": "つぎ", "見": "み", "話": "はな",
	"受": "う", "始": "はじ", "続": "つづ", "町": "まち", "戻": "もど", "文": "ぶん", "作": "つく",
	"書": "か", "出": "だ", "思": "おも", "声": "こえ", "聞": "き", "止": "と", "答": "こた", "合": "あ",
	"減": "へ", "消": "け", "訳": "やく", "済": "す", "全": "ぜん", "部": "ぶ", "直": "なお", "特大": "とくだい", "小": "しょう", "中": "ちゅう", "大": "だい", "文字": "もじ",
}


## English for fixed UI labels, shown under the Japanese while Progress.beginner() is on.
const UI_EN := {
	"次へ": "Next", "ホームへ": "Home", "もう一回": "Again", "選択肢を見る": "Show choices", "辞書へ": "Dictionary",
	"読み方の練習": "Practise readings", "話す": "Talk / say it", "試験を受ける": "Take the exam",
	"練習を始める": "Start practice", "続ける": "Continue", "確認する": "Check", "確認": "Check",
	"町へ戻る": "Back to town", "毎日の確認テスト": "Daily check", "次の文へ": "Next sentence",
	"模擬試験": "Practice exam", "昇級試験": "Stage exam", "文を作る": "Build sentences", "戻る": "Back",
	"学習データをリセット": "Reset progress", "一覧へ": "Back to list", "モード選択": "Choose mode",
	"ヒント": "Hint", "シナリオ一覧": "Scenario list", "やり直す": "Clear", "もう一度": "Try again",
	"この順番も自然だと思う": "This order is natural too", "● 録音": "Record", "■ 止める": "Stop",
	"▶ 自分の声": "My voice", "▶ 聞く": "Listen", "▶ テスト": "Test", "▶ ゆっくり": "Slowly",
	"はじめる": "Start", "報告済み": "Reported", "書き出し済み": "Exported", "報告を書き出す": "Export reports",
	"ライト": "Light", "ダーク": "Dark", "日本語のみ": "Japanese only", "日本語＋説明": "+ explanations",
	"日本語＋訳": "+ translations", "バイリンガル": "Bilingual", "小": "Small", "中": "Medium", "大": "Large",
	"特大": "Extra large", "自動": "Auto",
}


static func en_for(text: String) -> String:
	var key := Furigana.plain(text)
	if UI_EN.has(key):
		return UI_EN[key]
	var cut := key.find("（")
	if cut > 0 and UI_EN.has(key.substr(0, cut)):
		return UI_EN[key.substr(0, cut)]
	return ""


static func beginner() -> bool:
	# Looked up through the tree: UITheme is also compiled in contexts without autoload names.
	var tree := Engine.get_main_loop() as SceneTree
	var progress := tree.root.get_node_or_null("Progress") if tree else null
	return progress != null and progress.call("beginner")


## Add furigana markup to plain UI text using UI_RUBY. Text that already has markup is returned
## unchanged. Kanji not in the table stay bare (the test suite fails on those).
static func ruby(text: String) -> String:
	if text.contains("{"):
		return text
	var keys: Array = UI_RUBY.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var out := ""
	var i := 0
	while i < text.length():
		var matched := false
		for k: String in keys:
			if text.substr(i, k.length()) == k:
				out += "{%s|%s}" % [k, UI_RUBY[k]]
				i += k.length()
				matched = true
				break
		if not matched:
			out += text[i]
			i += 1
	return out


## A button whose label is drawn with furigana. Use set_button_text() to change it later.
static func button(text: String, primary: bool = true) -> Button:
	var b := Button.new()
	b.custom_minimum_size.y = BUTTON_HEIGHT
	b.focus_mode = Control.FOCUS_ALL
	if not primary:
		set_secondary(b)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lbl := FuriganaLabel.new()
	lbl.name = "Ruby"
	lbl.font_size = SIZE_LABEL
	lbl.weight = 500
	lbl.autowrap = false
	lbl.alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.color = ON_PRIMARY if primary else PRIMARY
	lbl.ruby_color = lbl.color
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	var sub := Label.new()
	sub.name = "En"
	sub.add_theme_font_override("font", font(400))
	sub.add_theme_font_size_override("font_size", SIZE_EN_SUB)
	sub.add_theme_color_override("font_color", lbl.color)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sub)
	set_button_text(b, text)
	b.draw.connect(func() -> void:
		var c := TEXT_DISABLED if b.disabled else (ON_PRIMARY if primary else PRIMARY)
		if lbl.color != c:
			lbl.color = c
			lbl.ruby_color = c
			sub.add_theme_color_override("font_color", c))
	return b


static func set_button_text(b: Button, text: String) -> void:
	var lbl := b.get_node_or_null("Box/Ruby") as FuriganaLabel
	if lbl == null:
		b.text = text
		return
	b.text = ""
	lbl.text = ruby(text)
	var sub := b.get_node("Box/En") as Label
	var english := en_for(text) if beginner() else ""
	sub.text = english
	sub.visible = english != ""
	# get_minimum_size() asks the label directly; the combined size is cached and is not
	# refreshed for nodes outside the tree.
	var min := lbl.get_minimum_size()
	var w := min.x
	var h := min.y
	if english != "":
		w = maxf(w, font(400).get_string_size(english, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE_EN_SUB).x)
		h += SIZE_EN_SUB + 4
	b.custom_minimum_size = Vector2(w + 48, maxf(BUTTON_HEIGHT, h + 6))


## A labelled on/off switch whose label carries furigana.
static func toggle(text: String, pressed: bool, on_toggled: Callable, tooltip: String = "") -> HBoxContainer:
	var row := hbox(12)
	var col := vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(ja(ruby(text), SIZE_LABEL))
	if tooltip != "" and beginner():
		col.add_child(en(tooltip, SIZE_LABEL))
	row.add_child(col)
	var cb := CheckButton.new()
	cb.button_pressed = pressed
	cb.tooltip_text = tooltip
	cb.focus_mode = Control.FOCUS_ALL
	cb.size_flags_horizontal = Control.SIZE_SHRINK_END
	cb.toggled.connect(on_toggled)
	row.add_child(cb)
	return row


## A row of tile buttons acting as a single choice (dropdowns cannot show furigana).
static func segmented(options: Array, selected: int, on_select: Callable) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for i in options.size():
		var b := TileButton.new(ruby(String(options[i])), SIZE_LABEL, en_for(String(options[i])) if beginner() else "")
		if i == selected:
			b.set_state(PRIMARY_TINT, PRIMARY)
		b.pressed.connect(on_select.bind(i))
		flow.add_child(b)
	return flow


static func set_secondary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _flat(SURFACE, RADIUS_BUTTON, PRIMARY, 2))
	b.add_theme_stylebox_override("hover", _flat(PRIMARY_TINT, RADIUS_BUTTON, PRIMARY, 2))
	b.add_theme_stylebox_override("pressed", _flat(PRIMARY_TINT, RADIUS_BUTTON, PRIMARY_HOVER, 2))
	for state in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(state, PRIMARY)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, PRIMARY_HOVER)


## Quiet look used for option tiles: surface fill, hairline border, dark text.
static func set_tile(b: Button, fill: Color = SURFACE, border: Color = BORDER) -> void:
	b.add_theme_stylebox_override("normal", _flat(fill, RADIUS_BUTTON, border, 2))
	b.add_theme_stylebox_override("hover", _flat(fill, RADIUS_BUTTON, PRIMARY, 2))
	b.add_theme_stylebox_override("pressed", _flat(PRIMARY_TINT, RADIUS_BUTTON, PRIMARY, 2))
	b.add_theme_stylebox_override("disabled", _flat(fill if fill != SURFACE else SURFACE_ALT, RADIUS_BUTTON, border, 2))
	b.add_theme_stylebox_override("focus", _outline(NEUTRAL, RADIUS_BUTTON, 2))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(state, TEXT_PRIMARY)


static func progress_bar(fill: Color, value: float) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 100
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, 14)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("fill", _flat(fill, 6))
	p.add_theme_stylebox_override("background", _flat(SURFACE_ALT, 6))
	return p


## A tinted icon from res://assets/icons (Tabler, MIT).
static func icon(name: String, color: Color = TEXT_SECONDARY, px: int = 24) -> TextureRect:
	var r := TextureRect.new()
	var path := "res://assets/icons/%s.svg" % name
	if ResourceLoader.exists(path):
		r.texture = load(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func spacer(height: int = GAP) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func hspacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Fade + 8 px rise, ANIM_IN seconds, no overshoot (ART_BIBLE: wrong answers never bounce).
static func animate_in(node: CanvasItem) -> void:
	if not node.is_inside_tree():
		await node.tree_entered
	node.modulate.a = 0.0
	var tw := node.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, ANIM_IN)
	if node is Control and not (node.get_parent() is Container):
		var c := node as Control
		var y := c.position.y
		c.position.y = y + 8
		tw.parallel().tween_property(c, "position:y", y, ANIM_IN)
