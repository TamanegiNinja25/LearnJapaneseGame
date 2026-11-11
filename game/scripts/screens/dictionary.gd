extends ScreenBase
## 辞書: searchable word list on the left, the entry card on the right (concept §5 template).
## Opening an entry discovers the word, which schedules its first review immediately.

var _list: ItemList
var _entry_box: VBoxContainer
var _results: Array[Dictionary] = []


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
	search.placeholder_text = "さがす / search"
	search.text_changed.connect(_refresh_list)
	left.add_child(search)
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

	_refresh_list("")
	if not _results.is_empty():
		_list.select(0)
		_on_selected(0)


func _refresh_list(query: String) -> void:
	_results = ContentDB.search_vocab(query)
	_list.clear()
	for entry in _results:
		var rank := Progress.rank_of(entry["id"])
		var marker := "●" if rank >= Mastery.Rank.LEARNED else ("◐" if rank > Mastery.Rank.UNSEEN else "○")
		_list.add_item("%s %s　%s" % [marker, entry["headword"], entry["reading"] if entry["headword"] != entry["reading"] else ""])


func _on_selected(index: int) -> void:
	if index < 0 or index >= _results.size():
		return
	show_entry(_results[index])


func show_entry(entry: Dictionary) -> void:
	Progress.discover_word(entry["id"])
	ScreenBase.clear(_entry_box)
	var card := UITheme.card()
	_entry_box.add_child(card)
	var v := UITheme.vbox(12)
	card.add_child(v)

	v.add_child(UITheme.ja(ExamBuilder.headword_markup(entry), UITheme.SIZE_DISPLAY))
	var meta := "%s · %s · %s" % [entry["reading"], entry["level"], entry["category_ja"]]
	v.add_child(UITheme.ja(_markup_category(entry), UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	if Progress.show_explanations():
		v.add_child(UITheme.en(meta, UITheme.SIZE_LABEL))

	var rank := Progress.rank_of(entry["id"])
	var chip := UITheme.ja("{習得度|しゅうとくど}：%s" % Mastery.RANK_LABEL_JA[rank], UITheme.SIZE_LABEL, UITheme.SKILL_INK[&"vocab"])
	v.add_child(chip)
	if Progress.show_explanations():
		v.add_child(UITheme.en(Mastery.RANK_LABEL_EN[rank], UITheme.SIZE_LABEL))

	v.add_child(UITheme.spacer(4))
	v.add_child(UITheme.ja("{日本語|にほんご}の{意味|いみ}", UITheme.SIZE_H2))
	v.add_child(UITheme.ja(entry["definition_ja"], UITheme.SIZE_BODY_L))
	if Progress.show_explanations():
		v.add_child(UITheme.en("English: " + entry["english"], UITheme.SIZE_BODY_L))

	v.add_child(UITheme.spacer(4))
	v.add_child(UITheme.ja("{例文|れいぶん}", UITheme.SIZE_H2))
	for ex in entry["examples"]:
		v.add_child(UITheme.ja(ex["ja"], UITheme.SIZE_BODY_L))
		if Progress.show_english():
			v.add_child(UITheme.en(ex["en"], UITheme.SIZE_BODY_L))

	var related: Array = entry["related"]
	if not related.is_empty():
		v.add_child(UITheme.spacer(4))
		v.add_child(UITheme.ja("{関連語|かんれんご}", UITheme.SIZE_H2))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		v.add_child(flow)
		for headword in related:
			var target := ContentDB.word_by_headword(headword)
			var b := TileButton.new(ExamBuilder.headword_markup(target) if not target.is_empty() else headword, UITheme.SIZE_LABEL)
			if target.is_empty():
				b.disabled = true
				b.tooltip_text = "Not in the N5 set yet"
			else:
				b.pressed.connect(func() -> void:
					var i := _results.find(target)
					if i >= 0:
						_list.select(i)
					show_entry(target))
			flow.add_child(b)

	v.add_child(UITheme.spacer(4))
	v.add_child(UITheme.label("Source: " + entry["source"], UITheme.SIZE_CAPTION, UITheme.TEXT_DISABLED))


func _markup_category(entry: Dictionary) -> String:
	match entry["category"]:
		"noun": return "{名詞|めいし}"
		"pronoun": return "{代名詞|だいめいし}"
		"verb-u": return "{動詞|どうし}（{五段|ごだん}）"
		"verb-ru": return "{動詞|どうし}（{一段|いちだん}）"
		"verb-irregular": return "{動詞|どうし}（{不規則|ふきそく}）"
		"adj-i": return "い{形容詞|けいようし}"
		"adj-na": return "な{形容詞|けいようし}"
		"expression": return "{表現|ひょうげん}"
		"adverb": return "{副詞|ふくし}"
	return entry["category_ja"]
