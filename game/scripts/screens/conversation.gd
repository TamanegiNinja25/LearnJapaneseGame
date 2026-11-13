extends ScreenBase
## 会話: scenario conversations (GDD §8). A list of scenarios from unlocked stages (optionally
## filtered by town location), then turn by turn: the NPC line is spoken when a Japanese voice is
## installed; the player chooses (正解 / 惜しい / 不正解) or, in typed mode, writes the answer,
## graded against the turn's typed list with particle feedback. A wrong pick removes the option
## and caps the retry at half credit.

const REGISTER_JA := {"casual": "タメ{口|ぐち}", "polite": "{丁寧語|ていねいご}", "business": "ビジネス{敬語|けいご}",
	"respectful": "{尊敬語|そんけいご}・{謙譲語|けんじょうご}", "written": "{書|か}き{言葉|ことば}"}

var _scenario: Dictionary = {}
var _turn := 0
var _turn_scores: Array[float] = []
var _retry := false
var _removed: Array = []
var _box: VBoxContainer
var _history: VBoxContainer


func _ready() -> void:
	make_column(UITheme.COLUMN_WIDTH)
	if args.has("scenario_id"):
		_start(ContentDB.scenario(args["scenario_id"]))
	else:
		_show_list()


func _available() -> Array:
	var all := ContentDB.unlocked_items("scenarios", Progress.stage)
	if args.has("location"):
		var loc: String = args["location"]
		var here := all.filter(func(s: Dictionary) -> bool: return Furigana.plain(s["location"]) == loc)
		if not here.is_empty():
			return here
	return all


func _show_list() -> void:
	ScreenBase.clear(column)
	add_title("{会話|かいわ}シナリオ", "Conversation scenarios")
	column.add_child(UITheme.toggle("入力モード（タイプで答える）", bool(Progress.setting("typed_answers")),
		func(on: bool) -> void: Progress.set_setting("typed_answers", on), "Type your answers instead of choosing"))
	var buttons: Array = []
	for sc in _available():
		var rec: Dictionary = Progress.scenarios.get(sc["id"], {})
		var star := "★" if float(rec.get("best", 0.0)) >= 0.8 else "・"
		var b := TileButton.new("%s %s　%s · %s" % [star, sc["title_ja"], sc["level"], sc["location"]], UITheme.SIZE_BODY,
			sc["title_en"] if Progress.show_english() else "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = sc["title_en"]
		b.pressed.connect(_start.bind(sc))
		column.add_child(b)
		buttons.append(b)
	set_options(buttons.slice(0, 9))


func _start(sc: Dictionary) -> void:
	if sc.is_empty():
		_show_list()
		return
	_scenario = sc
	_turn = 0
	_turn_scores.clear()
	ScreenBase.clear(column)
	add_title(sc["title_ja"], sc["title_en"])
	column.add_child(UITheme.ja("%s · %s" % [sc["location"], REGISTER_JA.get(sc.get("register", "polite"), "")], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	_history = UITheme.vbox(8)
	column.add_child(_history)
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	_show_turn()


func _show_turn() -> void:
	_retry = false
	_removed = []
	if _turn >= (_scenario["turns"] as Array).size():
		_show_summary()
		return
	_render_turn()


func _render_turn() -> void:
	ScreenBase.clear(_box)
	var turn: Dictionary = _scenario["turns"][_turn]
	var npc := UITheme.card()
	_box.add_child(npc)
	var nv := UITheme.vbox(8)
	npc.add_child(nv)
	var head := UITheme.hbox(8)
	nv.add_child(head)
	head.add_child(UITheme.ja(turn["speaker"], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	head.add_child(ScreenBase.speak_button(turn["line_ja"]))
	nv.add_child(UITheme.ja(turn["line_ja"], UITheme.SIZE_BODY_L))
	if Progress.show_english():
		nv.add_child(UITheme.en(turn["line_en"], UITheme.SIZE_BODY_L))
	UITheme.animate_in(npc)
	Speech.speak(turn["line_ja"])
	_box.add_child(UITheme.ja("あなた：", UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	if bool(Progress.setting("typed_answers")) and not (turn.get("typed", []) as Array).is_empty():
		_typed(turn)
		return
	var buttons: Array = []
	for opt in ScreenBase.shuffled(turn["options"]):
		if opt["ja"] in _removed:
			continue
		var b := TileButton.new(opt["ja"], UITheme.SIZE_BODY_L, String(opt.get("en", "")) if Progress.show_english() else "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose.bind(opt))
		_box.add_child(b)
		buttons.append(b)
	set_options(buttons)


func _typed(turn: Dictionary) -> void:
	var row := UITheme.hbox(12)
	_box.add_child(row)
	var input := LineEdit.new()
	input.placeholder_text = "にほんごで（romaji → かな / IME）"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size.y = 56
	input.text_changed.connect(func(t: String) -> void:
		if Romaji.has_latin(t):
			var conv := Romaji.to_hiragana(t)
			if conv != t:
				input.text = conv
				input.caret_column = conv.length())
	row.add_child(input)
	var send := UITheme.button("話す")
	row.add_child(send)
	var hint_box := UITheme.vbox(4)
	_box.add_child(hint_box)
	var correct_opt: Dictionary = {}
	for opt in turn["options"]:
		if opt["verdict"] == "correct":
			correct_opt = opt
	var accepted: Array = (turn["typed"] as Array).duplicate()
	accepted.append(correct_opt.get("ja", ""))
	var submit := func() -> void:
		var r := AnswerMatch.grade(input.text, accepted)
		if r["correct"]:
			_choose(correct_opt)
			return
		# Typed answers that match a scripted unnatural/wrong option get that option's feedback.
		for opt in turn["options"]:
			if opt["verdict"] != "correct" and AnswerMatch.grade(input.text, [opt["ja"]])["correct"]:
				_choose(opt)
				return
		ScreenBase.clear(hint_box)
		_retry = true
		Progress.record_sample(&"scenario_turn", Srs.C_WRONG)
		var msg: String = r["hint_ja"] if r["hint_ja"] != "" else "{伝|つた}わりませんでした。もう{一度|いちど}。"
		hint_box.add_child(ScreenBase.feedback_card("△", msg, "Try again. Choices are shown below if you need them.", UITheme.NEUTRAL_TINT, UITheme.NEUTRAL))
		var show := UITheme.button("選択肢を見る", false)
		show.pressed.connect(func() -> void:
			Progress.set_setting("typed_answers", false)
			_render_turn())
		hint_box.add_child(show)
	send.pressed.connect(submit)
	input.text_submitted.connect(func(_t: String) -> void: submit.call())
	setup_text_input(input)


func _choose(opt: Dictionary) -> void:
	var turn: Dictionary = _scenario["turns"][_turn]
	var tag: String = opt["verdict"]
	var c := Srs.C_CORRECT if tag == "correct" else (Srs.C_PARTIAL if tag == "unnatural" else Srs.C_WRONG)
	if _retry:
		c = minf(c, Srs.C_PARTIAL)
	var verdict := "○ {正解|せいかい}"
	var tint := UITheme.CORRECT_TINT
	var ink := UITheme.CORRECT
	if tag == "unnatural":
		verdict = "△ {惜|お}しい"
		tint = UITheme.NEUTRAL_TINT
		ink = UITheme.WARNING
	elif tag == "wrong":
		verdict = "✕ {不正解|ふせいかい}"
		tint = UITheme.INCORRECT_TINT
		ink = UITheme.INCORRECT
	set_options([])
	ScreenBase.clear(_box)
	_box.add_child(ScreenBase.feedback_card(verdict, opt["feedback_ja"], opt["feedback_en"], tint, ink))
	if opt.has("register") and opt["register"] != _scenario.get("register", "polite"):
		_box.add_child(UITheme.ja("この{答|こた}えは「%s」です。" % REGISTER_JA.get(opt["register"], opt["register"]), UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	if tag == "wrong":
		_removed.append(opt["ja"])
		_retry = true
		Progress.record_sample(&"scenario_turn", Srs.C_WRONG)
		_box.add_child(UITheme.ja("%s「すみません、もう{一度|いちど}お{願|ねが}いします。」" % turn["speaker"], UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
		var again := UITheme.button("もう一度")
		again.pressed.connect(_render_turn)
		_box.add_child(again)
		set_primary(again)
		return
	_turn_scores.append(c)
	Progress.record_sample(&"scenario_turn", c)
	Progress.add_xp(Mastery.XP[&"scenario_turn"])
	if c >= Srs.C_CORRECT:
		for seg in Furigana.parse(opt["ja"]):
			var entry := ContentDB.word_by_headword(seg["base"])
			if not entry.is_empty():
				Progress.record_word_answer(entry["id"], "use", Srs.C_CORRECT, false)
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
	set_primary(next)


func _show_summary() -> void:
	ScreenBase.clear(_box)
	var total := 0.0
	for s in _turn_scores:
		total += s
	var score := total / maxf(1.0, float(_turn_scores.size()))
	var first_today: bool = _scenario["id"] not in Progress.daily.get("scenarios_rewarded", [])
	Progress.record_scenario(_scenario["id"], score)
	if first_today:
		var rewarded: Array = Progress.daily.get("scenarios_rewarded", [])
		rewarded.append(_scenario["id"])
		Progress.daily["scenarios_rewarded"] = rewarded
		Progress.add_xp(Mastery.XP[&"scenario_complete"])
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
	again.pressed.connect(_start.bind(_scenario))
	row.add_child(again)
	var list := UITheme.button("シナリオ一覧", false)
	list.pressed.connect(func() -> void: go(&"conversation"))
	row.add_child(list)
	if args.has("from_town"):
		var back := UITheme.button("町へ戻る", false)
		back.pressed.connect(func() -> void: go(&"town"))
		row.add_child(back)
		set_primary(back)
	else:
		set_primary(list)
	UITheme.animate_in(card)
