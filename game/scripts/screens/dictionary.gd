extends ScreenBase
## 辞書: searchable word list (unlocked stages, filter by level) and the entry card (concept §5).
## Opening an entry discovers the word; 学習する adds it to reviews within the daily budget.

var _list: ItemList
var _entry_box: VBoxContainer
var _results: Array[Dictionary] = []
var _level := ""   # "" = all unlocked stages
var _query := ""


func _ready() -> void:
	var root := UITheme.hbox(UITheme.GAP_SECTION)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 32
	root.offset_right = -32
	root.offset_top = 24
	root.offset_bottom = -24
	add_child(root)

	var left := UITheme.vbox(12)
	left.custom_minimum_size.x = 340
	root.add_child(left)
	left.add_child(UITheme.ja("{辞書|じしょ}", UITheme.SIZE_H1))
	var search := LineEdit.new()
	search.placeholder_text = "さがす / search (romaji ok)"
	search.text = String(args.get("query", ""))
	_query = search.text
	search.text_changed.connect(func(t: String) -> void:
		_query = t
		_refresh_list())
	left.add_child(search)
	var levels := OptionButton.new()
	levels.add_item("すべて")
	var unlocked: Array[StringName] = []
	for s: StringName in Mastery.STAGES:
		if not ContentDB.stage_items("vocab", s).is_empty():
			unlocked.append(s)
		if s == Progress.stage:
			break
	for s in unlocked:
		levels.add_item(String(s))
	levels.item_selected.connect(func(i: int) -> void:
		_level = "" if i == 0 else levels.get_item_text(i)
		_refresh_list())
	left.add_child(levels)
	var budget := UITheme.ja("{今日|きょう}{学習|がくしゅう}できる{新語|しんご}：%d" % Progress.budget_left(), UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY)
	left.add_child(budget)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_selected)
	left.add_child(_list)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_entry_box = UITheme.vbox(UITheme.GAP)
	_entry_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_entry_box)

	_refresh_list()
	var start := 0
	if args.has("word_id"):
		for i in _results.size():
			if _results[i]["id"] == args["word_id"]:
				start = i
	elif not _results.is_empty():
		# Prefer the first word not yet studied (今日の単語).
		for i in _results.size():
			if not Progress.in_srs(_results[i]["id"]):
				start = i
				break
	if not _results.is_empty():
		_list.select(start)
		_list.ensure_current_is_visible()
		_on_selected(start)
	_list.call_deferred("grab_focus")


func _pool() -> Array:
	var pool := ContentDB.unlocked_items("vocab", Progress.stage)
	if _level != "":
		pool = pool.filter(func(e: Dictionary) -> bool: return e["level"] == _level)
	return pool


func _refresh_list() -> void:
	var pool := _pool()
	_results = ContentDB.search_vocab(_query, pool) if not pool.is_empty() else []
	_list.clear()
	for e in _results:
		var rank := Progress.rank_of(e["id"])
		var marker := "●" if rank >= Mastery.Rank.LEARNED else ("◐" if Progress.in_srs(e["id"]) else ("・" if rank > Mastery.Rank.UNSEEN else "○"))
		var rd: String = "　" + e["reading"] if e["headword"] != e["reading"] else ""
		_list.add_item("%s %s%s" % [marker, e["headword"], rd])


func _on_selected(index: int) -> void:
	if index >= 0 and index < _results.size():
		show_entry(_results[index])


func show_entry(entry: Dictionary) -> void:
	Progress.discover_word(entry["id"])
	ScreenBase.clear(_entry_box)
	var card := UITheme.card()
	_entry_box.add_child(card)
	var v := UITheme.vbox(12)
	card.add_child(v)

	var head := UITheme.hbox(12)
	v.add_child(head)
	var hw := UITheme.ja(ExamBuilder.headword_markup(entry), UITheme.SIZE_DISPLAY)
	hw.autowrap = false
	head.add_child(hw)
	head.add_child(UITheme.hspacer())
	head.add_child(ScreenBase.speak_button(entry["reading"]))

	v.add_child(UITheme.ja("%s · %s · %s" % [entry["reading"], entry["level"], _markup_category(entry)], UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	var rank := Progress.rank_of(entry["id"])
	var status := UITheme.hbox(12)
	v.add_child(status)
	status.add_child(UITheme.ja("{習得度|しゅうとくど}：%s" % Mastery.RANK_LABEL_JA[rank], UITheme.SIZE_LABEL, UITheme.SKILL_INK[&"vocab"]))
	if Progress.in_srs(entry["id"]):
		status.add_child(UITheme.ja("{復習中|ふくしゅうちゅう}", UITheme.SIZE_LABEL, UITheme.CORRECT))
	else:
		var study := TileButton.new("{学習|がくしゅう}する", UITheme.SIZE_LABEL)
		study.set_state(UITheme.PRIMARY, UITheme.PRIMARY)
		study.set_text_color(UITheme.ON_PRIMARY)
		study.size_flags_horizontal = Control.SIZE_SHRINK_END
		study.pressed.connect(func() -> void:
			if Progress.study_word(entry["id"]):
				_refresh_list()
				show_entry(entry)
			else:
				_entry_box.add_child(ScreenBase.feedback_card("{今日|きょう}はここまで",
					"{今日|きょう}の{新|あたら}しい{言葉|ことば}はもう{十分|じゅうぶん}です。まず{復習|ふくしゅう}しましょう。",
					"Today's new-word budget is used up. Review first.", UITheme.NEUTRAL_TINT, UITheme.NEUTRAL)))
		status.add_child(study)
		set_primary(study)

	v.add_child(UITheme.spacer(4))
	v.add_child(UITheme.ja("{日本語|にほんご}の{意味|いみ}", UITheme.SIZE_H2))
	v.add_child(UITheme.ja(entry["definition_ja"], UITheme.SIZE_BODY_L))
	if Progress.show_explanations():
		v.add_child(UITheme.en("English: " + entry["english"], UITheme.SIZE_BODY_L))

	v.add_child(UITheme.spacer(4))
	v.add_child(UITheme.ja("{例文|れいぶん}", UITheme.SIZE_H2))
	for ex in entry["examples"]:
		var line := UITheme.hbox(8)
		v.add_child(line)
		line.add_child(UITheme.ja(ex["ja"], UITheme.SIZE_BODY_L))
		line.add_child(ScreenBase.speak_button(ex["ja"]))
		if Progress.show_english():
			v.add_child(UITheme.en(ex["en"], UITheme.SIZE_BODY_L))

	var kanji_chars: Array = entry.get("kanji", [])
	if not kanji_chars.is_empty():
		v.add_child(UITheme.spacer(4))
		v.add_child(UITheme.ja("{漢字|かんじ}", UITheme.SIZE_H2))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		v.add_child(flow)
		for ch in kanji_chars:
			var b := TileButton.new(ch, UITheme.SIZE_H2)
			b.disabled = ContentDB.kanji_info(ch).is_empty()
			b.pressed.connect(func() -> void: go(&"kanji", {"kanji": ch}))
			flow.add_child(b)

	var related: Array = entry["related"]
	if not related.is_empty():
		v.add_child(UITheme.spacer(4))
		v.add_child(UITheme.ja("{関連語|かんれんご}", UITheme.SIZE_H2))
		var flow2 := HFlowContainer.new()
		flow2.add_theme_constant_override("h_separation", 8)
		flow2.add_theme_constant_override("v_separation", 8)
		v.add_child(flow2)
		for headword in related:
			var target := ContentDB.word_by_headword(headword)
			var b := TileButton.new(ExamBuilder.headword_markup(target) if not target.is_empty() else _safe(headword), UITheme.SIZE_LABEL)
			if target.is_empty():
				b.disabled = true
			else:
				b.pressed.connect(func() -> void:
					var i := _results.find(target)
					if i >= 0:
						_list.select(i)
						_list.ensure_current_is_visible()
					show_entry(target))
			flow2.add_child(b)

	v.add_child(UITheme.spacer(4))
	v.add_child(UITheme.label("Source: " + entry["source"], UITheme.SIZE_CAPTION, UITheme.TEXT_DISABLED))
	UITheme.animate_in(card)


## Related headwords not in the dictionary are shown as plain text; drop kanji-only ones to the
## reading-less form so no kanji is drawn without ruby.
func _safe(headword: String) -> String:
	return headword if ExamBuilder._no_kanji(headword) else "…"


func _markup_category(entry: Dictionary) -> String:
	match entry["category"]:
		"noun": return "{名詞|めいし}"
		"pronoun": return "{代名詞|だいめいし}"
		"verb-u": return "{動詞|どうし}（{五段|ごだん}）"
		"verb-ru": return "{動詞|どうし}（{一段|いちだん}）"
		"verb-irregular": return "{動詞|どうし}（{不規則|ふきそく}）"
		"adj-i": return "い{形容詞|けいようし}"
		"adj-na": return "な{形容詞|けいようし}"
		"adverb": return "{副詞|ふくし}"
		"expression": return "{表現|ひょうげん}"
		"conjunction": return "{接続詞|せつぞくし}"
		"counter": return "{助数詞|じょすうし}"
		"particle": return "{助詞|じょし}"
		"interjection": return "{感動詞|かんどうし}"
		"prefix": return "{接頭辞|せっとうじ}"
		"suffix": return "{接尾辞|せつびじ}"
	return entry["category"]
