extends ScreenBase
## 復習: the spaced-repetition queue. Each due word gets the question type for its weakest
## unlocked dimension (GDD §6.4); the answer updates counters, rank, box and due time.

var _queue: Array[String] = []
var _index := 0
var _correct := 0
var _box: VBoxContainer


func _ready() -> void:
	make_column(820)
	add_title("{復習|ふくしゅう}", "Review")
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	_queue = Progress.due_words(20)
	_index = 0
	_correct = 0
	_show_next()


func _show_next() -> void:
	ScreenBase.clear(_box)
	if _queue.is_empty():
		_show_empty()
		return
	if _index >= _queue.size():
		_show_summary()
		return
	var id := _queue[_index]
	var entry := ContentDB.word(id)
	var q := _question_for(entry)
	_box.add_child(UITheme.label("%d / %d" % [_index + 1, _queue.size()], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var prompt := UITheme.ja(q["prompt"], UITheme.SIZE_H1)
	prompt.show_ruby = not q.get("hide_ruby", false)
	prompt.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(prompt)
	if Progress.show_explanations():
		var hint := UITheme.en(q["prompt_en"], UITheme.SIZE_LABEL)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2 if q["skill"] != &"reading" else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for i in (q["options"] as Array).size():
		var b := TileButton.new(q["options"][i], UITheme.SIZE_BODY)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_answer.bind(q, i, grid))
		grid.add_child(b)


## GDD §6.4: pick the dimension with the lowest counter among those unlocked for the rank.
func _question_for(entry: Dictionary) -> Dictionary:
	var w := Progress.word(entry["id"])
	var rank := int(w["rank"])
	var has_kanji: bool = entry["headword"] != entry["reading"]
	var candidates: Array = []  # [dimension, builder]
	candidates.append(["rec", "recognition"])
	if has_kanji:
		candidates.append(["rec", "kanji"])
	if rank >= Mastery.Rank.LEARNED:
		candidates.append(["rcl", "recall"])
	if rank >= Mastery.Rank.PROFICIENT:
		candidates.append(["use", "usage"])
		candidates.append(["rec", "example"])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return int(w[a[0]]) < int(w[b[0]]))
	# Among equal-counter candidates, vary the type a little.
	var lowest := int(w[candidates[0][0]])
	var ties := candidates.filter(func(c: Array) -> bool: return int(w[c[0]]) == lowest)
	var pick: Array = ties[randi() % ties.size()]
	var q := {}
	match pick[1]:
		"kanji":
			var pool := ContentDB.vocab.filter(func(e: Dictionary) -> bool: return e["headword"] != e["reading"])
			q = ExamBuilder.kanji_reading_question(entry, pool)
		"recall":
			q = ExamBuilder.recall_question(entry, ContentDB.vocab)
		"usage":
			q = ExamBuilder.usage_question(entry, ContentDB.vocab)
			if q.is_empty():
				q = ExamBuilder.recall_question(entry, ContentDB.vocab)
		"example":
			q = ExamBuilder.example_reading_question(entry, ContentDB.vocab)
		_:
			q = ExamBuilder.recognition_question(entry, ContentDB.vocab)
	return q


func _answer(q: Dictionary, chosen: int, grid: GridContainer) -> void:
	var correct: bool = chosen == int(q["answer"])
	var c := Srs.C_CORRECT if correct else Srs.C_WRONG
	Progress.record_word_answer(q["word_id"], q["dimension"], c)
	Progress.record_sample(q["activity"], c)
	if correct:
		_correct += 1
		Progress.add_xp(Mastery.XP[&"review"])
	for i in grid.get_child_count():
		var b: TileButton = grid.get_child(i)
		b.disabled = true
		if i == int(q["answer"]):
			b.set_state(UITheme.CORRECT_TINT, UITheme.CORRECT)
		elif i == chosen:
			b.set_state(UITheme.INCORRECT_TINT, UITheme.INCORRECT)
	var entry := ContentDB.word(q["word_id"])
	var w := Progress.word(q["word_id"])
	var verdict := "○ {正解|せいかい}" if correct else "✕ {不正解|ふせいかい}"
	var detail := "%s（%s）— %s\n{習得度|しゅうとくど}：%s　{次|つぎ}の{復習|ふくしゅう}：%s" % [
		entry["headword"], entry["reading"], entry["definition_ja"],
		Mastery.RANK_LABEL_JA[int(w["rank"])], _interval_label(int(w["box"]))]
	_box.add_child(ScreenBase.feedback_card(verdict, detail, entry["english"] if Progress.show_english() else "",
		UITheme.CORRECT_TINT if correct else UITheme.INCORRECT_TINT, UITheme.CORRECT if correct else UITheme.INCORRECT))
	var next := UITheme.button("次へ")
	next.pressed.connect(func() -> void:
		_index += 1
		_show_next())
	_box.add_child(next)
	next.grab_focus()


func _interval_label(box: int) -> String:
	var h := Srs.interval_hours(box)
	if h <= 0.0:
		return "すぐ"
	if h < 24.0:
		return "%d{時間後|じかんご}" % int(h)
	return "%d{日後|にちご}" % int(h / 24.0)


func _show_empty() -> void:
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja("{今|いま}は{復習|ふくしゅう}する{言葉|ことば}がありません。", UITheme.SIZE_BODY_L))
	v.add_child(UITheme.ja("{辞書|じしょ}で{新|あたら}しい{言葉|ことば}を{開|ひら}くと、ここに{出|で}てきます。", UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
	if Progress.show_english():
		v.add_child(UITheme.en("Nothing is due. Open words in the dictionary and they will appear here."))
	var b := UITheme.button("辞書へ")
	b.pressed.connect(func() -> void: navigate.emit(&"dictionary"))
	v.add_child(b)


func _show_summary() -> void:
	Progress.save_game()
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja("{結果|けっか}", UITheme.SIZE_H2))
	v.add_child(UITheme.label("%d / %d" % [_correct, _queue.size()], UITheme.SIZE_DISPLAY))
	var remaining := Progress.due_count()
	v.add_child(UITheme.ja("{残|のこ}りの{復習|ふくしゅう}：%d" % remaining, UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
	var row := UITheme.hbox(12)
	v.add_child(row)
	if remaining > 0:
		var more := UITheme.button("続ける")
		more.pressed.connect(func() -> void: navigate.emit(&"review"))
		row.add_child(more)
	var home := UITheme.button("ホームへ", remaining == 0)
	home.pressed.connect(func() -> void: navigate.emit(&"dashboard"))
	row.add_child(home)
