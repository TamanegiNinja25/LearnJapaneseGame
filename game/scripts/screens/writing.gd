extends ScreenBase
## 書き: writing practice on a WritingPad (GDD §10.3). Four sources: the stage's 漢字, ひらがな,
## カタカナ, and 言葉 (whole words, written character by character, for fluency). なぞる traces
## over a faint model with the next stroke's start marked; 見ないで書く writes from the readings,
## the meaning or the romaji. Every stroke is judged in order by StrokeMatch: a wrong stroke
## flashes red, and the second miss on the same stroke shows it as a hint. Each finished
## character is recorded with Progress.record_writing (writing skill, plus a little kanji).
##
## args: {"kanji": "日"} practises one kanji; {"source": "words"} opens a source. Otherwise the
## last source used (設定 key writing_source) and its next unwritten item.

const TRACE := 0
const MEMORY := 1
const SOURCES := ["kanji", "hiragana", "katakana", "words"]
const SOURCE_LABELS := ["漢字", "ひらがな", "カタカナ", "言葉"]

var _source := "kanji"
## The item being written: {"id", "chars": Array[String], "kanji"?: Dictionary, "word"?: Dictionary,
## "kana"?: Dictionary}
var _item: Dictionary = {}
var _char_i := 0         # character of the item being written
var _model: Array[PackedVector2Array] = []
var _mode := TRACE
var _index := 0          # next stroke to write
var _miss_this := 0      # misses on the current stroke
var _mistakes := 0       # strokes of this character that needed a retry or a hint
var _total_mistakes := 0 # across the item
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

	# Top to bottom: source and mode, buttons, progress and feedback, then the prompt card. The
	# buttons sit above the card so they stay on screen on a phone.
	add_title("{書|か}き", "Writing")
	_mode_box = UITheme.vbox(8)
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
	if ch != "":
		_source = "kanji"
		_begin(_kanji_item(ch), -1)
	else:
		var wanted := String(args.get("source", Progress.setting("writing_source")))
		_source = wanted if wanted in SOURCES else "kanji"
		_begin(_next_item(""), -1)


func _fit_pad() -> void:
	var avail := size if size.x > 0 else get_parent_area_size()
	var side := clampf(minf(avail.y - 48.0, avail.x * 0.52), 240.0, 640.0)
	_pad.custom_minimum_size = Vector2(side, side)


# ---------------------------------------------------------------- items

static func _has_strokes(text: String) -> bool:
	for ch in text:
		if ContentDB.strokes(ch).is_empty():
			return false
	return true


func _kanji_item(ch: String) -> Dictionary:
	var k := ContentDB.kanji_info(ch)
	if k.is_empty() or not _has_strokes(ch):
		return {}
	return {"id": ch, "chars": [ch], "kanji": k}


## Kana entries of one script (basic, dakuten, handakuten and yōon), in table order.
func _kana_pool(script: String) -> Array:
	var out: Array = []
	for e: Dictionary in ContentDB.kana.get(script, []):
		if _has_strokes(e["kana"]):
			out.append(e)
	return out


## Words worth writing: unlocked, containing a kanji, at most five characters, all writable.
## Words the player already knows come first.
func _word_pool() -> Array:
	var known: Array = []
	var rest: Array = []
	for e in ContentDB.unlocked_items("vocab", Progress.stage):
		var hw := String(e["headword"])
		if hw.length() > 5 or ExamBuilder._no_kanji(hw) or not _has_strokes(hw):
			continue
		(known if Progress.rank_of(e["id"]) >= Mastery.Rank.FAMILIAR else rest).append(e)
	return known if known.size() >= 10 else known + rest


## The next item of the current source after [param after] (an item id), preferring characters
## not yet written cleanly from memory. Words are picked at random.
func _next_item(after: String) -> Dictionary:
	match _source:
		"words":
			var pool := _word_pool()
			if pool.is_empty():
				return {}
			var w: Dictionary = pool[randi() % pool.size()]
			if w["id"] == after and pool.size() > 1:
				w = pool[(pool.find(w) + 1) % pool.size()]
			var chars: Array[String] = []
			for ch in String(w["headword"]):
				chars.append(ch)
			return {"id": w["id"], "chars": chars, "word": w}
		"hiragana", "katakana":
			var pool := _kana_pool(_source)
			var i := _next_index(pool.map(func(e: Dictionary) -> String: return e["kana"]), after)
			if i < 0:
				return {}
			var e: Dictionary = pool[i]
			var chars: Array[String] = []
			for ch in String(e["kana"]):
				chars.append(ch)
			return {"id": e["kana"], "chars": chars, "kana": e}
		_:
			var chars: Array = []
			for k in ContentDB.stage_items("kanji", Progress.stage):
				if _has_strokes(k["kanji"]):
					chars.append(k["kanji"])
			var i := _next_index(chars, after)
			return {} if i < 0 else _kanji_item(chars[i])


## Index of the first id after [param after] (wrapping) not yet written cleanly, or the next one.
func _next_index(ids: Array, after: String) -> int:
	if ids.is_empty():
		return -1
	var start := 0
	for i in ids.size():
		if ids[i] == after:
			start = i + 1
	for n in ids.size():
		var id: String = ids[(start + n) % ids.size()]
		if id != after and _clean(id) == 0:
			return (start + n) % ids.size()
	return start % ids.size()


## Times every character of [param text] was written cleanly from memory (the minimum).
func _clean(text: String) -> int:
	var low := 1 << 30
	for ch in text:
		low = mini(low, Progress.writing_clean(ch))
	return low


# ---------------------------------------------------------------- flow

## [param mode] -1 picks: trace something new the first time, then write it from memory. Words
## start from memory: they are for putting known characters together.
func _begin(item: Dictionary, mode: int) -> void:
	_item = item
	_render_mode_box()
	if item.is_empty():
		ScreenBase.clear(_info)
		ScreenBase.clear(_actions)
		_info.add_child(UITheme.ja("{書|か}けるものがありません。", UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
		_pad.enabled = false
		_pad.set_model([] as Array[PackedVector2Array], false)
		return
	if mode >= 0:
		_mode = mode
	elif _source == "words":
		_mode = MEMORY
	else:
		var w: Dictionary = Progress.writing.get(String(item["chars"][0]), {})
		_mode = MEMORY if int(w.get("traced", 0)) + int(w.get("written", 0)) > 0 else TRACE
	_total_mistakes = 0
	_finished = false
	_char_i = 0
	_render_mode_box()
	_start_char()


func _start_char() -> void:
	_model = ContentDB.strokes(_item["chars"][_char_i])
	_index = 0
	_miss_this = 0
	_mistakes = 0
	_pad.enabled = true
	_pad.set_model(_model, _mode == TRACE)
	_render_info()
	_render_actions()
	_say("", UITheme.TEXT_SECONDARY)
	_update_counter()


func _on_stroke(points: PackedVector2Array) -> void:
	if _finished or _index >= _model.size():
		return
	var result := StrokeMatch.judge(points, _model[_index])
	if result["ok"]:
		_pad.accept_stroke()
		Sfx.play("stroke")
		_index += 1
		_miss_this = 0
		_update_counter()
		if _index >= _model.size():
			_char_done()
		else:
			_say("○", UITheme.CORRECT)
		return
	if result["reason"] == "short":
		return  # a tap, not an attempt
	_pad.reject_stroke(points)
	Sfx.play("wrong")
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


## One character finished: record it, then move to the next character or finish the item.
func _char_done() -> void:
	var ch: String = _item["chars"][_char_i]
	Progress.record_writing(ch, _mode == MEMORY, _mistakes, _model.size())
	_total_mistakes += _mistakes
	if _char_i + 1 < (_item["chars"] as Array).size():
		_char_i += 1
		Sfx.play("correct")
		await get_tree().create_timer(0.35).timeout
		if is_inside_tree() and not _finished:
			_start_char()
		return
	_finish()


func _finish() -> void:
	_finished = true
	var strokes := 0
	for ch: String in _item["chars"]:
		strokes += ContentDB.strokes(ch).size()
	var c := Mastery.writing_correctness(_total_mistakes, strokes)
	Sfx.play("complete" if c > 0.0 else "wrong")
	if c >= 1.0:
		_say("{上手|じょうず}！　ミスなし", UITheme.CORRECT, "Clean: no mistakes.")
	elif c > 0.0:
		_say("よくできました。ミス %d" % _total_mistakes, UITheme.WARNING, "Good. A few strokes needed another try.")
	else:
		_say("もう{一度|いちど}{練習|れんしゅう}しましょう。ミス %d" % _total_mistakes, UITheme.INCORRECT, "Practise this one again.")
	_render_info()
	_render_actions()


# ---------------------------------------------------------------- UI

func _render_mode_box() -> void:
	ScreenBase.clear(_mode_box)
	_mode_box.add_child(UITheme.segmented(SOURCE_LABELS, SOURCES.find(_source), func(i: int) -> void:
		_source = SOURCES[i]
		Progress.set_setting("writing_source", _source)
		_begin(_next_item(""), -1)))
	if not _item.is_empty():
		_mode_box.add_child(UITheme.segmented(["なぞる", "見ないで書く"], _mode, func(i: int) -> void: _begin(_item, i)))


func _render_info() -> void:
	ScreenBase.clear(_info)
	var card := UITheme.card()
	_info.add_child(card)
	var v := UITheme.vbox(8)
	card.add_child(v)
	var reveal := _mode == TRACE or _finished
	if _item.has("word"):
		_word_info(v, reveal)
	elif _item.has("kana"):
		_kana_info(v, reveal)
	else:
		_kanji_info(v, reveal)


func _kanji_info(v: VBoxContainer, reveal: bool) -> void:
	var k: Dictionary = _item["kanji"]
	if reveal:
		v.add_child(UITheme.label(k["kanji"], 88, UITheme.SKILL_INK[&"writing"]))
	else:
		v.add_child(UITheme.ja("この{漢字|かんじ}を{書|か}きましょう", UITheme.SIZE_H2))
	v.add_child(UITheme.ja("{音読|おんよ}み：%s" % "、".join(k["on"]), UITheme.SIZE_LABEL))
	v.add_child(UITheme.ja("{訓読|くんよ}み：%s" % "、".join(k["kun"]), UITheme.SIZE_LABEL))
	var word := _context_word(k)
	if not word.is_empty():
		v.add_child(UITheme.ja("{言葉|ことば}：%s" % (ExamBuilder.headword_markup(word) if reveal else String(word["reading"])), UITheme.SIZE_BODY))
		if Progress.show_english():
			v.add_child(UITheme.en(ExamBuilder._short_gloss(word["english"]), UITheme.SIZE_LABEL))
	if Progress.show_explanations():
		v.add_child(UITheme.en("Meaning: " + ", ".join(k["meanings"]), UITheme.SIZE_LABEL))


func _kana_info(v: VBoxContainer, reveal: bool) -> void:
	var e: Dictionary = _item["kana"]
	if reveal:
		v.add_child(UITheme.label(e["kana"], 88, UITheme.SKILL_INK[&"writing"]))
	else:
		v.add_child(UITheme.ja("「%s」を{書|か}きましょう" % e["romaji"], UITheme.SIZE_H2))
		if _source == "katakana":
			v.add_child(UITheme.ja("ひらがな：%s" % _hiragana_for(e), UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
	v.add_child(UITheme.label("romaji: %s" % e["romaji"], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	if _item["chars"].size() > 1:
		v.add_child(_slots())


func _word_info(v: VBoxContainer, reveal: bool) -> void:
	var w: Dictionary = _item["word"]
	v.add_child(UITheme.ja("この{言葉|ことば}を{書|か}きましょう" if not _finished else ExamBuilder.headword_markup(w), UITheme.SIZE_H2))
	v.add_child(_slots())
	v.add_child(UITheme.ja("{読|よ}み：%s" % w["reading"], UITheme.SIZE_BODY))
	if reveal and not _finished:
		v.add_child(UITheme.ja(ExamBuilder.headword_markup(w), UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
	if Progress.show_english():
		v.add_child(UITheme.en(ExamBuilder._short_gloss(w["english"]), UITheme.SIZE_LABEL))


## One box per character: written ones in ink, the current one highlighted, the rest hidden
## (from memory) or faint (tracing).
func _slots() -> HBoxContainer:
	var row := UITheme.hbox(6)
	var chars: Array = _item["chars"]
	for i in chars.size():
		var done := i < _char_i or _finished
		var shown: String = chars[i] if done or _mode == TRACE else "□"
		var color := UITheme.TEXT_PRIMARY if done else (UITheme.PRIMARY if i == _char_i else UITheme.TEXT_DISABLED)
		var l := UITheme.label(shown, 44, color)
		l.custom_minimum_size = Vector2(52, 0)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(l)
	return row


func _hiragana_for(katakana_entry: Dictionary) -> String:
	var kata: Array = ContentDB.kana.get("katakana", [])
	var hira: Array = ContentDB.kana.get("hiragana", [])
	var i := kata.find(katakana_entry)
	return String(hira[i]["kana"]) if i >= 0 and i < hira.size() else ""


## A word that uses the kanji, preferring one the player already knows.
func _context_word(k: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for id: String in k.get("words", []):
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
			again.pressed.connect(func() -> void: _begin(_item, MEMORY))
			_actions.add_child(again)
			set_primary(again)
		var next := UITheme.button("次へ", _mode != TRACE)
		next.pressed.connect(func() -> void: _begin(_next_item(_item["id"]), -1))
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
	restart.pressed.connect(func() -> void: _begin(_item, _mode))
	_actions.add_child(restart)
	var skip := UITheme.button("次へ", false)
	skip.pressed.connect(func() -> void: _begin(_next_item(_item["id"]), -1))
	_actions.add_child(skip)


func _update_counter() -> void:
	var chars: Array = _item.get("chars", [])
	var where := "%d / %d　" % [_char_i + 1, chars.size()] if chars.size() > 1 else ""
	_counter.text = "%s%d / %d" % [where, _index, _model.size()]


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
