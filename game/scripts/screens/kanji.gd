extends ScreenBase
## 漢字: the current stage's kanji grid (coloured by coverage) and a detail card with on/kun
## readings, meanings, stroke count and the words that use it. "Practise" starts a review
## session that forces kanji-reading questions.

var _detail: VBoxContainer


func _ready() -> void:
	make_column(1000)
	add_title("{漢字|かんじ}　%s" % String(Progress.stage), "Kanji")
	var chars := ContentDB.stage_items("kanji", Progress.stage)
	if chars.is_empty():
		chars = ContentDB.stage_items("kanji", &"N1")
	var learned := _learned_chars()
	var covered := 0
	for k in chars:
		if learned.has(k["kanji"]):
			covered += 1
	var info := UITheme.hbox(12)
	column.add_child(info)
	info.add_child(UITheme.ja("{覚|おぼ}えた{漢字|かんじ}：%d / %d" % [covered, chars.size()], UITheme.SIZE_LABEL, UITheme.SKILL_INK[&"kanji"]))
	var practise := UITheme.button("読み方の練習", false)
	practise.size_flags_horizontal = Control.SIZE_SHRINK_END
	practise.pressed.connect(func() -> void: go(&"review", {"mode": "kanji"}))
	info.add_child(practise)
	_detail = UITheme.vbox(UITheme.GAP)
	column.add_child(_detail)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	var first: Dictionary = {}
	for k in chars:
		var b := Button.new()
		b.text = k["kanji"]
		b.custom_minimum_size = Vector2(64, 64)
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_override("font", UITheme.font(500))
		b.add_theme_font_size_override("font_size", 32)
		if learned.has(k["kanji"]):
			UITheme.set_tile(b, UITheme.CORRECT_TINT, UITheme.CORRECT)
		elif not (k["words"] as Array).is_empty():
			UITheme.set_tile(b)
		else:
			UITheme.set_tile(b, UITheme.SURFACE_ALT, UITheme.BORDER)
		b.pressed.connect(_show.bind(k))
		grid.add_child(b)
		if args.get("kanji", "") == k["kanji"]:
			first = k
	if first.is_empty() and not chars.is_empty():
		first = chars[0]
	if args.has("kanji") and first.get("kanji", "") != args["kanji"]:
		var direct := ContentDB.kanji_info(args["kanji"])
		if not direct.is_empty():
			first = direct
	if not first.is_empty():
		_show(first)


func _learned_chars() -> Dictionary:
	var out := {}
	for id: String in Progress.words:
		if int(Progress.words[id]["rank"]) >= Mastery.Rank.LEARNED:
			for ch in ContentDB.word(id).get("kanji", []):
				out[ch] = true
	return out


func _show(k: Dictionary) -> void:
	ScreenBase.clear(_detail)
	var card := UITheme.card()
	_detail.add_child(card)
	var row := UITheme.hbox(UITheme.GAP_SECTION)
	card.add_child(row)
	var big := UITheme.label(k["kanji"], 112)
	big.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	big.custom_minimum_size.x = 140
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(big)
	var v := UITheme.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UITheme.ja("{音読|おんよ}み：%s" % "、".join(k["on"]), UITheme.SIZE_BODY))
	v.add_child(UITheme.ja("{訓読|くんよ}み：%s" % "、".join(k["kun"]), UITheme.SIZE_BODY))
	v.add_child(UITheme.ja("{画数|かくすう}：%d　レベル：%s" % [int(k["strokes"]), k.get("level", "")], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	if Progress.show_explanations():
		v.add_child(UITheme.en("Meaning: " + ", ".join(k["meanings"])))
	var words: Array = k["words"]
	if not words.is_empty():
		v.add_child(UITheme.ja("この{漢字|かんじ}を{使|つか}う{言葉|ことば}", UITheme.SIZE_LABEL))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		v.add_child(flow)
		for id in words:
			var w := ContentDB.word(id)
			if w.is_empty():
				continue
			var b := TileButton.new(ExamBuilder.headword_markup(w), UITheme.SIZE_LABEL)
			if Progress.rank_of(id) >= Mastery.Rank.LEARNED:
				b.set_state(UITheme.CORRECT_TINT, UITheme.CORRECT)
			b.pressed.connect(func() -> void: go(&"dictionary", {"word_id": id}))
			flow.add_child(b)
	else:
		v.add_child(UITheme.ja("まだこの{漢字|かんじ}を{使|つか}う{言葉|ことば}はありません。", UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	UITheme.animate_in(card)
