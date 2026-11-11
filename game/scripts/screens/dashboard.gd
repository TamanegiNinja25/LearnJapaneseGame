extends ScreenBase
## ホーム: stage, six skill bars, counters, the recommended next activity and settings.
## Two columns at desktop width (ART_BIBLE §2.7).

var _scores_box: VBoxContainer
var _rec_box: VBoxContainer


func _ready() -> void:
	make_column(1100)
	var header := UITheme.hbox(UITheme.GAP)
	column.add_child(header)
	var title := UITheme.vbox(4)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	title.add_child(UITheme.ja("{日本語能力|にほんごのうりょく}", UITheme.SIZE_H2, UITheme.TEXT_SECONDARY))
	title.add_child(UITheme.ja(Mastery.STAGE_LABEL_JA[Progress.stage], UITheme.SIZE_DISPLAY))
	header.add_child(_english_mode_picker())

	var cols := UITheme.hbox(UITheme.GAP_SECTION)
	column.add_child(cols)
	var left := UITheme.vbox(UITheme.GAP)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	cols.add_child(left)
	var right := UITheme.vbox(UITheme.GAP)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	# Skills card
	var skills_card := UITheme.card()
	left.add_child(skills_card)
	_scores_box = UITheme.vbox(12)
	skills_card.add_child(_scores_box)
	_render_scores()
	Progress.scores_changed.connect(func(_s: Dictionary) -> void: _render_scores())

	# Counters card
	left.add_child(_counters_card())

	# Recommendation card
	var rec_card := UITheme.card(UITheme.PRIMARY_TINT, UITheme.PRIMARY)
	right.add_child(rec_card)
	_rec_box = UITheme.vbox(12)
	rec_card.add_child(_rec_box)
	_render_recommendation()

	right.add_child(_exam_card())
	right.add_child(_credits_card())


func _render_scores() -> void:
	ScreenBase.clear(_scores_box)
	_scores_box.add_child(UITheme.ja("スキル", UITheme.SIZE_H2))
	var scores := Progress.scores()
	var gate: Dictionary = Mastery.GATES.get(Progress.stage, {})
	for skill in Mastery.SKILLS:
		var row := UITheme.hbox(12)
		_scores_box.add_child(row)
		var name := UITheme.ja(Mastery.SKILL_LABEL_JA[skill], UITheme.SIZE_LABEL, UITheme.SKILL_INK[skill])
		name.autowrap = false
		name.custom_minimum_size.x = 120
		name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(name)
		var bar_box := UITheme.vbox(2)
		bar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar_box)
		bar_box.add_child(UITheme.progress_bar(UITheme.SKILL_FILL[skill], float(scores[skill])))
		var pct := UITheme.label("%d%%" % int(scores[skill]), UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY)
		pct.size_flags_horizontal = Control.SIZE_SHRINK_END
		pct.custom_minimum_size.x = 60
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct)
		var target := UITheme.label("/ %s" % (str(gate[skill]) if gate.has(skill) else "–"), UITheme.SIZE_CAPTION, UITheme.TEXT_DISABLED)
		target.size_flags_horizontal = Control.SIZE_SHRINK_END
		target.custom_minimum_size.x = 60
		row.add_child(target)


func _counters_card() -> PanelContainer:
	var card := UITheme.card()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	card.add_child(grid)
	var rows := [
		["{学習済|がくしゅうず}みの{言葉|ことば}", str(Progress.count_words_at_least(Mastery.Rank.LEARNED))],
		["{発見|はっけん}した{言葉|ことば}", str(Progress.count_words_at_least(Mastery.Rank.DISCOVERED))],
		["{今日|きょう}の{復習|ふくしゅう}", str(Progress.due_count())],
		["{会話|かいわ}の{完了|かんりょう}", str(_sum(Progress.scenarios, "completions"))],
		["{作|つく}った{文|ぶん}", str(_sum(Progress.prompts, "attempts"))],
		["{勉強|べんきょう}した{日|ひ}", "%d" % Progress.days_studied()],
	]
	for r in rows:
		grid.add_child(UITheme.ja(r[0], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
		var v := UITheme.label(r[1], UITheme.SIZE_H2)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(v)
	return card


func _render_recommendation() -> void:
	ScreenBase.clear(_rec_box)
	var target := Recommender.recommend(Progress.kana_mastery(), Progress.due_count(), Progress.exam_unlocked(),
		Progress.scores(), Progress.stage, Progress.recommend_history)
	Progress.recommend_history.append(target)
	if Progress.recommend_history.size() > 3:
		Progress.recommend_history.pop_front()
	_rec_box.add_child(UITheme.ja("{次|つぎ}にやること", UITheme.SIZE_H2, UITheme.PRIMARY))
	_rec_box.add_child(UITheme.ja(Recommender.REASON[target], UITheme.SIZE_BODY))
	var go := TileButton.new(_screen_label(target), UITheme.SIZE_LABEL)
	go.set_state(UITheme.PRIMARY, UITheme.PRIMARY)
	go.label.color = UITheme.ON_PRIMARY
	go.label.ruby_color = UITheme.ON_PRIMARY
	go.pressed.connect(func() -> void: navigate.emit(target))
	_rec_box.add_child(go)


func _exam_card() -> PanelContainer:
	var card := UITheme.card()
	var v := UITheme.vbox(8)
	card.add_child(v)
	v.add_child(UITheme.ja("{昇級試験|しょうきゅうしけん}", UITheme.SIZE_H2))
	var status := Progress.gate_status()
	if Progress.exam_unlocked():
		v.add_child(UITheme.ja("{受験|じゅけん}できます。{全|すべ}ての{項目|こうもく}で{基準|きじゅん}を{超|こ}えると{合格|ごうかく}です。", UITheme.SIZE_BODY))
	elif Progress.now() < Progress.cooldown_until:
		var hours := ceili(float(Progress.cooldown_until - Progress.now()) / 3600.0)
		v.add_child(UITheme.ja("{次|つぎ}の{受験|じゅけん}まで %d {時間|じかん}" % hours, UITheme.SIZE_BODY, UITheme.WARNING))
	else:
		var names: Array = []
		for skill: StringName in status["failing"]:
			names.append(Furigana.plain(Mastery.SKILL_LABEL_JA[skill]))
		v.add_child(UITheme.ja("{基準|きじゅん}まであと{少|すこ}し：%s" % "、".join(names), UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
	if Progress.show_explanations():
		v.add_child(UITheme.en("Unlocks when every skill is within 15 points of its threshold."))
	return card


func _credits_card() -> PanelContainer:
	var card := UITheme.card(UITheme.SURFACE_ALT, UITheme.BORDER)
	var v := UITheme.vbox(4)
	card.add_child(v)
	v.add_child(UITheme.label("Dictionary data: JMdict © EDRDG, CC BY-SA 4.0", UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	v.add_child(UITheme.label("Open source under MIT · github.com/TamanegiNinja25/LearnJapaneseGame", UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	return card


func _english_mode_picker() -> OptionButton:
	var ob := OptionButton.new()
	ob.tooltip_text = "English assistance"
	for item in ["日本語のみ", "日本語＋説明", "日本語＋訳", "バイリンガル"]:
		ob.add_item(item)
	ob.selected = Progress.english_mode
	ob.item_selected.connect(func(i: int) -> void:
		Progress.set_english_mode(i)
		navigate.emit(&"dashboard"))
	return ob


func _screen_label(target: StringName) -> String:
	match target:
		&"kana": return "かなトレーナー"
		&"review": return "{復習|ふくしゅう}する"
		&"dictionary": return "{辞書|じしょ}を{開|ひら}く"
		&"sentences": return "{文|ぶん}を{作|つく}る"
		&"conversation": return "{会話|かいわ}する"
		&"assessment": return "{試験|しけん}を{受|う}ける"
	return String(target)


static func _sum(d: Dictionary, key: String) -> int:
	var n := 0
	for id in d:
		n += int(d[id].get(key, 0))
	return n
