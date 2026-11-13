extends ScreenBase
## 文法レッスン (GDD §9.3): pick a grammar point of an unlocked stage, read the explanation and
## examples, then answer six quiz items. Five or more correct marks the lesson as done; every
## answer counts toward the point's coverage (3 correct = covered).

const ITEMS_PER_LESSON := 6

var _point: Dictionary = {}
var _items: Array = []
var _index := 0
var _correct := 0
var _box: VBoxContainer


func _ready() -> void:
	make_column(UITheme.COLUMN_WIDTH)
	add_title("{文法|ぶんぽう}レッスン", "Grammar lessons")
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	if args.has("grammar_id"):
		_open(ContentDB.grammar_point(args["grammar_id"]))
	else:
		_show_list()


func _show_list() -> void:
	ScreenBase.clear(_box)
	var points := ContentDB.unlocked_items("grammar", Progress.stage)
	var current := ContentDB.stage_items("grammar", Progress.stage)
	# Current stage first, least-covered first; then earlier stages.
	current = current.duplicate()
	current.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(Progress.grammar.get(a["id"], {}).get("correct", 0)) < int(Progress.grammar.get(b["id"], {}).get("correct", 0)))
	var ordered: Array = current + points.filter(func(p: Dictionary) -> bool: return p not in current)
	var buttons: Array = []
	for g in ordered:
		var rec: Dictionary = Progress.grammar.get(g["id"], {})
		var done: bool = rec.get("lesson_done", false)
		var covered := int(rec.get("correct", 0)) >= Mastery.GRAMMAR_COVERED_AT
		var b := TileButton.new("%s　%s" % ["○" if done else ("◐" if covered else "・"), g["pattern"]], UITheme.SIZE_BODY,
			g["meaning_en"] if Progress.show_english() else "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%s — %s" % [g["level"], g["meaning_en"]]
		if done:
			b.set_state(UITheme.CORRECT_TINT, UITheme.CORRECT)
		b.pressed.connect(_open.bind(g))
		_box.add_child(b)
		buttons.append(b)
	set_options(buttons.slice(0, 9))


func _open(g: Dictionary) -> void:
	if g.is_empty():
		_show_list()
		return
	_point = g
	_items = (g["items"] as Array).duplicate()
	_items.shuffle()
	_items = _items.slice(0, ITEMS_PER_LESSON)
	_index = 0
	_correct = 0
	ScreenBase.clear(_box)
	set_options([])
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(12)
	card.add_child(v)
	v.add_child(UITheme.ja(g["pattern"], UITheme.SIZE_H1))
	v.add_child(UITheme.label("%s · %s" % [g["level"], g["meaning_en"]], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	v.add_child(UITheme.ja(g["explanation_ja"], UITheme.SIZE_BODY_L))
	if Progress.show_explanations():
		v.add_child(UITheme.en(g["explanation_en"], UITheme.SIZE_BODY_L))
	v.add_child(UITheme.ja("{例文|れいぶん}", UITheme.SIZE_H2))
	for ex in g["examples"]:
		var line := UITheme.hbox(8)
		v.add_child(line)
		line.add_child(UITheme.ja(ex["ja"], UITheme.SIZE_BODY_L))
		line.add_child(ScreenBase.speak_button(ex["ja"]))
		if Progress.show_english():
			v.add_child(UITheme.en(ex["en"], UITheme.SIZE_BODY))
	UITheme.animate_in(card)
	var start := UITheme.button("練習を始める")
	start.pressed.connect(_show_item)
	_box.add_child(start)
	set_primary(start)


func _show_item() -> void:
	ScreenBase.clear(_box)
	if _index >= _items.size():
		_finish()
		return
	var item: Dictionary = _items[_index]
	_box.add_child(UITheme.label("%d / %d" % [_index + 1, _items.size()], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja(item["ja"], UITheme.SIZE_H2))
	var buttons: Array = []
	var opts: Array = item["options"]
	for i in opts.size():
		var b := TileButton.new(opts[i], UITheme.SIZE_BODY)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_answer.bind(i, v))
		v.add_child(b)
		buttons.append(b)
	set_options(buttons)
	UITheme.animate_in(card)


func _answer(chosen: int, v: VBoxContainer) -> void:
	var item: Dictionary = _items[_index]
	var correct := chosen == int(item["answer"])
	set_options([])
	var buttons := v.get_children().filter(func(c: Node) -> bool: return c is TileButton)
	for i in buttons.size():
		var b: TileButton = buttons[i]
		b.disabled = true
		if i == int(item["answer"]):
			b.set_state(UITheme.CORRECT_TINT, UITheme.CORRECT)
		elif i == chosen:
			b.set_state(UITheme.INCORRECT_TINT, UITheme.INCORRECT)
	Progress.record_grammar(_point["id"], correct)
	Progress.record_sample(&"grammar_quiz", Srs.C_CORRECT if correct else Srs.C_WRONG)
	if correct:
		_correct += 1
		Progress.add_xp(Mastery.XP[&"grammar_quiz"])
	var full := String(item["ja"]).replace("［　］", "［%s］" % opts_text(item, int(item["answer"])))
	_box.add_child(ScreenBase.feedback_card("○ {正解|せいかい}" if correct else "✕ {不正解|ふせいかい}",
		"%s\n%s" % [full, item["why_ja"]], item["why_en"],
		UITheme.CORRECT_TINT if correct else UITheme.INCORRECT_TINT, UITheme.CORRECT if correct else UITheme.INCORRECT))
	var next := UITheme.button("次へ")
	next.pressed.connect(func() -> void:
		_index += 1
		_show_item())
	_box.add_child(next)
	set_primary(next)


static func opts_text(item: Dictionary, i: int) -> String:
	return String(item["options"][i])


func _finish() -> void:
	Progress.finish_grammar_lesson(_point["id"], _correct)
	var passed := _correct >= 5
	var card := UITheme.card(UITheme.CORRECT_TINT if passed else UITheme.SURFACE, UITheme.CORRECT if passed else UITheme.BORDER)
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja("{結果|けっか}：%d / %d" % [_correct, _items.size()], UITheme.SIZE_H1))
	v.add_child(UITheme.ja("レッスン{完了|かんりょう}！" if passed else "5{問以上|もんいじょう}{正解|せいかい}で{完了|かんりょう}です。もう{一度|いちど}{挑戦|ちょうせん}しましょう。", UITheme.SIZE_BODY))
	v.add_child(UITheme.ja(_point["one_liner_ja"], UITheme.SIZE_BODY, UITheme.NEUTRAL))
	var row := UITheme.hbox(12)
	v.add_child(row)
	var again := UITheme.button("もう一回", not passed)
	again.pressed.connect(_open.bind(_point))
	row.add_child(again)
	var list := UITheme.button("一覧へ", passed)
	list.pressed.connect(_show_list)
	row.add_child(list)
	var build := UITheme.button("文を作る", false)
	build.pressed.connect(func() -> void: go(&"sentences", {"grammar_id": _point["id"]}))
	row.add_child(build)
	set_primary(list if passed else again)
	UITheme.animate_in(card)
