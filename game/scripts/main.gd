extends Control
## Root of the running game: applies theme settings, shows the sidebar navigation, swaps screens,
## and shows toasts for rank-ups, quests and stage clears. Screens are plain scripts (no .tscn)
## that build their own widgets; see scripts/screens/.

const SCREENS := {
	&"dashboard": "res://scripts/screens/dashboard.gd",
	&"onboarding": "res://scripts/screens/onboarding.gd",
	&"town": "res://scripts/screens/town_screen.gd",
	&"kana": "res://scripts/screens/kana_trainer.gd",
	&"dictionary": "res://scripts/screens/dictionary.gd",
	&"review": "res://scripts/screens/review.gd",
	&"kanji": "res://scripts/screens/kanji.gd",
	&"grammar": "res://scripts/screens/grammar_lesson.gd",
	&"sentences": "res://scripts/screens/sentence_builder.gd",
	&"conversation": "res://scripts/screens/conversation.gd",
	&"listening": "res://scripts/screens/listening.gd",
	&"assessment": "res://scripts/screens/assessment.gd",
	&"settings": "res://scripts/screens/settings.gd",
}

## Sidebar: [screen, icon, Japanese label (markup), English tooltip]
const NAV := [
	[&"dashboard", "home", "ホーム", "Dashboard"],
	[&"town", "map-2", "{町|まち}", "Town (3D)"],
	[&"kana", "language-hiragana", "かな", "Kana trainer"],
	[&"dictionary", "book", "{辞書|じしょ}", "Dictionary"],
	[&"review", "repeat", "{復習|ふくしゅう}", "Review"],
	[&"kanji", "brush", "{漢字|かんじ}", "Kanji"],
	[&"grammar", "notebook", "{文法|ぶんぽう}", "Grammar lessons"],
	[&"sentences", "puzzle", "{文|ぶん}を{作|つく}る", "Sentence builder"],
	[&"conversation", "messages", "{会話|かいわ}", "Conversation"],
	[&"listening", "headphones", "{聴解|ちょうかい}", "Listening"],
	[&"assessment", "certificate", "{試験|しけん}", "Assessment"],
	[&"settings", "settings", "{設定|せってい}", "Settings"],
]

var _content: Control
var _nav_buttons: Dictionary = {}
var _status: Label
var _current: StringName = &""
var _current_args: Dictionary = {}
var _overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_settings()
	_build()
	Progress.xp_changed.connect(func(_xp: int) -> void: _refresh_status())
	Progress.stage_changed.connect(_on_stage_changed)
	Progress.settings_changed.connect(_on_settings_changed)
	Progress.rank_up.connect(_on_rank_up)
	Progress.quest_completed.connect(_on_quest)
	show_screen(&"dashboard" if Progress.setting("onboarded") else &"onboarding")


func _apply_settings() -> void:
	UITheme.apply(Progress.setting("theme") == "dark", Progress.setting("font") == "bizud")
	theme = UITheme.build_theme()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_sidebar())
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	root.add_child(_content)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_refresh_status()


func _build_sidebar() -> Control:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.SURFACE
	sb.border_color = UITheme.BORDER
	sb.border_width_right = 1
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	bar.add_theme_stylebox_override("panel", sb)
	bar.custom_minimum_size.x = 196
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bar.add_child(scroll)
	var col := UITheme.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var title := UITheme.ja("{日本語|にほんご}の{世界|せかい}", UITheme.SIZE_LABEL, UITheme.PRIMARY)
	col.add_child(title)
	_status = UITheme.label("", UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(_status)
	col.add_child(UITheme.spacer(8))
	for item in NAV:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = item[3]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		UITheme.set_tile(b, UITheme.SURFACE, UITheme.SURFACE)
		var row := UITheme.hbox(10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 12
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		b.add_child(row)
		var ic := UITheme.icon(item[1], UITheme.TEXT_SECONDARY, 22)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var lbl := UITheme.ja(item[2], UITheme.SIZE_LABEL)
		lbl.autowrap = false
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lbl)
		b.pressed.connect(show_screen.bind(item[0], {}))
		col.add_child(b)
		_nav_buttons[item[0]] = {"button": b, "icon": ic}
	return bar


func _refresh_status() -> void:
	if _status:
		_status.text = "%s · Lv %d · %d XP" % [String(Progress.stage), Progress.level(), Progress.xp]


func show_screen(name: StringName, args: Dictionary = {}) -> void:
	if not SCREENS.has(name) or not ResourceLoader.exists(SCREENS[name]):
		push_error("main: unknown screen %s" % name)
		name = &"dashboard"
	Speech.stop()
	ScreenBase.clear(_content)
	var screen: ScreenBase = (load(SCREENS[name]) as GDScript).new()
	screen.args = args
	screen.navigate.connect(show_screen)
	_content.add_child(screen)
	_current = name
	_current_args = args
	for key: StringName in _nav_buttons:
		var b: Button = _nav_buttons[key]["button"]
		var ic: TextureRect = _nav_buttons[key]["icon"]
		if key == name:
			UITheme.set_tile(b, UITheme.PRIMARY_TINT, UITheme.PRIMARY)
			ic.modulate = UITheme.PRIMARY
		else:
			UITheme.set_tile(b, UITheme.SURFACE, UITheme.SURFACE)
			ic.modulate = UITheme.TEXT_SECONDARY


func _on_settings_changed() -> void:
	var dark_now: bool = Progress.setting("theme") == "dark"
	var biz_now: bool = Progress.setting("font") == "bizud"
	if dark_now != UITheme.dark or biz_now != UITheme.accessible_font:
		_apply_settings()
		_build()
		show_screen(_current, _current_args)


func _on_stage_changed(stage: StringName) -> void:
	_refresh_status()
	Toast.show_on(_overlay, "%s　{解放|かいほう}！" % Mastery.STAGE_LABEL_JA.get(stage, String(stage)), "New stage unlocked", UITheme.CORRECT)


func _on_rank_up(word_id: String, rank: int) -> void:
	var w := ContentDB.word(word_id)
	if w.is_empty():
		return
	Toast.show_on(_overlay, "%s → %s" % [ExamBuilder.headword_markup(w), Mastery.RANK_LABEL_JA[rank]], Mastery.RANK_LABEL_EN[rank])


func _on_quest(q: Dictionary) -> void:
	Toast.show_on(_overlay, "%s　+%d XP" % [q["ja"], int(q["xp"])], q["en"], UITheme.SKILL_INK[&"vocab"])
