extends ScreenBase
## 試験: the stage gate exam (GDD §9.1). Real sittings require the dashboard unlock; a practice
## sitting (模擬試験) is always available, records samples, but never changes the stage.

var _questions: Array[Dictionary] = []
var _flags: Array[bool] = []
var _index := 0
var _practice := false
var _box: VBoxContainer


func _ready() -> void:
	make_column(UITheme.COLUMN_WIDTH)
	add_title("{昇級試験|しょうきゅうしけん}　%s" % Mastery.STAGE_LABEL_JA[Progress.stage], "Stage exam")
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	_show_intro()


func _show_intro() -> void:
	ScreenBase.clear(_box)
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var gate: Dictionary = Mastery.GATES.get(Progress.stage, {})
	v.add_child(UITheme.ja("{合格基準|ごうかくきじゅん}", UITheme.SIZE_H2))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	v.add_child(grid)
	for skill: StringName in gate:
		grid.add_child(UITheme.ja(Mastery.SKILL_LABEL_JA[skill], UITheme.SIZE_LABEL, UITheme.SKILL_INK[skill]))
		grid.add_child(UITheme.label("%d%%" % int(gate[skill]), UITheme.SIZE_LABEL))
	if Progress.show_explanations():
		v.add_child(UITheme.en("Every section must reach its threshold. A failed sitting has a 24 h cooldown."))
	var row := UITheme.hbox(12)
	v.add_child(row)
	var real := UITheme.button("試験を受ける")
	real.disabled = not Progress.exam_unlocked()
	real.pressed.connect(func() -> void: _start(false))
	row.add_child(real)
	var practice := UITheme.button("模擬試験", false)
	practice.pressed.connect(func() -> void: _start(true))
	row.add_child(practice)
	if real.disabled:
		v.add_child(UITheme.ja("{本番|ほんばん}はホームの{条件|じょうけん}を{満|み}たすと{受|う}けられます。", UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))


func _start(practice: bool) -> void:
	_practice = practice
	_questions = ExamBuilder.build_exam(ContentDB.vocab, ContentDB.sentences, ContentDB.scenarios)
	_flags = []
	_index = 0
	_show_question()


func _show_question() -> void:
	ScreenBase.clear(_box)
	if _index >= _questions.size():
		_show_result()
		return
	var q := _questions[_index]
	var head := UITheme.hbox(12)
	_box.add_child(head)
	head.add_child(UITheme.label("%d / %d" % [_index + 1, _questions.size()], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	head.add_child(UITheme.hspacer())
	head.add_child(UITheme.ja(Mastery.SKILL_LABEL_JA[q["skill"]], UITheme.SIZE_LABEL, UITheme.SKILL_INK[q["skill"]]))
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var prompt := UITheme.ja(q["prompt"], UITheme.SIZE_H2)
	prompt.show_ruby = not q.get("hide_ruby", false)
	v.add_child(prompt)
	if Progress.show_explanations():
		v.add_child(UITheme.en(q["prompt_en"], UITheme.SIZE_LABEL))
	for i in (q["options"] as Array).size():
		var b := TileButton.new(q["options"][i], UITheme.SIZE_BODY)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_answer.bind(i))
		v.add_child(b)


func _answer(chosen: int) -> void:
	var q := _questions[_index]
	var correct: bool = chosen == int(q["answer"])
	_flags.append(correct)
	var c := Srs.C_CORRECT if correct else Srs.C_WRONG
	Progress.record_sample(q["activity"], c, true)
	if q["word_id"] != "":
		Progress.record_word_answer(q["word_id"], q["dimension"], c, false)
	if q.has("grammar"):
		for gid in q["grammar"]:
			Progress.record_grammar(gid, correct)
	_index += 1
	_show_question()


func _show_result() -> void:
	var sections := ExamBuilder.section_scores(_questions, _flags)
	var result: Dictionary
	if _practice:
		result = Mastery.evaluate_gate(sections, Progress.stage)
		Progress.save_game()
	else:
		result = Progress.record_exam(sections)
	var passed: bool = result["passed"]
	var card := UITheme.card(UITheme.CORRECT_TINT if passed else UITheme.INCORRECT_TINT, UITheme.CORRECT if passed else UITheme.INCORRECT)
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var title := "{合格|ごうかく}！" if passed else "{不合格|ふごうかく}"
	if _practice:
		title = "{模擬試験|もぎしけん}の{結果|けっか}：" + title
	v.add_child(UITheme.ja(title, UITheme.SIZE_H1, UITheme.CORRECT if passed else UITheme.INCORRECT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	v.add_child(grid)
	var required: Dictionary = result["required"]
	for skill: StringName in sections:
		grid.add_child(UITheme.ja(Mastery.SKILL_LABEL_JA[skill], UITheme.SIZE_LABEL, UITheme.SKILL_INK[skill]))
		grid.add_child(UITheme.label("%d%%" % int(sections[skill]), UITheme.SIZE_LABEL))
		var ok := int(sections[skill]) >= int(required.get(skill, 0))
		grid.add_child(UITheme.label(("○ / %d" if ok else "✕ / %d") % int(required.get(skill, 0)), UITheme.SIZE_LABEL, UITheme.CORRECT if ok else UITheme.INCORRECT))
	if passed and not _practice:
		v.add_child(UITheme.ja("{次|つぎ}のステージ：%s　＋%d XP" % [Mastery.STAGE_LABEL_JA[Progress.stage], Mastery.EXAM_PASS_XP], UITheme.SIZE_BODY))
	elif not passed and not _practice:
		v.add_child(UITheme.ja("24{時間後|じかんご}にもう{一度|いちど}{受|う}けられます。", UITheme.SIZE_BODY))
	if Progress.show_english():
		v.add_child(UITheme.en("Sections below their threshold are marked ✕."))
	var home := UITheme.button("ホームへ")
	home.pressed.connect(func() -> void: navigate.emit(&"dashboard"))
	v.add_child(home)
