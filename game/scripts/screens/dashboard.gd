extends ScreenBase
## ホーム: stage, six skill bars with thresholds, counters, recommended next activity, daily
## quests and the gate-exam status. Two columns at desktop width (ART_BIBLE §2.7).

var _scores_box: VBoxContainer


func _ready() -> void:
	Progress.touch_today()
	make_column(1000)
	var header := UITheme.hbox(UITheme.GAP)
	column.add_child(header)
	var title := UITheme.vbox(4)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	title.add_child(ScreenBase.ja_en("{日本語能力|にほんごのうりょく}", "Your Japanese level", UITheme.SIZE_H2, UITheme.TEXT_SECONDARY))
	title.add_child(UITheme.ja(Mastery.STAGE_LABEL_JA[Progress.stage], UITheme.SIZE_DISPLAY))
	var streak := UITheme.vbox(0)
	streak.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(streak)
	var days := UITheme.label("%d" % Progress.streak_days(), UITheme.SIZE_DISPLAY, UITheme.PRIMARY)
	days.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	streak.add_child(days)
	var days_lbl := UITheme.ja("{連続日数|れんぞくにっすう}", UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY)
	days_lbl.autowrap = false
	streak.add_child(days_lbl)
	if Progress.show_english():
		var days_en := UITheme.en("day streak", UITheme.SIZE_LABEL)
		days_en.autowrap_mode = TextServer.AUTOWRAP_OFF
		days_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		streak.add_child(days_en)

	var cols := UITheme.hbox(UITheme.GAP_SECTION)
	column.add_child(cols)
	var left := UITheme.vbox(UITheme.GAP)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	cols.add_child(left)
	var right := UITheme.vbox(UITheme.GAP)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	var skills_card := UITheme.card()
	left.add_child(skills_card)
	_scores_box = UITheme.vbox(10)
	skills_card.add_child(_scores_box)
	_render_scores()
	left.add_child(_counters_card())

	right.add_child(_recommendation_card())
	right.add_child(_quests_card())
	right.add_child(_exam_card())


func _render_scores() -> void:
	ScreenBase.clear(_scores_box)
	_scores_box.add_child(ScreenBase.ja_en("スキル", "Skills", UITheme.SIZE_H2))
	var scores := Progress.scores()
	var gate: Dictionary = Mastery.GATES.get(Progress.stage, {})
	for skill in Mastery.SKILLS:
		var row := UITheme.hbox(12)
		_scores_box.add_child(row)
		var name := UITheme.ja(Mastery.SKILL_LABEL_JA[skill], UITheme.SIZE_LABEL, UITheme.SKILL_INK[skill])
		name.autowrap = false
		name.custom_minimum_size.x = 64
		name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if Progress.show_english():
			var stack := UITheme.vbox(0)
			stack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			stack.custom_minimum_size.x = 120
			stack.add_child(name)
			var en := UITheme.label(Mastery.SKILL_LABEL_EN[skill], UITheme.SIZE_EN_SUB, UITheme.TEXT_SECONDARY)
			en.autowrap_mode = TextServer.AUTOWRAP_OFF
			stack.add_child(en)
			row.add_child(stack)
		else:
			row.add_child(name)
		row.add_child(UITheme.progress_bar(UITheme.SKILL_FILL[skill], float(scores[skill])))
		var pct := UITheme.label("%d%%" % int(scores[skill]), UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY)
		pct.size_flags_horizontal = Control.SIZE_SHRINK_END
		pct.custom_minimum_size.x = 56
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct)
		var target_text := "/ %d" % int(gate[skill]) if gate.has(skill) else "{任意|にんい}"
		var target := UITheme.ja(target_text, UITheme.SIZE_CAPTION, UITheme.TEXT_DISABLED)
		target.autowrap = false
		target.custom_minimum_size.x = 56
		target.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(target)


func _counters_card() -> PanelContainer:
	var card := UITheme.card()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	card.add_child(grid)
	var rows := [
		["{学習済|がくしゅうず}みの{言葉|ことば}", str(Progress.count_words_at_least(Mastery.Rank.LEARNED)), "Words learned"],
		["{復習中|ふくしゅうちゅう}の{言葉|ことば}", str(_count_srs()), "Words in review"],
		["{今日|きょう}の{復習|ふくしゅう}", str(Progress.due_count()), "Reviews due today"],
		["{今日|きょう}{学習|がくしゅう}できる{新語|しんご}", str(Progress.budget_left()), "New words left today"],
		["{会話|かいわ}の{完了|かんりょう}", str(_sum(Progress.scenarios, "completions")), "Conversations done"],
		["{勉強|べんきょう}した{日|ひ}", str(Progress.days_studied()), "Days studied"],
	]
	for r in rows:
		grid.add_child(ScreenBase.ja_en(r[0], r[2], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
		var v := UITheme.label(r[1], UITheme.SIZE_H2)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(v)
	return card


func _recommendation_card() -> PanelContainer:
	var weakest := Progress.weakest_grammar()
	var rec := Recommender.recommend({
		"kana_mastery": Progress.kana_mastery(), "due_count": Progress.due_count(),
		"exam_unlocked": Progress.exam_unlocked(), "scores": Progress.scores(), "stage": Progress.stage,
		"history": Progress.recommend_history, "daily_done": Progress.daily.get("assessment_done", false),
		"daily_score": int(Progress.daily.get("assessment_score", 0)),
		"familiar_words": Progress.count_words_at_least(Mastery.Rank.FAMILIAR),
		"budget_left": Progress.budget_left(), "weakest_grammar_correct": int(weakest["correct"]),
		"tts": Speech.available(),
	})
	Progress.recommend_history.append(rec["screen"])
	if Progress.recommend_history.size() > 3:
		Progress.recommend_history.pop_front()
	var card := UITheme.card(UITheme.PRIMARY_TINT, UITheme.PRIMARY)
	var v := UITheme.vbox(12)
	card.add_child(v)
	v.add_child(ScreenBase.ja_en("{次|つぎ}にやること", "Up next", UITheme.SIZE_H2, UITheme.PRIMARY))
	v.add_child(UITheme.ja(rec["reason"], UITheme.SIZE_BODY))
	var go_btn := TileButton.new(_screen_label(rec["screen"], rec["mode"]), UITheme.SIZE_LABEL,
		_screen_en(rec["screen"], rec["mode"]) if Progress.show_english() else "")
	go_btn.set_state(UITheme.PRIMARY, UITheme.PRIMARY)
	go_btn.set_text_color(UITheme.ON_PRIMARY)
	go_btn.pressed.connect(func() -> void: go(rec["screen"], {"mode": rec["mode"]}))
	v.add_child(go_btn)
	set_primary(go_btn)
	return card


func _quests_card() -> PanelContainer:
	var card := UITheme.card()
	var v := UITheme.vbox(8)
	card.add_child(v)
	v.add_child(ScreenBase.ja_en("{今日|きょう}のクエスト", "Today's quests", UITheme.SIZE_H2))
	for q in Quests.LIST:
		if q["id"] == "listening" and not Speech.available():
			continue
		var row := UITheme.hbox(10)
		v.add_child(row)
		var done := Progress.quest_paid(q["id"])
		var n := mini(Progress.daily_counter(q["counter"]), int(q["target"]))
		var mark := UITheme.label("○" if done else "・", UITheme.SIZE_LABEL, UITheme.CORRECT if done else UITheme.TEXT_DISABLED)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mark.custom_minimum_size.x = 24
		row.add_child(mark)
		var lbl := ScreenBase.ja_en(q["ja"], q["en"], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY if done else UITheme.TEXT_PRIMARY)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var count := UITheme.label("%d/%d · %d XP" % [n, int(q["target"]), int(q["xp"])], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(count)
	return card


func _exam_card() -> PanelContainer:
	var card := UITheme.card()
	var v := UITheme.vbox(8)
	card.add_child(v)
	v.add_child(ScreenBase.ja_en("{昇級試験|しょうきゅうしけん}", "Stage exam", UITheme.SIZE_H2))
	if Progress.stage == &"MASTERY" and "MASTERY" in Progress.cleared_stages:
		v.add_child(UITheme.ja("{完全習得|かんぜんしゅうとく}おめでとうございます！", UITheme.SIZE_BODY, UITheme.CORRECT))
		return card
	if Progress.exam_unlocked():
		v.add_child(UITheme.ja("{受験|じゅけん}できます。{全|すべ}ての{項目|こうもく}で{基準|きじゅん}を{超|こ}えると{合格|ごうかく}です。", UITheme.SIZE_BODY))
		var b := UITheme.button("試験を受ける")
		b.pressed.connect(func() -> void: go(&"assessment", {"mode": "gate"}))
		v.add_child(b)
	elif Progress.on_cooldown():
		var hours := ceili(float(Progress.cooldown_until - Progress.now()) / 3600.0)
		v.add_child(UITheme.ja("{次|つぎ}の{受験|じゅけん}まで %d {時間|じかん}" % hours, UITheme.SIZE_BODY, UITheme.WARNING))
	else:
		var names: Array = []
		for skill: StringName in Progress.gate_status()["failing"]:
			names.append(Furigana.plain(Mastery.SKILL_LABEL_JA[skill]))
		v.add_child(UITheme.ja("あと{少|すこ}し：%s" % "、".join(names), UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
		if Progress.show_explanations():
			v.add_child(UITheme.en("Unlocks when every required skill is within 15 points of its threshold."))
	return card


func _screen_label(target: StringName, mode: String) -> String:
	if target == &"assessment":
		return "{毎日|まいにち}の{確認|かくにん}テスト" if mode == "daily" else "{試験|しけん}を{受|う}ける"
	match target:
		&"kana": return "かなトレーナー"
		&"review": return "{復習|ふくしゅう}する"
		&"dictionary": return "{辞書|じしょ}で{新|あたら}しい{言葉|ことば}"
		&"sentences": return "{文|ぶん}を{作|つく}る"
		&"grammar": return "{文法|ぶんぽう}レッスン"
		&"conversation": return "{会話|かいわ}する"
		&"kanji": return "{漢字|かんじ}を{学|まな}ぶ"
		&"listening": return "{聴解|ちょうかい}の{練習|れんしゅう}"
	return String(target)


func _screen_en(target: StringName, mode: String) -> String:
	if target == &"assessment":
		return "Daily check" if mode == "daily" else "Take the exam"
	return {&"kana": "Kana trainer", &"review": "Review", &"dictionary": "New words in the dictionary",
		&"sentences": "Build sentences", &"grammar": "Grammar lesson", &"conversation": "Conversation",
		&"kanji": "Learn kanji", &"listening": "Listening practice"}.get(target, "")


func _count_srs() -> int:
	var n := 0
	for id: String in Progress.words:
		if Progress.words[id].get("srs", false):
			n += 1
	return n


static func _sum(d: Dictionary, key: String) -> int:
	var n := 0
	for id in d:
		n += int(d[id].get(key, 0))
	return n
