extends ScreenBase
## 試験 (GDD §9): the stage gate exam (mode "gate", needs the dashboard unlock), the daily check
## (mode "daily", 10 questions, 250 XP once a day) and a practice sitting (mode "practice", never
## changes the stage). Questions may carry a reading passage or anchor sentence ("context") and
## audio. Listening joins the gate from N4 when a Japanese voice is installed; without a voice it
## is marked as waived rather than blocking the stage.

var _mode := "gate"
var _questions: Array[Dictionary] = []
var _flags: Array[bool] = []
var _index := 0
var _box: VBoxContainer


func _ready() -> void:
	make_column(UITheme.COLUMN_WIDTH)
	_mode = String(args.get("mode", ""))
	add_title("{試験|しけん}　%s" % Mastery.STAGE_LABEL_JA[Progress.stage], "Assessment")
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	if _mode in ["gate", "daily", "practice"] and (_mode != "gate" or Progress.exam_unlocked()):
		_start(_mode)
	else:
		_show_intro()


func _needs_listening() -> bool:
	return (Mastery.GATES.get(Progress.stage, {}) as Dictionary).has(&"listening")


func _show_intro() -> void:
	ScreenBase.clear(_box)
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var gate: Dictionary = Mastery.GATES.get(Progress.stage, {})
	v.add_child(UITheme.ja("{合格基準|ごうかくきじゅん}", UITheme.SIZE_H2))
	if Progress.show_explanations():
		v.add_child(UITheme.en("Your score / the pass mark. 練習する opens the practice that raises that skill.", UITheme.SIZE_LABEL))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var scores := Progress.scores()
	for skill: StringName in gate:
		var ok := int(scores[skill]) >= int(gate[skill])
		grid.add_child(_skill_name(skill))
		grid.add_child(_cell("%d%%" % int(scores[skill]), UITheme.CORRECT if ok else UITheme.TEXT_PRIMARY))
		grid.add_child(_cell("/ %d%%" % int(gate[skill]), UITheme.TEXT_SECONDARY))
		grid.add_child(_practice_button(skill, not ok))
	if _needs_listening() and not Speech.available():
		v.add_child(UITheme.ja("{日本語|にほんご}の{音声|おんせい}がないため、{聴解|ちょうかい}は{免除|めんじょ}されます。", UITheme.SIZE_LABEL, UITheme.WARNING))
	if Progress.show_explanations():
		v.add_child(UITheme.en("Every section must reach its threshold. Fails add a cooldown of 24 h, then 48 h, then 72 h."))
	var row := UITheme.hbox(12)
	v.add_child(row)
	var buttons: Array = []
	var real := UITheme.button("昇級試験")
	real.disabled = not Progress.exam_unlocked()
	real.pressed.connect(_start.bind("gate"))
	row.add_child(real)
	buttons.append(real)
	var daily := UITheme.button("毎日の確認テスト", false)
	daily.pressed.connect(_start.bind("daily"))
	row.add_child(daily)
	buttons.append(daily)
	var practice := UITheme.button("模擬試験", false)
	practice.pressed.connect(_start.bind("practice"))
	row.add_child(practice)
	buttons.append(practice)
	set_options(buttons)
	if real.disabled:
		var why := "{次|つぎ}の{受験|じゅけん}は{少|すこ}し{待|ま}ってください。" if Progress.on_cooldown() else "{本番|ほんばん}はスキルが{基準|きじゅん}に{近|ちか}づくと{受|う}けられます。"
		v.add_child(UITheme.ja(why, UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))


func _start(mode: String) -> void:
	_mode = mode
	var listening := _needs_listening() and Speech.available()
	var pack := ContentDB.stage_pack(Progress.stage)
	if mode == "daily":
		_questions = ExamBuilder.build_daily(pack, Progress.known_word_ids(), Mastery.skills_by_gap(Progress.scores(), Progress.stage).slice(0, 2), listening)
	else:
		_questions = ExamBuilder.build_exam(pack, Progress.known_word_ids(), Progress.recent_exam_items() if mode == "gate" else {}, listening)
	_flags = []
	_index = 0
	_show_question()


func _show_question() -> void:
	ScreenBase.clear(_box)
	set_options([])
	if _index >= _questions.size():
		_show_result()
		return
	var q := _questions[_index]
	var head := UITheme.hbox(12)
	_box.add_child(head)
	head.add_child(UITheme.label("%d / %d" % [_index + 1, _questions.size()], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	head.add_child(UITheme.hspacer())
	var sk := UITheme.ja(Mastery.SKILL_LABEL_JA[q["skill"]], UITheme.SIZE_LABEL, UITheme.SKILL_INK[q["skill"]])
	sk.autowrap = false
	head.add_child(sk)
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	if q.has("context"):
		var ctx := UITheme.card(UITheme.SURFACE_ALT, UITheme.BORDER)
		var cv := UITheme.vbox(6)
		ctx.add_child(cv)
		if q.has("context_title"):
			cv.add_child(UITheme.ja(q["context_title"], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
		cv.add_child(UITheme.ja(q["context"], UITheme.SIZE_BODY))
		v.add_child(ctx)
	var prow := UITheme.hbox(8)
	v.add_child(prow)
	var prompt := UITheme.ja(q["prompt"], UITheme.SIZE_H2)
	prompt.show_ruby = not q.get("hide_ruby", false)
	prow.add_child(prompt)
	if q.has("audio") and (q.get("listen_only", false) or q["skill"] == &"conversation"):
		prow.add_child(ScreenBase.speak_button(q["audio"]))
		if q.get("listen_only", false):
			Speech.speak(q["audio"])
	if Progress.show_explanations():
		v.add_child(UITheme.en(q["prompt_en"], UITheme.SIZE_LABEL))
	var buttons: Array = []
	for i in (q["options"] as Array).size():
		var b := TileButton.new(q["options"][i], UITheme.SIZE_BODY)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.enable_wrap()
		b.pressed.connect(_answer.bind(i))
		v.add_child(b)
		buttons.append(b)
	set_options(buttons)
	UITheme.animate_in(card)


func _answer(chosen: int) -> void:
	var q := _questions[_index]
	var correct: bool = chosen == int(q["answer"])
	_flags.append(correct)
	var c := Srs.C_CORRECT if correct else Srs.C_WRONG
	Progress.record_sample(q["activity"], c, true)
	if q["word_id"] != "":
		Progress.record_word_answer(q["word_id"], q["dimension"], c, false)
	for gid in q.get("grammar", []):
		Progress.record_grammar(gid, correct)
	_index += 1
	_show_question()


func _show_result() -> void:
	var sections := ExamBuilder.section_scores(_questions, _flags)
	var waived := _needs_listening() and not Speech.available()
	if waived:
		sections[&"listening"] = 100
	var result: Dictionary
	match _mode:
		"gate":
			var ids: Array = []
			for q in _questions:
				ids.append(q.get("item_id", ""))
			result = Progress.record_exam(sections, ids)
		"daily":
			var total := 0
			for f in _flags:
				total += 1 if f else 0
			var pct := roundi(100.0 * total / maxf(1.0, float(_flags.size())))
			Progress.record_daily(pct)
			result = {"passed": pct >= Recommender.DAILY_EXAM_SCORE, "required": {}}
		_:
			result = Mastery.evaluate_gate(sections, Progress.stage)
			Progress.save_game()
	var passed: bool = result["passed"]
	var card := UITheme.card(UITheme.CORRECT_TINT if passed else UITheme.INCORRECT_TINT, UITheme.CORRECT if passed else UITheme.INCORRECT)
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var title := ""
	match _mode:
		"gate": title = "{合格|ごうかく}！" if passed else "{不合格|ふごうかく}"
		"daily": title = "{確認|かくにん}テスト{完了|かんりょう}"
		_: title = "{模擬試験|もぎしけん}：" + ("{合格|ごうかく}ライン" if passed else "あと{少|すこ}し")
	v.add_child(UITheme.ja(title, UITheme.SIZE_H1, UITheme.CORRECT if passed else UITheme.INCORRECT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var required: Dictionary = result.get("required", {})
	for skill: StringName in sections:
		var is_waived := waived and skill == &"listening"
		grid.add_child(_skill_name(skill))
		var shown := UITheme.ja("{免除|めんじょ}" if is_waived else "%d%%" % int(sections[skill]), UITheme.SIZE_LABEL)
		shown.autowrap = false
		shown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		shown.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		grid.add_child(shown)
		var ok := true
		if required.has(skill):
			ok = int(sections[skill]) >= int(required[skill])
			grid.add_child(_cell(("○ / %d" if ok else "✕ / %d") % int(required[skill]), UITheme.CORRECT if ok else UITheme.INCORRECT))
		else:
			grid.add_child(_cell("", UITheme.TEXT_SECONDARY))
		if is_waived:
			grid.add_child(Control.new())
		else:
			grid.add_child(_practice_button(skill, not ok))
	if _mode == "gate" and passed:
		v.add_child(UITheme.ja("{次|つぎ}のステージ：%s　＋%d XP" % [Mastery.STAGE_LABEL_JA[Progress.stage], Mastery.EXAM_PASS_XP], UITheme.SIZE_BODY))
	elif _mode == "gate":
		var hours := ceili(float(Progress.cooldown_until - Progress.now()) / 3600.0)
		v.add_child(UITheme.ja("%d{時間後|じかんご}にもう{一度|いちど}{受|う}けられます。" % hours, UITheme.SIZE_BODY))
	var home := UITheme.button("ホームへ")
	home.pressed.connect(func() -> void: go(&"dashboard"))
	v.add_child(home)
	set_primary(home)
	UITheme.animate_in(card)


func _skill_name(skill: StringName) -> Control:
	var name := ScreenBase.ja_en(Mastery.SKILL_LABEL_JA[skill], Mastery.SKILL_LABEL_EN[skill], UITheme.SIZE_LABEL, UITheme.SKILL_INK[skill])
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name.custom_minimum_size.x = 150  # wrapping labels have no width of their own
	return name


func _cell(text: String, color: Color) -> Label:
	var l := UITheme.label(text, UITheme.SIZE_LABEL, color)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## Opens the activity that trains [param skill] (the same mapping as 次にやること). Skills below
## their pass mark get the filled style so the next step stands out.
func _practice_button(skill: StringName, highlight: bool) -> Button:
	var rec := Recommender.for_skill(skill, Progress.recommender_input())
	var b := UITheme.button("練習する", highlight)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.tooltip_text = ScreenBase.activity_en(rec["screen"], rec["mode"])
	b.pressed.connect(func() -> void: go(rec["screen"], {"mode": rec["mode"]}))
	return b
