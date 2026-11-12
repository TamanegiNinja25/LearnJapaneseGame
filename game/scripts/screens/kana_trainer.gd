extends ScreenBase
## かなトレーナー: ten cards per round, one kana shown large, four romaji choices (keys 1–4).
## Kana with a short streak come first; both scripts are mixed; yōon appear once the core set
## is mostly known. A ▶ button speaks the kana when a Japanese voice is installed.

const ROUND_SIZE := 10

var _queue: Array[Dictionary] = []
var _index := 0
var _correct := 0
var _card_box: VBoxContainer


func _ready() -> void:
	make_column(720)
	add_title("かなトレーナー", "Kana trainer")
	_card_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_card_box)
	_start_round()


func _start_round() -> void:
	_queue.clear()
	_index = 0
	_correct = 0
	var include_yoon := Progress.kana_mastery() >= 0.6
	var pool: Array = []
	for table in ["hiragana", "katakana"]:
		for row in ContentDB.kana.get(table, []):
			if row["group"] == "yoon" and not include_yoon:
				continue
			var entry: Dictionary = row.duplicate()
			entry["table"] = table
			pool.append(entry)
	pool.shuffle()
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _streak(a["kana"]) < _streak(b["kana"]))
	var weak := pool.slice(0, ROUND_SIZE * 2)
	weak.shuffle()
	for i in mini(ROUND_SIZE, weak.size()):
		_queue.append(weak[i])
	_show_card()


func _streak(ch: String) -> int:
	return int(Progress.kana.get(ch, {}).get("streak", 0))


func _show_card() -> void:
	ScreenBase.clear(_card_box)
	if _index >= _queue.size():
		_show_summary()
		return
	var item := _queue[_index]
	_card_box.add_child(UITheme.label("%d / %d" % [_index + 1, _queue.size()], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	var card := UITheme.card()
	_card_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var big := UITheme.label(item["kana"], 120)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var meta := UITheme.hbox(8)
	meta.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(meta)
	var script_name := UITheme.label("ひらがな" if item["table"] == "hiragana" else "カタカナ", UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY)
	script_name.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	script_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	meta.add_child(script_name)
	meta.add_child(ScreenBase.speak_button(item["kana"]))

	var options: Array = [item["romaji"]]
	var same: Array = ContentDB.kana[item["table"]].filter(func(r: Dictionary) -> bool:
		return r["romaji"] != item["romaji"] and r["group"] == item["group"])
	same.shuffle()
	for r in same:
		if options.size() >= 4:
			break
		if r["romaji"] not in options:
			options.append(r["romaji"])
	options.shuffle()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var buttons: Array = []
	for i in options.size():
		var b := TileButton.new("%d  %s" % [i + 1, options[i]], UITheme.SIZE_BODY)
		b.set_meta("romaji", options[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_answer.bind(item, options[i], grid))
		grid.add_child(b)
		buttons.append(b)
	set_options(buttons)
	UITheme.animate_in(card)


func _answer(item: Dictionary, chosen: String, grid: GridContainer) -> void:
	var correct: bool = chosen == item["romaji"]
	Progress.record_kana(item["kana"], correct)
	Speech.speak(item["kana"])
	if correct:
		_correct += 1
	for b: TileButton in grid.get_children():
		b.disabled = true
		if b.get_meta("romaji") == item["romaji"]:
			b.set_state(UITheme.CORRECT_TINT, UITheme.CORRECT)
		elif b.get_meta("romaji") == chosen:
			b.set_state(UITheme.INCORRECT_TINT, UITheme.INCORRECT)
	var verdict := "○ {正解|せいかい}" if correct else "✕ {不正解|ふせいかい}"
	_card_box.add_child(ScreenBase.feedback_card(verdict, "%s ＝ %s" % [item["kana"], item["romaji"]], "",
		UITheme.CORRECT_TINT if correct else UITheme.INCORRECT_TINT, UITheme.CORRECT if correct else UITheme.INCORRECT))
	var next := UITheme.button("次へ")
	next.pressed.connect(func() -> void:
		_index += 1
		_show_card())
	_card_box.add_child(next)
	set_options([])
	set_primary(next)


func _show_summary() -> void:
	Progress.save_game()
	var card := UITheme.card()
	_card_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja("{結果|けっか}", UITheme.SIZE_H2))
	v.add_child(UITheme.label("%d / %d" % [_correct, _queue.size()], UITheme.SIZE_DISPLAY))
	v.add_child(UITheme.ja("かなの{習得率|しゅうとくりつ}：%d%%" % roundi(Progress.kana_mastery() * 100), UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
	var row := UITheme.hbox(12)
	v.add_child(row)
	var again := UITheme.button("もう一回")
	again.pressed.connect(_start_round)
	row.add_child(again)
	var home := UITheme.button("ホームへ", false)
	home.pressed.connect(func() -> void: go(&"dashboard"))
	row.add_child(home)
	set_primary(again)
	UITheme.animate_in(card)
