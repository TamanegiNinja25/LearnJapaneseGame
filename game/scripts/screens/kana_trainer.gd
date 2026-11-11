extends ScreenBase
## かなトレーナー: ten cards per round, one kana shown large, four romaji choices.
## Kana with a short streak are drawn more often; both scripts are mixed.

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
	var pool: Array = []
	for table in ["hiragana", "katakana"]:
		for row in ContentDB.kana.get(table, []):
			var entry: Dictionary = row.duplicate()
			entry["table"] = table
			pool.append(entry)
	# Weight: unknown kana (streak < 2) appear first; the rest fill the round.
	pool.shuffle()
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _streak(a["kana"]) < _streak(b["kana"]))
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
	var progress := UITheme.label("%d / %d" % [_index + 1, _queue.size()], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY)
	_card_box.add_child(progress)
	var card := UITheme.card()
	_card_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var big := UITheme.label(item["kana"], 120)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var script_name := UITheme.label("ひらがな" if item["table"] == "hiragana" else "カタカナ", UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY)
	script_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(script_name)

	var options: Array = [item["romaji"]]
	var same_table: Array = ContentDB.kana[item["table"]].filter(func(r: Dictionary) -> bool: return r["romaji"] != item["romaji"])
	same_table.shuffle()
	for i in 3:
		options.append(same_table[i]["romaji"])
	options.shuffle()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for opt in options:
		var b := UITheme.button(opt)
		UITheme.set_tile(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_answer.bind(item, opt, grid))
		grid.add_child(b)


func _answer(item: Dictionary, chosen: String, grid: GridContainer) -> void:
	var correct: bool = chosen == item["romaji"]
	Progress.record_kana(item["kana"], correct)
	if correct:
		_correct += 1
	for b in grid.get_children():
		b.disabled = true
		if b.text == item["romaji"]:
			UITheme.set_tile(b, UITheme.CORRECT_TINT, UITheme.CORRECT)
		elif b.text == chosen:
			UITheme.set_tile(b, UITheme.INCORRECT_TINT, UITheme.INCORRECT)
	var verdict := "○ {正解|せいかい}" if correct else "✕ {不正解|ふせいかい}"
	var tint := UITheme.CORRECT_TINT if correct else UITheme.INCORRECT_TINT
	var ink := UITheme.CORRECT if correct else UITheme.INCORRECT
	_card_box.add_child(ScreenBase.feedback_card(verdict, "%s ＝ %s" % [item["kana"], item["romaji"]], "", tint, ink))
	var next := UITheme.button("次へ")
	next.pressed.connect(func() -> void:
		_index += 1
		_show_card())
	_card_box.add_child(next)
	next.grab_focus()


func _show_summary() -> void:
	Progress.bump_stat("kana_rounds")
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
	home.pressed.connect(func() -> void: navigate.emit(&"dashboard"))
	row.add_child(home)
