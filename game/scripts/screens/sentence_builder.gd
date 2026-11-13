extends ScreenBase
## 文を作る: assemble a sentence from word tiles (GDD §7). Tier from the 文法 score, adjusted in the
## session (3 first-try wins → +1, 2 failures → −1). Three attempts, two hints. A single wrong
## particle is named with the grammar point's one-line rule. A rejected answer can be reported as
## natural (GDD §13 question 4) for curation.

const MAX_ATTEMPTS := 3

var _prompt: Dictionary = {}
var _answer: Array = []
var _tray: Array = []
var _attempts := 0
var _hints := 0
var _done := false
var _tier := 1
var _streak_ok := 0
var _streak_fail := 0
var _last_id := ""

var _box: VBoxContainer
var _answer_flow: HFlowContainer
var _tray_flow: HFlowContainer
var _feedback: VBoxContainer
var _check: Button
var _hint: Button


func _ready() -> void:
	make_column(UITheme.COLUMN_WIDTH)
	add_title("{文|ぶん}を{作|つく}りましょう！", "Build the sentence")
	_tier = SentenceCheck.tier_for_score(int(Progress.scores()[&"grammar"]))
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	_load_prompt()


func _pool() -> Array:
	var current := ContentDB.stage_items("sentences", Progress.stage)
	var pool: Array = current if not current.is_empty() else ContentDB.unlocked_items("sentences", Progress.stage)
	if args.has("grammar_id"):
		var gid: String = args["grammar_id"]
		var focused := ContentDB.unlocked_items("sentences", Progress.stage).filter(func(p: Dictionary) -> bool: return gid in p["grammar"])
		if not focused.is_empty():
			return focused
	return pool


## Prefer prompts at the current tier not yet answered perfectly; fall back to the nearest tier.
func _pick_prompt() -> Dictionary:
	var pool := _pool().filter(func(p: Dictionary) -> bool: return p["id"] != _last_id)
	if pool.is_empty():
		pool = _pool()
	pool.shuffle()
	for distance in [0, 1, 2]:
		var at_tier := pool.filter(func(p: Dictionary) -> bool: return absi(int(p.get("tier", 1)) - _tier) == distance)
		var fresh := at_tier.filter(func(p: Dictionary) -> bool:
			return float(Progress.prompts.get(p["id"], {}).get("best_c", 0.0)) < 1.0)
		if not fresh.is_empty():
			return fresh[0]
		if not at_tier.is_empty() and distance == 2:
			return at_tier[0]
	return pool[0] if not pool.is_empty() else {}


func _load_prompt() -> void:
	_prompt = _pick_prompt()
	ScreenBase.clear(_box)
	if _prompt.is_empty():
		_box.add_child(UITheme.ja("まだ{問題|もんだい}がありません。", UITheme.SIZE_BODY))
		return
	_last_id = _prompt["id"]
	_answer = []
	_tray = (_prompt["tiles"] as Array).duplicate()
	_tray.append_array(_prompt["distractors"])
	_tray.shuffle()
	_attempts = 0
	_hints = 0
	_done = false

	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var head := UITheme.hbox(12)
	v.add_child(head)
	var tier_lbl := UITheme.label("Tier %d" % int(_prompt.get("tier", 1)), UITheme.SIZE_CAPTION, UITheme.SKILL_INK[&"grammar"])
	tier_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tier_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(tier_lbl)
	if Progress.english_mode == Progress.EnglishMode.JAPANESE_ONLY and _prompt.has("ja_hint"):
		v.add_child(UITheme.ja(_prompt["ja_hint"], UITheme.SIZE_H2))
	else:
		v.add_child(UITheme.ja("「%s」" % _prompt["prompt_en"], UITheme.SIZE_H2))
		if _prompt.has("ja_hint"):
			v.add_child(UITheme.ja(_prompt["ja_hint"], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	if Progress.show_explanations() and not compact():
		v.add_child(UITheme.en("Tap the tiles in order. Some tiles do not belong."))

	v.add_child(UITheme.ja("{答|こた}え", UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	var answer_panel := UITheme.card(UITheme.SURFACE_ALT, UITheme.BORDER)
	answer_panel.custom_minimum_size.y = 72 if compact() else 96
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
	set_primary(_check)

	_feedback = UITheme.vbox(12)
	_box.add_child(_feedback)
	_render_tiles()
	UITheme.animate_in(card)


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
		var b := TileButton.new(_answer[i], UITheme.SIZE_BODY_L, _gloss(_answer[i]))
		b.set_state(UITheme.PRIMARY_TINT, UITheme.PRIMARY)
		b.disabled = _done
		b.pressed.connect(func() -> void:
			_tray.append(_answer[i])
			_answer.remove_at(i)
			_render_tiles())
		_answer_flow.add_child(b)
	var tray_buttons: Array = []
	for i in _tray.size():
		var b := TileButton.new(_tray[i], UITheme.SIZE_BODY_L, _gloss(_tray[i]))
		b.disabled = _done or (_hints >= 1 and _tray[i] in _prompt["distractors"])
		b.pressed.connect(func() -> void:
			_answer.append(_tray[i])
			_tray.remove_at(i)
			_render_tiles())
		_tray_flow.add_child(b)
		tray_buttons.append(b)
	# Keys 1–9 pick tray tiles in order.
	_options.clear()
	for b in tray_buttons:
		_options.append(b)


## Beginner help: a short English gloss under each tile (particles get their role).
const PARTICLE_EN := {"は": "topic", "が": "subject", "を": "object", "に": "to / at (time)", "で": "at / by means of",
	"へ": "toward", "と": "with / and", "も": "also", "の": "'s / of", "や": "and (etc.)", "から": "from / because",
	"まで": "until / to", "か": "question", "ね": "right?", "よ": "you know", "より": "than"}


func _gloss(tile: String) -> String:
	if not Progress.beginner():
		return ""
	var plain := Furigana.plain(tile)
	if PARTICLE_EN.has(plain):
		return PARTICLE_EN[plain]
	var entry := ContentDB.word_by_headword(plain)
	if entry.is_empty():
		entry = _verb_for(plain)
	if entry.is_empty():
		return ""
	var g := ExamBuilder._short_gloss(entry["english"])
	return g.split(";")[0]


static var _verb_stems: Dictionary = {}


## Conjugated verbs/adjectives (食べていません, 寒かった) map back to their dictionary form by the
## longest matching stem (headword minus its final kana).
func _verb_for(plain: String) -> Dictionary:
	if _verb_stems.is_empty():
		for e in ContentDB.unlocked_items("vocab", &"N4"):
			var cat: String = e["category"]
			if cat.begins_with("verb") or cat == "adj-i":
				var hw: String = e["headword"]
				var stem := hw.substr(0, hw.length() - 1) if hw.length() > 1 else hw
				if stem.length() >= 1 and not _verb_stems.has(stem):
					_verb_stems[stem] = e
	for n in range(plain.length() - 1, 0, -1):
		var stem := plain.substr(0, n)
		if _verb_stems.has(stem):
			return _verb_stems[stem]
	return {}


func _on_hint() -> void:
	if _done or _hints >= 2:
		return
	_hints += 1
	if _hints == 2:
		var target: Array = _prompt["accepted"][0]
		var n := 0
		while n < _answer.size() and n < target.size() and _answer[n] == target[n]:
			n += 1
		while _answer.size() > n:
			_tray.append(_answer.pop_back())
		if n < target.size():
			var at := _tray.find(target[n])
			if at >= 0:
				_answer.append(_tray[at])
				_tray.remove_at(at)
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
		_finish(c, "○ {正解|せいかい}", "".join(_answer), UITheme.CORRECT_TINT, UITheme.CORRECT)
		return
	if _attempts >= MAX_ATTEMPTS:
		_finish(Srs.C_WRONG, "✕ {答|こた}え", "".join(_prompt["accepted"][0]), UITheme.INCORRECT_TINT, UITheme.INCORRECT)
		return
	var hint_ja: String = r["hint"]
	var rule := _grammar_rule()
	if rule != "":
		hint_ja += "\n" + rule
	_feedback.add_child(ScreenBase.feedback_card("△ もう{一度|いちど}（%d / %d）" % [_attempts, MAX_ATTEMPTS], hint_ja,
		"Not yet. Check the hint and try again.", UITheme.NEUTRAL_TINT, UITheme.NEUTRAL))
	if r["result"] == SentenceCheck.Result.WRONG_ORDER:
		var report := UITheme.button("この順番も自然だと思う", false)
		report.tooltip_text = "Report this order as natural (saved for review)"
		var snapshot := _answer.duplicate()
		report.pressed.connect(func() -> void:
			Progress.report_natural(_prompt["id"], snapshot)
			report.disabled = true
			UITheme.set_button_text(report, "報告済み"))
		_feedback.add_child(report)
	var bad := int(r["first_bad_index"])
	if bad >= 0 and bad < _answer_flow.get_child_count():
		(_answer_flow.get_child(bad) as TileButton).set_state(UITheme.INCORRECT_TINT, UITheme.INCORRECT)


func _grammar_rule() -> String:
	var ids: Array = _prompt["grammar"]
	for gid in ids:
		var g := ContentDB.grammar_point(gid)
		if not g.is_empty():
			return g.get("one_liner_ja", g.get("explanation_ja", ""))
	return ""


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
		_streak_ok += 1
		_streak_fail = 0
		if _streak_ok >= 3:
			_tier = mini(3, _tier + 1)
			_streak_ok = 0
	else:
		if c > Srs.C_WRONG:
			Progress.add_xp(Mastery.XP[&"sentence_hinted"])
		_streak_fail += 1
		_streak_ok = 0
		if _streak_fail >= 2:
			_tier = maxi(1, _tier - 1)
			_streak_fail = 0
	Progress.save_game()
	Speech.speak(answer_markup)
	_feedback.add_child(ScreenBase.feedback_card(verdict, answer_markup, _prompt["prompt_en"] if Progress.show_english() else "", tint, ink))
	for gid in _prompt["grammar"]:
		var g := ContentDB.grammar_point(gid)
		if g.is_empty():
			continue
		_feedback.add_child(ScreenBase.feedback_card(g["pattern"], g.get("one_liner_ja", ""), g.get("meaning_en", ""), UITheme.NEUTRAL_TINT, UITheme.NEUTRAL))
		break
	var row := UITheme.hbox(12)
	_feedback.add_child(row)
	var next := UITheme.button("次の文へ")
	next.pressed.connect(_load_prompt)
	row.add_child(next)
	var home := UITheme.button("ホームへ", false)
	home.pressed.connect(func() -> void: go(&"dashboard"))
	row.add_child(home)
	set_primary(next)
