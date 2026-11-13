extends ScreenBase
## 聴解: listening practice with the system Japanese voice (GDD §12 listening phase).
## Modes: 単語 (hear a word, pick it), 文 (hear an example sentence, pick its meaning, normal or
## slow speed), シャドーイング (hear a sentence, record yourself with the microphone, play both
## back and grade yourself). Automatic pronunciation scoring is not implemented: it needs a
## speech recogniser, which this offline build does not ship.

const ROUND := 8
const RECORD_BUS := "Record"

var _mode := ""
var _items: Array = []
var _index := 0
var _correct := 0
var _box: VBoxContainer
var _mic: AudioStreamPlayer
var _playback: AudioStreamPlayer
var _record: AudioEffectRecord
var _recording: AudioStreamWAV


func _ready() -> void:
	make_column(UITheme.COLUMN_WIDTH)
	add_title("{聴解|ちょうかい}", "Listening")
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	if not Speech.available():
		_no_voice()
		return
	_menu()


func _no_voice() -> void:
	var card := UITheme.card(UITheme.NEUTRAL_TINT, UITheme.NEUTRAL)
	_box.add_child(card)
	var v := UITheme.vbox(8)
	card.add_child(v)
	v.add_child(UITheme.ja("{日本語|にほんご}の{音声|おんせい}が{見|み}つかりません。", UITheme.SIZE_H2))
	v.add_child(UITheme.ja("パソコンに{日本語|にほんご}の{音声|おんせい}を{追加|ついか}してください。", UITheme.SIZE_BODY))
	v.add_child(UITheme.en("No Japanese text-to-speech voice is installed. On Windows: Settings › Time & language › Speech › Add voices › Japanese. On macOS: System Settings › Accessibility › Spoken Content › System voice › Manage voices. Then restart the game.", UITheme.SIZE_BODY))


func _menu() -> void:
	ScreenBase.clear(_box)
	var modes := [["words", "{単語|たんご}を{聞|き}く", "Hear a word, choose it"],
		["sentences", "{文|ぶん}を{聞|き}く", "Hear a sentence, choose its meaning"],
		["shadowing", "シャドーイング", "Listen, repeat, compare your recording"]]
	var buttons: Array = []
	for m in modes:
		var b := TileButton.new(m[1], UITheme.SIZE_BODY_L, m[2] if Progress.show_english() else "")
		b.tooltip_text = m[2]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_start.bind(m[0]))
		_box.add_child(b)
		buttons.append(b)
	set_options(buttons)


func _pool() -> Array:
	var known := ContentDB.unlocked_items("vocab", Progress.stage).filter(func(e: Dictionary) -> bool:
		return Progress.rank_of(e["id"]) > Mastery.Rank.UNSEEN)
	if known.size() < ROUND:
		known = ContentDB.stage_items("vocab", Progress.stage).duplicate()
	known.shuffle()
	return known


func _start(mode: String) -> void:
	_mode = mode
	_items = _pool().slice(0, ROUND)
	_index = 0
	_correct = 0
	if mode == "shadowing":
		_setup_recording()
	_show()


func _show() -> void:
	ScreenBase.clear(_box)
	set_options([])
	if _index >= _items.size():
		_finish()
		return
	var e: Dictionary = _items[_index]
	_box.add_child(UITheme.label("%d / %d" % [_index + 1, _items.size()], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	var text: String = e["reading"] if _mode == "words" else Furigana.reading(e["examples"][0]["ja"])
	var row := UITheme.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var play := UITheme.button("▶ 聞く")
	play.pressed.connect(func() -> void: Speech.speak(text))
	row.add_child(play)
	var slow := UITheme.button("▶ ゆっくり", false)
	slow.pressed.connect(func() -> void: Speech.speak(text, Speech.RATE_SLOW))
	row.add_child(slow)
	Speech.speak(text)
	UITheme.animate_in(card)
	match _mode:
		"words":
			var q := ExamBuilder.recall_question(e, ContentDB.unlocked_items("vocab", Progress.stage))
			_choices(v, q["options"], int(q["answer"]), e)
		"sentences":
			var q2 := ExamBuilder.example_reading_question(e, _items if _items.size() >= 4 else ContentDB.stage_items("vocab", Progress.stage))
			_choices(v, q2["options"], int(q2["answer"]), e)
		"shadowing":
			_shadow(v, e)


func _choices(v: VBoxContainer, options: Array, answer: int, e: Dictionary) -> void:
	var buttons: Array = []
	for i in options.size():
		var b := TileButton.new(options[i], UITheme.SIZE_BODY)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.enable_wrap()
		b.pressed.connect(func() -> void:
			var ok := i == answer
			for c in buttons:
				(c as TileButton).disabled = true
			(buttons[answer] as TileButton).set_state(UITheme.CORRECT_TINT, UITheme.CORRECT)
			if not ok:
				b.set_state(UITheme.INCORRECT_TINT, UITheme.INCORRECT)
			_result(ok, e))
		v.add_child(b)
		buttons.append(b)
	set_options(buttons)


func _result(ok: bool, e: Dictionary) -> void:
	set_options([])
	Progress.record_sample(&"listening", Srs.C_CORRECT if ok else Srs.C_WRONG)
	if ok:
		_correct += 1
		Progress.add_xp(Mastery.XP[&"listening"])
	var reveal: String = ExamBuilder.headword_markup(e) if _mode == "words" else e["examples"][0]["ja"]
	var en: String = e["english"] if _mode == "words" else e["examples"][0]["en"]
	_box.add_child(ScreenBase.feedback_card("○ {正解|せいかい}" if ok else "✕ {不正解|ふせいかい}", reveal, en,
		UITheme.CORRECT_TINT if ok else UITheme.INCORRECT_TINT, UITheme.CORRECT if ok else UITheme.INCORRECT))
	var next := UITheme.button("次へ")
	next.pressed.connect(func() -> void:
		_index += 1
		_show())
	_box.add_child(next)
	set_primary(next)


# ---------------------------------------------------------------- shadowing

func _setup_recording() -> void:
	var idx := AudioServer.get_bus_index(RECORD_BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, RECORD_BUS)
		AudioServer.set_bus_mute(idx, true)
		AudioServer.add_bus_effect(idx, AudioEffectRecord.new())
	_record = AudioServer.get_bus_effect(idx, 0) as AudioEffectRecord
	if _mic == null:
		_mic = AudioStreamPlayer.new()
		_mic.stream = AudioStreamMicrophone.new()
		_mic.bus = RECORD_BUS
		add_child(_mic)
		_playback = AudioStreamPlayer.new()
		add_child(_playback)


func _shadow(v: VBoxContainer, e: Dictionary) -> void:
	var ex: Dictionary = e["examples"][0]
	v.add_child(UITheme.ja(ex["ja"], UITheme.SIZE_BODY_L))
	if Progress.show_english():
		v.add_child(UITheme.en(ex["en"]))
	var row := UITheme.hbox(12)
	v.add_child(row)
	var rec := UITheme.button("● 録音")
	var play := UITheme.button("▶ 自分の声", false)
	play.disabled = true
	rec.pressed.connect(func() -> void:
		if _record == null:
			return
		if _record.is_recording_active():
			_record.set_recording_active(false)
			_mic.stop()
			_recording = _record.get_recording()
			UITheme.set_button_text(rec, "● 録音")
			play.disabled = _recording == null
		else:
			_mic.play()
			_record.set_recording_active(true)
			UITheme.set_button_text(rec, "■ 止める"))
	row.add_child(rec)
	play.pressed.connect(func() -> void:
		if _recording:
			_playback.stream = _recording
			_playback.play())
	row.add_child(play)
	v.add_child(UITheme.ja("{聞|き}き{比|くら}べて、{自分|じぶん}で{評価|ひょうか}してください。", UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	if Progress.show_explanations():
		v.add_child(UITheme.en("Compare your recording with the voice, then rate yourself. (Automatic pronunciation scoring needs a speech recogniser and is not included.)", UITheme.SIZE_LABEL))
	var grade := UITheme.hbox(12)
	v.add_child(grade)
	var buttons: Array = []
	for g in [["もう少し", 0.0], ["だいたい", 0.5], ["そっくり！", 1.0]]:
		var b := UITheme.button(g[0], g[1] >= 1.0)
		b.pressed.connect(func() -> void:
			Progress.record_sample(&"shadowing", g[1])
			if g[1] >= 1.0:
				_correct += 1
			_index += 1
			_show())
		grade.add_child(b)
		buttons.append(b)
	set_options(buttons)


func _finish() -> void:
	Progress.bump_daily("listening")
	Progress.save_game()
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja("{結果|けっか}", UITheme.SIZE_H2))
	v.add_child(UITheme.label("%d / %d" % [_correct, _items.size()], UITheme.SIZE_DISPLAY))
	var row := UITheme.hbox(12)
	v.add_child(row)
	var again := UITheme.button("もう一回")
	again.pressed.connect(_start.bind(_mode))
	row.add_child(again)
	var menu := UITheme.button("モード選択", false)
	menu.pressed.connect(_menu)
	row.add_child(menu)
	set_primary(again)
	UITheme.animate_in(card)
