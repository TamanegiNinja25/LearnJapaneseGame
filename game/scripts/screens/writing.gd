extends ScreenBase
## 書き: kanji writing practice on a WritingPad (GDD §10.3). なぞる traces over a faint model
## with the next stroke's start marked; 見ないで書く writes from the readings, the meaning and a
## word that uses the kanji. Every stroke is judged in order by StrokeMatch: a wrong stroke
## flashes red, and the second miss on the same stroke shows it as a hint. A finished kanji is
## recorded with Progress.record_writing (writing skill, plus a little kanji).
##
## args: {"kanji": "日"} to practise one kanji; otherwise the next stage kanji not yet written
## cleanly from memory.

const TRACE := 0
const MEMORY := 1

var _kanji: Dictionary = {}
var _model: Array[PackedVector2Array] = []
var _mode := TRACE
var _index := 0          # next stroke to write
var _miss_this := 0      # misses on the current stroke
var _mistakes := 0       # strokes that needed a retry or a hint
var _finished := false

var _pad: WritingPad
var _left: VBoxContainer
var _mode_box: VBoxContainer
var _info: VBoxContainer
var _feedback: Control
var _counter: Label
var _actions: HFlowContainer


func _ready() -> void:
	var row := UITheme.hbox(UITheme.GAP_SECTION)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side_name in ["left", "top", "right", "bottom"]:
		row.set("offset_" + side_name, 24.0 if side_name in ["left", "top"] else -24.0)
	add_child(row)
	scroll = ScreenBase.make_scroll(row)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left = UITheme.vbox(UITheme.GAP)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_left)
	column = _left
	_pad = WritingPad.new()
	_pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pad.stroke_drawn.connect(_on_stroke)
	row.add_child(_pad)
	resized.connect(_fit_pad)
	_fit_pad()

	# Top to bottom: mode, buttons, progress and feedback, then the prompt card. The buttons sit
	# above the card so they stay on screen on a phone.
	add_title("{書|か}き", "Writing")
	_mode_box = UITheme.vbox(0)
	_left.add_child(_mode_box)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 12)
	_actions.add_theme_constant_override("v_separation", 12)
	_left.add_child(_actions)
	_counter = UITheme.label("", UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY)
	_left.add_child(_counter)
	_feedback = Control.new()
	_left.add_child(_feedback)
	_info = UITheme.vbox(8)
	_left.add_child(_info)

	var ch := String(args.get("kanji", ""))
	_start(ch if ch != "" else _next_kanji(""), -1)


func _fit_pad() -> void:
	var avail := size if size.x > 0 else get_parent_area_size()
	var side := clampf(minf(avail.y - 48.0, avail.x * 0.52), 240.0, 640.0)
	_pad.custom_minimum_size = Vector2(side, side)


## The stage's kanji that have stroke data, in teaching order.
func _pool() -> Array:
	var out: Array = []
	for k in ContentDB.stage_items("kanji", Progress.stage):
		if not ContentDB.strokes(k["kanji"]).is_empty():
			out.append(k)
	return out


## The first kanji after [param after] (wrapping) not yet written cleanly from memory.
func _next_kanji(after: String) -> String:
	var pool := _pool()
	if pool.is_empty():
		return ""
	var start := 0
	for i in pool.size():
		if pool[i]["kanji"] == after:
			start = i + 1
	for n in pool.size():
		var k: Dictionary = pool[(start + n) % pool.size()]
		if Progress.writing_clean(k["kanji"]) == 0 and k["kanji"] != after:
			return k["kanji"]
	return pool[start % pool.size()]["kanji"]


## [param mode] -1 picks: trace a kanji the first time, then write it from memory.
func _start(ch: String, mode: int) -> void:
	_kanji = ContentDB.kanji_info(ch)
	_model = ContentDB.strokes(ch)
	if _kanji.is_empty() or _model.is_empty():
		ScreenBase.clear(_info)
		_info.add_child(UITheme.ja("{書|か}ける{漢字|かんじ}がありません。", UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
		_pad.enabled = false
		return
	var w: Dictionary = Progress.writing.get(ch, {})
	_mode = mode if mode >= 0 else (MEMORY if int(w.get("traced", 0)) + int(w.get("written", 0)) > 0 else TRACE)
	_index = 0
	_miss_this = 0
	_mistakes = 0
	_finished = false
	_pad.enabled = true
	_pad.set_model(_model, _mode == TRACE)
	_render_info()
	_render_actions()
	_say("", UITheme.TEXT_SECONDARY)
	_update_counter()


func _render_info() -> void:
	ScreenBase.clear(_info)
	ScreenBase.clear(_mode_box)
	_mode_box.add_child(UITheme.segmented(["なぞる", "見ないで書く"], _mode, func(i: int) -> void: _start(_kanji["kanji"], i)))
	var card := UITheme.card()
	_info.add_child(card)
	var v := UITheme.vbox(8)
	card.add_child(v)
	var word := _context_word()
	if _mode == TRACE or _finished:
		v.add_child(UITheme.label(_kanji["kanji"], 88, UITheme.SKILL_INK[&"writing"]))
	else:
		v.add_child(UITheme.ja("この{漢字|かんじ}を{書|か}きましょう", UITheme.SIZE_H2))
	v.add_child(UITheme.ja("{音読|おんよ}み：%s" % "、".join(_kanji["on"]), UITheme.SIZE_LABEL))
	v.add_child(UITheme.ja("{訓読|くんよ}み：%s" % "、".join(_kanji["kun"]), UITheme.SIZE_LABEL))
	if not word.is_empty():
		var shown := ExamBuilder.headword_markup(word) if _mode == TRACE or _finished else String(word["reading"])
		v.add_child(UITheme.ja("{言葉|ことば}：%s" % shown, UITheme.SIZE_BODY))
		if Progress.show_english():
			v.add_child(UITheme.en(ExamBuilder._short_gloss(word["english"]), UITheme.SIZE_LABEL))
	if Progress.show_explanations():
		v.add_child(UITheme.en("Meaning: " + ", ".join(_kanji["meanings"]), UITheme.SIZE_LABEL))


## A word that uses the kanji, preferring one the player already knows.
func _context_word() -> Dictionary:
	var best: Dictionary = {}
	for id: String in _kanji.get("words", []):
		var w := ContentDB.word(id)
		if w.is_empty():
			continue
		if best.is_empty() or Progress.rank_of(id) > Progress.rank_of(best["id"]):
			best = w
	return best


func _render_actions() -> void:
	ScreenBase.clear(_actions)
	if _finished:
		if _mode == TRACE:
			var again := UITheme.button("見ないでもう一度")
			again.pressed.connect(func() -> void: _start(_kanji["kanji"], MEMORY))
			_actions.add_child(again)
			set_primary(again)
		var next := UITheme.button("次へ", _mode != TRACE)
		next.pressed.connect(func() -> void: _start(_next_kanji(_kanji["kanji"]), -1))
		_actions.add_child(next)
		if _mode != TRACE:
			set_primary(next)
		return
	var demo := UITheme.button("書き順を見る", false)
	demo.pressed.connect(func() -> void: _pad.play_demo())
	_actions.add_child(demo)
	var hint := UITheme.button("ヒント", false)
	hint.pressed.connect(_show_hint)
	_actions.add_child(hint)
	var restart := UITheme.button("書き直す", false)
	restart.pressed.connect(func() -> void: _start(_kanji["kanji"], _mode))
	_actions.add_child(restart)
	var skip := UITheme.button("次へ", false)
	skip.pressed.connect(func() -> void: _start(_next_kanji(_kanji["kanji"]), -1))
	_actions.add_child(skip)


func _on_stroke(points: PackedVector2Array) -> void:
	if _finished or _index >= _model.size():
		return
	var result := StrokeMatch.judge(points, _model[_index])
	if result["ok"]:
		_pad.accept_stroke()
		_index += 1
		_miss_this = 0
		_update_counter()
		if _index >= _model.size():
			_finish()
		else:
			_say("○", UITheme.CORRECT)
		return
	if result["reason"] == "short":
		return  # a tap, not an attempt
	_pad.reject_stroke(points)
	_miss_this += 1
	if _miss_this == 1:
		_mistakes += 1
	if _miss_this >= 2:
		_pad.hint_stroke = _index
		_pad.queue_redraw()
	if result["reason"] == "direction":
		_say("{向|む}きが{逆|ぎゃく}です。", UITheme.INCORRECT, "Wrong direction: start from the dot.")
	else:
		_say("{書|か}き{順|じゅん}か{形|かたち}が{違|ちが}います。", UITheme.INCORRECT, "Wrong stroke or shape. The dot marks where the next stroke starts.")


func _show_hint() -> void:
	if _finished or _index >= _model.size():
		return
	if _miss_this == 0:
		_mistakes += 1
	_miss_this = maxi(_miss_this, 2)
	_pad.hint_stroke = _index
	_pad.queue_redraw()


func _finish() -> void:
	_finished = true
	var c := Progress.record_writing(_kanji["kanji"], _mode == MEMORY, _mistakes, _model.size())
	if c >= 1.0:
		_say("{上手|じょうず}！　ミスなし", UITheme.CORRECT, "Clean: no mistakes.")
	elif c > 0.0:
		_say("よくできました。ミス %d" % _mistakes, UITheme.WARNING, "Good. A few strokes needed another try.")
	else:
		_say("もう{一度|いちど}{練習|れんしゅう}しましょう。ミス %d" % _mistakes, UITheme.INCORRECT, "Practise this one again.")
	_render_info()
	_render_actions()


func _update_counter() -> void:
	_counter.text = "%d / %d" % [_index, _model.size()]


func _say(markup: String, color: Color, english: String = "") -> void:
	var fresh := UITheme.vbox(2)
	if markup != "":
		fresh.add_child(UITheme.ja(markup, UITheme.SIZE_BODY, color))
		if english != "" and Progress.show_explanations():
			fresh.add_child(UITheme.en(english, UITheme.SIZE_LABEL))
	_left.add_child(fresh)
	_left.move_child(fresh, _feedback.get_index())
	_feedback.queue_free()
	_feedback = fresh
