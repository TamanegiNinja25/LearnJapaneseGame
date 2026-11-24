extends ScreenBase
## 表現: two drills about how Japanese sounds, not only whether it is grammatical (GDD §9.5).
## 言い換え rewrites a sentence into another register (polite ↔ casual ↔ honorific);
## 不自然な文 picks the reply a native speaker would not say, from the conversation scenarios.
## Questions come from StyleDrills; answers feed 文法 and 会話.
##
## args: {"mode": "rewrite" | "natural"}

const MODES := ["rewrite", "natural"]
const MODE_LABELS := ["言い換え", "不自然な文"]

var _mode := "rewrite"
var _questions: Array[Dictionary] = []
var _index := 0
var _right := 0
var _box: VBoxContainer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	make_column(UITheme.COLUMN_WIDTH)
	add_title("{表現|ひょうげん}", "Natural Japanese")
	var wanted := String(args.get("mode", "rewrite"))
	_mode = wanted if wanted in MODES else "rewrite"
	column.add_child(UITheme.segmented(MODE_LABELS, MODES.find(_mode), func(i: int) -> void: go(&"style", {"mode": MODES[i]})))
	if Progress.show_explanations():
		var help := "Rewrite each sentence in the style asked for: polite (です・ます), casual (plain form) or honorific." if _mode == "rewrite" \
			else "Every reply here is grammatical, but one is not what a native speaker would say in this situation. Find it."
		column.add_child(UITheme.en(help, UITheme.SIZE_LABEL))
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	_rng.randomize()
	_build_round()
	_show()


func _build_round() -> void:
	var pool: Array[Dictionary] = []
	if _mode == "rewrite":
		for item in ContentDB.unlocked_items("rewrites", Progress.stage):
			pool.append(StyleDrills.rewrite_question(item))
	else:
		pool = StyleDrills.unnatural_questions(ContentDB.unlocked_items("scenarios", Progress.stage))
	pool.shuffle()
	_questions = []
	for q in pool.slice(0, 10):
		_questions.append(StyleDrills.shuffled(q, _rng))
	_index = 0
	_right = 0


func _show() -> void:
	ScreenBase.clear(_box)
	set_options([])
	if _questions.is_empty():
		_box.add_child(UITheme.ja("まだ{問題|もんだい}がありません。", UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
		return
	if _index >= _questions.size():
		_show_result()
		return
	var q := _questions[_index]
	_box.add_child(UITheme.label("%d / %d" % [_index + 1, _questions.size()], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	if String(q["context"]) != "":
		var ctx := UITheme.card(UITheme.SURFACE_ALT, UITheme.BORDER)
		ctx.add_child(UITheme.ja(q["context"], UITheme.SIZE_BODY))
		v.add_child(ctx)
	v.add_child(UITheme.ja(q["prompt"], UITheme.SIZE_H2))
	if Progress.show_explanations():
		v.add_child(UITheme.en(q["prompt_en"], UITheme.SIZE_LABEL))
	var buttons: Array = []
	for i in (q["options"] as Array).size():
		var b := TileButton.new(q["options"][i], UITheme.SIZE_BODY)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.enable_wrap()
		b.pressed.connect(_answer.bind(i, buttons))
		v.add_child(b)
		buttons.append(b)
	set_options(buttons)
	if _mode == "rewrite" and SpeechInput.available():
		var mic := MicButton.new("● 話して言い換える")
		mic.heard.connect(func(heard: Array[String]) -> void:
			var answer: String = q["options"][int(q["answer"])]
			var r := AnswerMatch.spoken(heard, [answer])
			if r["verdict"] == "correct":
				Progress.record_sample(&"speaking", Srs.C_CORRECT)
				Progress.bump_daily("spoken")
				_answer(int(q["answer"]), buttons)
			elif r["verdict"] == "close":
				mic.say("おしい！もう{一度|いちど}。", "Almost. Say it again.")
			else:
				mic.say("{違|ちが}うようです。もう{一度|いちど}。", "That does not sound like the right rewrite."))
		v.add_child(mic)
	UITheme.animate_in(card)


func _answer(chosen: int, buttons: Array) -> void:
	var q := _questions[_index]
	var correct := chosen == int(q["answer"])
	for i in buttons.size():
		var b: TileButton = buttons[i]
		b.disabled = true
		if i == int(q["answer"]):
			b.set_state(UITheme.CORRECT_TINT, UITheme.CORRECT)
		elif i == chosen:
			b.set_state(UITheme.INCORRECT_TINT, UITheme.INCORRECT)
	Progress.record_sample(q["activity"], Srs.C_CORRECT if correct else Srs.C_WRONG)
	if correct:
		_right += 1
		Progress.add_xp(Mastery.XP[q["activity"]])
	_box.add_child(ScreenBase.feedback_card("○ {正解|せいかい}" if correct else "✕ {不正解|ふせいかい}", q["feedback_ja"],
		q["feedback_en"] if Progress.show_english() else "", UITheme.CORRECT_TINT if correct else UITheme.INCORRECT_TINT,
		UITheme.CORRECT if correct else UITheme.INCORRECT))
	var next := UITheme.button("次へ")
	next.pressed.connect(func() -> void:
		_index += 1
		_show())
	_box.add_child(next)
	set_primary(next)


func _show_result() -> void:
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja("{結果|けっか}：%d / %d" % [_right, _questions.size()], UITheme.SIZE_H1, UITheme.PRIMARY))
	var again := UITheme.button("もう一度")
	again.pressed.connect(func() -> void:
		_build_round()
		_show())
	v.add_child(again)
	set_primary(again)
	Sfx.play("complete")
