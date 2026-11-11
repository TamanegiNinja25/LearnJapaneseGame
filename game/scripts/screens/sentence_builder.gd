extends ScreenBase
## 文を作る: assemble a sentence from word tiles (GDD §7). Up to three attempts and two hints;
## first-try unhinted answers earn full credit and usage credit for the words used.

const MAX_ATTEMPTS := 3

var _prompt: Dictionary = {}
var _answer: Array = []          # tile markup strings in placed order
var _tray: Array = []            # remaining tile markup strings
var _attempts := 0
var _hints := 0
var _done := false

var _box: VBoxContainer
var _answer_flow: HFlowContainer
var _tray_flow: HFlowContainer
var _feedback: VBoxContainer
var _check: Button
var _hint: Button


func _ready() -> void:
	make_column(UITheme.COLUMN_WIDTH)
	add_title("{文|ぶん}を{作|つく}りましょう！", "Build the sentence")
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	_load_prompt()


## Prefer prompts never answered perfectly; otherwise any.
func _pick_prompt() -> Dictionary:
	var pool := ContentDB.sentences.duplicate()
	pool.shuffle()
	var fresh := pool.filter(func(p: Dictionary) -> bool:
		return float(Progress.prompts.get(p["id"], {}).get("best_c", 0.0)) < 1.0)
	return fresh[0] if not fresh.is_empty() else pool[0]


func _load_prompt() -> void:
	_prompt = _pick_prompt()
	_answer = []
	_tray = (_prompt["tiles"] as Array).duplicate()
	_tray.append_array(_prompt["distractors"])
	_tray.shuffle()
	_attempts = 0
	_hints = 0
	_done = false
	ScreenBase.clear(_box)

	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja("「%s」" % _prompt["prompt_en"], UITheme.SIZE_H2))
	if Progress.show_explanations():
		v.add_child(UITheme.en("Tap the tiles in order. Some tiles do not belong."))

	v.add_child(UITheme.ja("{答|こた}え", UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	var answer_panel := UITheme.card(UITheme.SURFACE_ALT, UITheme.BORDER)
	answer_panel.custom_minimum_size.y = 96
	v.add_child(answer_panel)
	_answer_flow = _flow()
	answer_panel.add_child(_answer_flow)

	v.add_child(UITheme.ja("{言葉|ことば}", UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	_tray_flow = _flow()
	v.add_child(_tray_flow)

	var row := UITheme.hbox(12)
	v.add_child(row)
	_check = UITheme.button("確認する")
	_check.pressed.connect(_on_check)
	row.add_child(_check)
	_hint = UITheme.button("ヒント", false)
	_hint.pressed.connect(_on_hint)
	row.add_child(_hint)
	var clear := UITheme.button("やり直す", false)
	clear.pressed.connect(func() -> void:
		if _done:
			return
		_tray.append_array(_answer)
		_answer = []
		_render_tiles())
	row.add_child(clear)

	_feedback = UITheme.vbox(12)
	_box.add_child(_feedback)
	_render_tiles()


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


func _render_tiles() -> void:
	ScreenBase.clear(_answer_flow)
	ScreenBase.clear(_tray_flow)
	for i in _answer.size():
		var b := TileButton.new(_answer[i], UITheme.SIZE_BODY_L)
		b.set_state(UITheme.PRIMARY_TINT, UITheme.PRIMARY)
		b.disabled = _done
		b.pressed.connect(func() -> void:
			var tile: String = _answer[i]
			_answer.remove_at(i)
			_tray.append(tile)
			_render_tiles())
		_answer_flow.add_child(b)
	for i in _tray.size():
		var b := TileButton.new(_tray[i], UITheme.SIZE_BODY_L)
		b.disabled = _done or (_hints >= 1 and _tray[i] in _prompt["distractors"])
		b.pressed.connect(func() -> void:
			var tile: String = _tray[i]
			_tray.remove_at(i)
			_answer.append(tile)
			_render_tiles())
		_tray_flow.add_child(b)


func _on_hint() -> void:
	if _done or _hints >= 2:
		return
	_hints += 1
	if _hints == 2:
		# Lock the next correct tile in place (GDD §7.3 hint 2).
		var target: Array = _prompt["accepted"][0]
		var next_index := 0
		while next_index < _answer.size() and next_index < target.size() and _answer[next_index] == target[next_index]:
			next_index += 1
		# Return any wrong tiles after the matching prefix to the tray.
		while _answer.size() > next_index:
			_tray.append(_answer.pop_back())
		if next_index < target.size():
			var tile: String = target[next_index]
			var at := _tray.find(tile)
			if at >= 0:
				_tray.remove_at(at)
				_answer.append(tile)
		_hint.disabled = true
	_render_tiles()


func _on_check() -> void:
	if _done or _answer.is_empty():
		return
	_attempts += 1
	var r := SentenceCheck.evaluate(_answer, _prompt["accepted"])
	ScreenBase.clear(_feedback)
	if r["result"] == SentenceCheck.Result.CORRECT:
		var c := Srs.C_CORRECT if (_attempts == 1 and _hints == 0) else Srs.C_PARTIAL
		_finish(c, "○ {正解|せいかい}", "".join(_prompt["accepted"][0]), UITheme.CORRECT_TINT, UITheme.CORRECT)
		return
	if _attempts >= MAX_ATTEMPTS:
		_finish(Srs.C_WRONG, "✕ {答|こた}え", "".join(_prompt["accepted"][0]), UITheme.INCORRECT_TINT, UITheme.INCORRECT)
		return
	var hint_ja: String = r["hint"]
	var grammar_line := _grammar_hint()
	if grammar_line != "":
		hint_ja += "\n" + grammar_line
	_feedback.add_child(ScreenBase.feedback_card("△ もう{一度|いちど}（%d / %d）" % [_attempts, MAX_ATTEMPTS], hint_ja,
		"Not yet. Check the hint and try again.", UITheme.NEUTRAL_TINT, UITheme.NEUTRAL))
	# Highlight the first bad tile.
	var bad := int(r["first_bad_index"])
	if bad >= 0 and bad < _answer_flow.get_child_count():
		(_answer_flow.get_child(bad) as TileButton).set_state(UITheme.INCORRECT_TINT, UITheme.INCORRECT)


## One-line rule of the prompt's first grammar point, Japanese-first.
func _grammar_hint() -> String:
	var ids: Array = _prompt["grammar"]
	if ids.is_empty():
		return ""
	var g := ContentDB.grammar_point(ids[0])
	return g.get("explanation_ja", "")


func _finish(c: float, verdict: String, answer_markup: String, tint: Color, ink: Color) -> void:
	_done = true
	_check.disabled = true
	_hint.disabled = true
	_render_tiles()
	Progress.record_sample(&"sentence_builder", c)
	Progress.record_prompt(_prompt["id"], c)
	for gid in _prompt["grammar"]:
		Progress.record_grammar(gid, c >= Srs.C_CORRECT)
	if c >= Srs.C_CORRECT:
		Progress.add_xp(Mastery.XP[&"sentence"])
		for tile in _prompt["tiles"]:
			var entry := ContentDB.word_by_headword(Furigana.plain(tile))
			if not entry.is_empty():
				Progress.record_word_answer(entry["id"], "use", Srs.C_CORRECT, false)
	elif c > Srs.C_WRONG:
		Progress.add_xp(Mastery.XP[&"sentence_hinted"])
	Progress.bump_stat("sentences_built")
	Progress.save_game()
	var en: String = "" if not Progress.show_english() else _prompt["prompt_en"]
	_feedback.add_child(ScreenBase.feedback_card(verdict, answer_markup, en, tint, ink))
	var explanation := _grammar_hint()
	if explanation != "":
		var g := ContentDB.grammar_point(_prompt["grammar"][0])
		_feedback.add_child(ScreenBase.feedback_card(g["pattern"], explanation, g.get("explanation_en", ""), UITheme.NEUTRAL_TINT, UITheme.NEUTRAL))
	var row := UITheme.hbox(12)
	_feedback.add_child(row)
	var next := UITheme.button("次の文へ")
	next.pressed.connect(_load_prompt)
	row.add_child(next)
	var home := UITheme.button("ホームへ", false)
	home.pressed.connect(func() -> void: navigate.emit(&"dashboard"))
	row.add_child(home)
	next.grab_focus()
