extends Control
## Root of the running game: applies the theme, shows the top navigation and swaps screens.
## Screens are plain scripts (no .tscn) that build their own widgets; see scripts/screens/.

const SCREENS := {
	&"dashboard": preload("res://scripts/screens/dashboard.gd"),
	&"kana": preload("res://scripts/screens/kana_trainer.gd"),
	&"dictionary": preload("res://scripts/screens/dictionary.gd"),
	&"review": preload("res://scripts/screens/review.gd"),
	&"sentences": preload("res://scripts/screens/sentence_builder.gd"),
	&"conversation": preload("res://scripts/screens/conversation.gd"),
	&"assessment": preload("res://scripts/screens/assessment.gd"),
}

## Navigation labels: Japanese-first with ruby (ART_BIBLE §2.8: an English gloss goes in a tooltip).
const NAV := [
	[&"dashboard", "ホーム", "Dashboard"],
	[&"kana", "かな", "Kana trainer"],
	[&"dictionary", "{辞書|じしょ}", "Dictionary"],
	[&"review", "{復習|ふくしゅう}", "Review"],
	[&"sentences", "{文|ぶん}を{作|つく}る", "Sentence builder"],
	[&"conversation", "{会話|かいわ}", "Conversation"],
	[&"assessment", "{試験|しけん}", "Assessment"],
]

var _content: Control
var _nav_buttons: Dictionary = {}
var _status: Label
var _current: StringName = &""


func _ready() -> void:
	theme = UITheme.build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_nav())
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_content)

	Progress.xp_changed.connect(func(_xp: int) -> void: _refresh_status())
	Progress.stage_changed.connect(func(_s: StringName) -> void: _refresh_status())
	_refresh_status()
	show_screen(&"dashboard")


func _build_nav() -> Control:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.SURFACE
	sb.border_color = UITheme.BORDER
	sb.set_border_width_all(0)
	sb.border_width_bottom = 1
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	bar.add_theme_stylebox_override("panel", sb)
	var row := UITheme.hbox(8)
	bar.add_child(row)
	for item in NAV:
		var b := TileButton.new(item[1], UITheme.SIZE_LABEL)
		b.tooltip_text = item[2]
		b.custom_minimum_size.y = UITheme.BUTTON_HEIGHT
		b.pressed.connect(show_screen.bind(item[0]))
		row.add_child(b)
		_nav_buttons[item[0]] = b
	row.add_child(UITheme.hspacer())
	_status = UITheme.label("", UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.size_flags_horizontal = Control.SIZE_SHRINK_END
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_status)
	return bar


func _refresh_status() -> void:
	_status.text = "%s  ·  Lv %d  ·  %d XP" % [String(Progress.stage), Progress.level(), Progress.xp]


func show_screen(name: StringName) -> void:
	if not SCREENS.has(name):
		push_error("main: unknown screen %s" % name)
		return
	ScreenBase.clear(_content)
	var screen: ScreenBase = SCREENS[name].new()
	screen.navigate.connect(show_screen)
	_content.add_child(screen)
	_current = name
	for key: StringName in _nav_buttons:
		var b: TileButton = _nav_buttons[key]
		if key == name:
			b.set_state(UITheme.PRIMARY_TINT, UITheme.PRIMARY)
		else:
			b.set_state(UITheme.SURFACE, UITheme.BORDER)
