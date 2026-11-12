extends ScreenBase
## 復習: the spaced-repetition queue (GDD §6.3–6.4). Each due word gets the question type for its
## weakest unlocked dimension; mode "reading" forces example-reading questions and mode "kanji"
## forces kanji readings (recommender). Recall at box ≥ 3 is typed (romaji or IME). A word that
## drops to box 0 comes back after at least five other items in the same session.

const REINSERT_GAP := 5
const MAX_RESHOWS := 2

var _queue: Array[String] = []
var _reshows: Dictionary = {}
var _index := 0
var _correct := 0
var _total := 0
var _box: VBoxContainer


func _ready() -> void:
	make_column(820)
	add_title("{復習|ふくしゅう}", "Review")
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	_queue = Progress.due_words(20)
	_show_next()


func _show_next() -> void:
	ScreenBase.clear(_box)
	set_options([])
	if _queue.is_empty() and _total == 0:
		_show_empty()
		return
	if _index >= _queue.size():
		_show_summary()
		return
	var entry := ContentDB.word(_queue[_index])
	if entry.is_empty():
		_index += 1
		_show_next()
		return
	var q := _question_for(entry)
	_box.add_child(UITheme.label("%d / %d" % [_index + 1, _queue.size()], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var head := UITheme.hbox(8)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(head)
	var prompt := UITheme.ja(q["prompt"], UITheme.SIZE_H1)
	prompt.show_ruby = not q.get("hide_ruby", false)
	prompt.alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(prompt)
	if q.has("audio") and not q.get("hide_ruby", false):
		head.add_child(ScreenBase.speak_button(q["audio"]))
	if Progress.show_explanations():
		var hint := UITheme.en(q["prompt_en"], UITheme.SIZE_LABEL)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hint)
	if q.get("typed", false):
		_typed_input(v, q)
	else:
		_choice_input(v, q)
	UITheme.animate_in(card)


func _choice_input(v: VBoxContainer, q: Dictionary) -> void:
	var grid := GridContainer.new()
	grid.columns = 1 if q["skill"] == &"reading" else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var buttons: Array = []
	for i in (q["options"] as Array).size():
		var b := TileButton.new(q["options"][i], UITheme.SIZE_BODY)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if grid.columns == 1:
			b.enable_wrap()
		b.pressed.connect(func() -> void:
			for c: TileButton in grid.get_children():
				c.disabled = true
			(grid.get_child(int(q["answer"])) as TileButton).set_state(UITheme.CORRECT_TINT, UITheme.CORRECT)
			if i != int(q["answer"]):
				b.set_state(UITheme.INCORRECT_TINT, UITheme.INCORRECT)
			_resolve(q, i == int(q["answer"])))
		grid.add_child(b)
		buttons.append(b)
	set_options(buttons)


func _typed_input(v: VBoxContainer, q: Dictionary) -> void:
	var row := UITheme.hbox(12)
	v.add_child(row)
	var input := LineEdit.new()
	input.placeholder_text = "ひらがなで（romaji → かな）"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size.y = 56
	input.text_changed.connect(func(t: String) -> void:
		var conv := Romaji.to_hiragana(t)
		if conv != t:
			input.text = conv
			input.caret_column = conv.length())
	row.add_child(input)
	var check := UITheme.button("確認")
	row.add_child(check)
	var submit := func() -> void:
		if check.disabled:
			return
		check.disabled = true
		input.editable = false
		var r := AnswerMatch.grade(input.text, q["typed_answers"])
		if not r["correct"] and r["hint_ja"] != "":
			v.add_child(UITheme.ja(r["hint_ja"], UITheme.SIZE_LABEL, UITheme.NEUTRAL))
		_resolve(q, r["correct"])
	check.pressed.connect(submit)
	input.text_submitted.connect(func(_t: String) -> void: submit.call())
	input.call_deferred("grab_focus")


## GDD §6.4: the dimension with the lowest counter among those unlocked for the rank.
func _question_for(entry: Dictionary) -> Dictionary:
	var w := Progress.word(entry["id"])
	var rank := int(w["rank"])
	var has_kanji := not ExamBuilder._no_kanji(entry["headword"])
	var mode := String(args.get("mode", ""))
	var kanji_pool := ContentDB.unlocked_items("vocab", Progress.stage).filter(func(e: Dictionary) -> bool: return not ExamBuilder._no_kanji(e["headword"]))
	var vocab := ContentDB.unlocked_items("vocab", Progress.stage)
	if mode == "kanji" and has_kanji:
		return ExamBuilder.kanji_reading_question(entry, kanji_pool)
	if mode == "reading":
		return ExamBuilder.example_reading_question(entry, vocab)
	var candidates: Array = [["rec", "recognition"]]
	if has_kanji:
		candidates.append(["rec", "kanji"])
	if rank >= Mastery.Rank.LEARNED or int(w["rec"]) >= 4:
		candidates.append(["rcl", "recall"])
	if rank >= Mastery.Rank.PROFICIENT or int(w["rcl"]) >= 4:
		candidates.append(["use", "usage"])
		candidates.append(["rec", "example"])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return int(w[a[0]]) < int(w[b[0]]))
	var lowest := int(w[candidates[0][0]])
	var ties := candidates.filter(func(c: Array) -> bool: return int(w[c[0]]) == lowest)
	var pick: Array = ties[randi() % ties.size()]
	match pick[1]:
		"kanji":
			return ExamBuilder.kanji_reading_question(entry, kanji_pool)
		"recall":
			var q := ExamBuilder.recall_question(entry, vocab)
			q["typed"] = int(w["box"]) >= 3
			return q
		"usage":
			var u := ExamBuilder.usage_question(entry, vocab)
			return u if not u.is_empty() else ExamBuilder.recall_question(entry, vocab)
		"example":
			return ExamBuilder.example_reading_question(entry, vocab)
	return ExamBuilder.recognition_question(entry, vocab)


func _resolve(q: Dictionary, correct: bool) -> void:
	set_options([])
	_total += 1
	var c := Srs.C_CORRECT if correct else Srs.C_WRONG
	var id: String = q["word_id"]
	Progress.record_word_answer(id, q["dimension"], c)
	Progress.record_sample(q["activity"], c)
	if correct:
		_correct += 1
		Progress.add_xp(Mastery.XP[&"review"])
	var entry := ContentDB.word(id)
	var w := Progress.word(id)
	Speech.speak(entry["reading"])
	# Box-0 words come back later in this session (GDD §6.3 "immediate" review).
	if int(w["box"]) == 0 and int(_reshows.get(id, 0)) < MAX_RESHOWS:
		_reshows[id] = int(_reshows.get(id, 0)) + 1
		_queue.insert(mini(_index + 1 + REINSERT_GAP, _queue.size()), id)
	var verdict := "○ {正解|せいかい}" if correct else "✕ {不正解|ふせいかい}"
	var detail := "%s（%s）— %s\n{習得度|しゅうとくど}：%s　{次|つぎ}の{復習|ふくしゅう}：%s" % [
		ExamBuilder.headword_markup(entry), entry["reading"], entry["definition_ja"],
		Mastery.RANK_LABEL_JA[int(w["rank"])], _interval_label(int(w["box"]))]
	_box.add_child(ScreenBase.feedback_card(verdict, detail, entry["english"] if Progress.show_english() else "",
		UITheme.CORRECT_TINT if correct else UITheme.INCORRECT_TINT, UITheme.CORRECT if correct else UITheme.INCORRECT))
	var next := UITheme.button("次へ")
	next.pressed.connect(func() -> void:
		_index += 1
		_show_next())
	_box.add_child(next)
	set_primary(next)


func _interval_label(box: int) -> String:
	var h := Srs.interval_hours(box)
	if h <= 0.0:
		return "このあとすぐ"
	if h < 24.0:
		return "%d{時間後|じかんご}" % int(h)
	return "%d{日後|にちご}" % int(h / 24.0)


func _show_empty() -> void:
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja("{今|いま}は{復習|ふくしゅう}する{言葉|ことば}がありません。", UITheme.SIZE_BODY_L))
	v.add_child(UITheme.ja("{辞書|じしょ}で「{学習|がくしゅう}する」を{押|お}すと、ここに{出|で}てきます。", UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
	if Progress.show_english():
		v.add_child(UITheme.en("Nothing is due. Press 学習する on dictionary entries to add words."))
	var b := UITheme.button("辞書へ")
	b.pressed.connect(func() -> void: go(&"dictionary"))
	v.add_child(b)
	set_primary(b)


func _show_summary() -> void:
	Progress.save_game()
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja("{結果|けっか}", UITheme.SIZE_H2))
	v.add_child(UITheme.label("%d / %d" % [_correct, _total], UITheme.SIZE_DISPLAY))
	var remaining := Progress.due_count()
	v.add_child(UITheme.ja("{残|のこ}りの{復習|ふくしゅう}：%d" % remaining, UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
	var row := UITheme.hbox(12)
	v.add_child(row)
	if remaining > 0:
		var more := UITheme.button("続ける")
		more.pressed.connect(func() -> void: go(&"review", args))
		row.add_child(more)
		set_primary(more)
	var home := UITheme.button("ホームへ", remaining == 0)
	home.pressed.connect(func() -> void: go(&"dashboard"))
	row.add_child(home)
	if remaining == 0:
		set_primary(home)
	UITheme.animate_in(card)
