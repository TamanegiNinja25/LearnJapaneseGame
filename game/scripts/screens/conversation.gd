extends ScreenBase
## 会話: scenario conversation (GDD §8). Each NPC line offers 正解 / 惜しい / 不正解 options.
## A wrong pick removes the option and lets the player choose again at half credit.

var _scenario: Dictionary = {}
var _turn := 0
var _turn_scores: Array[float] = []
var _retry := false
var _removed: Array = []

var _box: VBoxContainer
var _history: VBoxContainer


func _ready() -> void:
	make_column(UITheme.COLUMN_WIDTH)
	_scenario = ContentDB.scenarios[0] if not ContentDB.scenarios.is_empty() else {}
	if _scenario.is_empty():
		column.add_child(UITheme.ja("シナリオがありません。", UITheme.SIZE_BODY))
		return
	add_title(_scenario["title_ja"], _scenario["title_en"])
	_history = UITheme.vbox(8)
	column.add_child(_history)
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	_show_turn()


func _show_turn() -> void:
	ScreenBase.clear(_box)
	_retry = false
	_removed = []
	if _turn >= (_scenario["turns"] as Array).size():
		_show_summary()
		return
	_render_options()


func _render_options() -> void:
	ScreenBase.clear(_box)
	var turn: Dictionary = _scenario["turns"][_turn]
	var npc := UITheme.card()
	_box.add_child(npc)
	var nv := UITheme.vbox(8)
	npc.add_child(nv)
	nv.add_child(UITheme.ja(turn["speaker"], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	nv.add_child(UITheme.ja(turn["line_ja"], UITheme.SIZE_BODY_L))
	if Progress.show_english():
		nv.add_child(UITheme.en(turn["line_en"], UITheme.SIZE_BODY_L))

	_box.add_child(UITheme.ja("あなた：", UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	var options: Array = ScreenBase.shuffled(turn["options"])
	for opt in options:
		if opt["ja"] in _removed:
			continue
		var b := TileButton.new(opt["ja"], UITheme.SIZE_BODY_L)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose.bind(opt))
		_box.add_child(b)


func _choose(opt: Dictionary) -> void:
	var turn: Dictionary = _scenario["turns"][_turn]
	var verdict_tag: String = opt["verdict"]
	var c := Srs.C_CORRECT if verdict_tag == "correct" else (Srs.C_PARTIAL if verdict_tag == "unnatural" else Srs.C_WRONG)
	if _retry:
		c = minf(c, Srs.C_PARTIAL)
	var verdict := "○ {正解|せいかい}"
	var tint := UITheme.CORRECT_TINT
	var ink := UITheme.CORRECT
	if verdict_tag == "unnatural":
		verdict = "△ {惜|お}しい"
		tint = UITheme.NEUTRAL_TINT
		ink = UITheme.WARNING
	elif verdict_tag == "wrong":
		verdict = "✕ {不正解|ふせいかい}"
		tint = UITheme.INCORRECT_TINT
		ink = UITheme.INCORRECT
	ScreenBase.clear(_box)
	_box.add_child(ScreenBase.feedback_card(verdict, opt["feedback_ja"], opt["feedback_en"], tint, ink))

	if verdict_tag == "wrong":
		# NPC asks again; the option is removed and the retry is capped at partial credit.
		_removed.append(opt["ja"])
		_retry = true
		Progress.record_sample(&"scenario_turn", Srs.C_WRONG)
		_box.add_child(UITheme.ja("{店員|てんいん}「すみません、もう{一度|いちど}お{願|ねが}いします。」", UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
		var again := UITheme.button("もう一度選ぶ")
		again.pressed.connect(_render_options)
		_box.add_child(again)
		again.grab_focus()
		return

	_turn_scores.append(c)
	Progress.record_sample(&"scenario_turn", c)
	Progress.add_xp(Mastery.XP[&"scenario_turn"])
	if c >= Srs.C_CORRECT and not _retry:
		for seg in Furigana.parse(opt["ja"]):
			var entry := ContentDB.word_by_headword(seg["base"])
			if not entry.is_empty():
				Progress.record_word_answer(entry["id"], "use", Srs.C_CORRECT, false)
	# Log the exchange above.
	var line := UITheme.card(UITheme.SURFACE_ALT, UITheme.BORDER)
	var lv := UITheme.vbox(4)
	line.add_child(lv)
	lv.add_child(UITheme.ja("%s「%s」" % [turn["speaker"], turn["line_ja"]], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	lv.add_child(UITheme.ja("あなた「%s」" % opt["ja"], UITheme.SIZE_LABEL, ink))
	_history.add_child(line)
	var next := UITheme.button("次へ")
	next.pressed.connect(func() -> void:
		_turn += 1
		_show_turn())
	_box.add_child(next)
	next.grab_focus()


func _show_summary() -> void:
	var total := 0.0
	for s in _turn_scores:
		total += s
	var score := total / maxf(1.0, float(_turn_scores.size()))
	Progress.record_scenario(_scenario["id"], score)
	var rewarded: Array = Progress.daily.get("scenarios_rewarded", [])
	if _scenario["id"] not in rewarded:
		rewarded.append(_scenario["id"])
		Progress.daily["scenarios_rewarded"] = rewarded
		Progress.add_xp(Mastery.XP[&"scenario_complete"])
	Progress.bump_stat("conversations")
	Progress.save_game()
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja("{会話|かいわ}{終了|しゅうりょう}" + ("　★" if score >= 0.8 else ""), UITheme.SIZE_H2))
	v.add_child(UITheme.label("%d%%" % roundi(score * 100), UITheme.SIZE_DISPLAY))
	if Progress.show_english():
		v.add_child(UITheme.en("Scenario score. 80% or more earns a star."))
	var row := UITheme.hbox(12)
	v.add_child(row)
	var again := UITheme.button("もう一回")
	again.pressed.connect(func() -> void: navigate.emit(&"conversation"))
	row.add_child(again)
	var home := UITheme.button("ホームへ", false)
	home.pressed.connect(func() -> void: navigate.emit(&"dashboard"))
	row.add_child(home)
