extends Control
## Root of the running game: applies theme settings, shows the sidebar navigation, swaps screens,
## and shows toasts for rank-ups, quests and stage clears. Screens are plain scripts (no .tscn)
## that build their own widgets; see scripts/screens/. At start it asks GitHub once whether a
## newer release exists and offers it in a popup (設定 › 更新を確認する turns this off).

const SCREENS := {
	&"dashboard": "res://scripts/screens/dashboard.gd",
	&"onboarding": "res://scripts/screens/onboarding.gd",
	&"town": "res://scripts/screens/town_screen.gd",
	&"kana": "res://scripts/screens/kana_trainer.gd",
	&"dictionary": "res://scripts/screens/dictionary.gd",
	&"review": "res://scripts/screens/review.gd",
	&"kanji": "res://scripts/screens/kanji.gd",
	&"writing": "res://scripts/screens/writing.gd",
	&"style": "res://scripts/screens/style.gd",
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
	[&"writing", "pencil-kanji", "{書|か}き", "Writing"],
	[&"grammar", "notebook", "{文法|ぶんぽう}", "Grammar lessons"],
	[&"sentences", "puzzle", "{文|ぶん}を{作|つく}る", "Sentence builder"],
	[&"style", "swap-style", "{表現|ひょうげん}", "Natural Japanese"],
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
var _built_beginner := false
var _update_request: HTTPRequest
var _sfx: Sfx


func _ready() -> void:
	# Android back gesture: go back to ホーム, and only leave the app from ホーム.
	get_tree().quit_on_go_back = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_settings()
	_sfx = Sfx.new()
	add_child(_sfx)
	_build()
	Progress.xp_changed.connect(func(_xp: int) -> void: _refresh_status())
	Progress.stage_changed.connect(_on_stage_changed)
	Progress.settings_changed.connect(_on_settings_changed)
	Progress.rank_up.connect(_on_rank_up)
	Progress.quest_completed.connect(_on_quest)
	show_screen(&"dashboard" if Progress.setting("onboarded") else &"onboarding")
	_check_for_update()


func _apply_settings() -> void:
	UITheme.apply(Progress.setting("theme") == "dark", Progress.setting("font") == "bizud")
	theme = UITheme.build_theme()
	# Text size (設定 › 文字の大きさ). Automatic = larger on touch screens.
	get_window().content_scale_factor = Progress.ui_scale()


func _build() -> void:
	for c in get_children():
		if c == _update_request or c == _sfx:
			continue  # a rebuild (theme change) must not cancel the update check or the music
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
	_built_beginner = Progress.beginner()
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
	var beginner := Progress.beginner()
	bar.custom_minimum_size.x = 220 if beginner else 196
	var scroll := ScreenBase.make_scroll(bar)
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
		b.custom_minimum_size = Vector2(0, 76 if beginner else 46)
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
		if beginner:
			var stack := UITheme.vbox(0)
			stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			stack.add_child(lbl)
			var en := UITheme.label(item[3], UITheme.SIZE_EN_SUB, UITheme.TEXT_SECONDARY)
			en.autowrap_mode = TextServer.AUTOWRAP_OFF
			en.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_child(en)
			row.add_child(stack)
		else:
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _current == &"dashboard":
			get_tree().quit()
		else:
			show_screen(&"dashboard")


func _on_settings_changed() -> void:
	Sfx.refresh()
	var dark_now: bool = Progress.setting("theme") == "dark"
	var biz_now: bool = Progress.setting("font") == "bizud"
	var scale_now := Progress.ui_scale()
	var beginner_now := Progress.beginner()
	if dark_now != UITheme.dark or biz_now != UITheme.accessible_font or not is_equal_approx(scale_now, get_window().content_scale_factor) or beginner_now != _built_beginner:
		_apply_settings()
		_build()
		show_screen(_current, _current_args)


func _on_stage_changed(stage: StringName) -> void:
	_refresh_status()
	if Progress.beginner() != _built_beginner:
		_build()
		show_screen(_current, _current_args)
	Toast.show_on(_overlay, "%s　{解放|かいほう}！" % Mastery.STAGE_LABEL_JA.get(stage, String(stage)), "New stage unlocked", UITheme.CORRECT)


func _on_rank_up(word_id: String, rank: int) -> void:
	var w := ContentDB.word(word_id)
	if w.is_empty():
		return
	Toast.show_on(_overlay, "%s → %s" % [ExamBuilder.headword_markup(w), Mastery.RANK_LABEL_JA[rank]], Mastery.RANK_LABEL_EN[rank])


func _on_quest(q: Dictionary) -> void:
	Toast.show_on(_overlay, "%s　+%d XP" % [q["ja"], int(q["xp"])], q["en"], UITheme.SKILL_INK[&"vocab"])


# ---------------------------------------------------------------- update check

func _check_for_update() -> void:
	if not bool(Progress.setting("check_updates")) or DisplayServer.get_name() == "headless":
		return
	_update_request = HTTPRequest.new()
	_update_request.timeout = 10.0
	add_child(_update_request)
	_update_request.request_completed.connect(_on_update_response)
	var headers := ["User-Agent: NihongoNoSekai/%s" % _version(), "Accept: application/vnd.github+json"]
	if _update_request.request(UpdateCheck.RELEASES_API, headers) != OK:
		_update_request.queue_free()


func _on_update_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_update_request.queue_free()
	_update_request = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return  # offline or rate-limited: try again next launch, silently
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	var info := UpdateCheck.from_release(data)
	if info.is_empty() or not UpdateCheck.is_newer(info["version"], _version()):
		return
	if String(Progress.setting("skipped_update")) == info["version"]:
		return
	show_update_popup(info)


static func _version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## Modal card: the new version, a download button (this platform's build, or the release page
## on the web), "later" and "skip this version".
func show_update_popup(info: Dictionary) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card := UITheme.card(UITheme.SURFACE, UITheme.PRIMARY)
	card.custom_minimum_size.x = minf(560.0, get_viewport_rect().size.x - 48.0)
	center.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(ScreenBase.ja_en("{新|あたら}しいバージョンがあります", "A new version is available", UITheme.SIZE_H2, UITheme.PRIMARY))
	v.add_child(UITheme.ja("v%s　（{今|いま}は v%s）" % [info["version"], _version()], UITheme.SIZE_BODY))
	if Progress.show_explanations():
		v.add_child(UITheme.en("Your progress is kept when you install the update.", UITheme.SIZE_LABEL))
	var close := func() -> void: shade.queue_free()
	var download := UITheme.button("ダウンロード")
	download.pressed.connect(func() -> void:
		OS.shell_open(UpdateCheck.download_url(info, OS.get_name()))
		close.call())
	v.add_child(download)
	var row := UITheme.hbox(12)
	v.add_child(row)
	var later := UITheme.button("あとで", false)
	later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	later.pressed.connect(close)
	row.add_child(later)
	var skip := UITheme.button("このバージョンをスキップ", false)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(func() -> void:
		Progress.set_setting("skipped_update", info["version"])
		close.call())
	row.add_child(skip)
	UITheme.animate_in(card)
