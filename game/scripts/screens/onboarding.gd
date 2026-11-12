extends ScreenBase
## First-run welcome (GDD §13 question 1, resolved): a one-time bilingual introduction, so a
## complete beginner can start before they can read the Japanese-first interface. It sets the
## English assistance mode and sends the player to the kana trainer.

var _page := 0
var _box: VBoxContainer

const PAGES := [
	{"ja": "ようこそ、{日本語|にほんご}の{世界|せかい}へ！", "en": "Welcome to the World of Japanese!",
		"body_ja": "このゲームは{日本語|にほんご}が{中心|ちゅうしん}です。{漢字|かんじ}には{全部|ぜんぶ}ふりがながあります。",
		"body_en": "Everything is in Japanese first. Every kanji has its reading (furigana) written above it. English is there to help, and you can turn it up or down any time."},
	{"ja": "レベルは{実力|じつりょく}で{上|あ}がります", "en": "You level up by proving what you know",
		"body_ja": "六つのスキルが{基準|きじゅん}を{超|こ}えたら、{昇級試験|しょうきゅうしけん}に{挑戦|ちょうせん}できます。",
		"body_en": "Six skills — vocabulary, grammar, reading, listening, conversation and kanji — are measured as you play. When they reach the thresholds you can take the stage exam: N5 → N4 → … → N1 → Mastery."},
	{"ja": "まずはかなから", "en": "Start with kana",
		"body_ja": "ひらがなとカタカナを{覚|おぼ}えると、{全部|ぜんぶ}{読|よ}めるようになります。",
		"body_en": "Hiragana and katakana unlock everything else. Choose how much English you want, then begin with the kana trainer."},
]


func _ready() -> void:
	make_column(820)
	_box = UITheme.vbox(UITheme.GAP)
	column.add_child(_box)
	_show()


func _show() -> void:
	ScreenBase.clear(_box)
	var p: Dictionary = PAGES[_page]
	_box.add_child(UITheme.spacer(40))
	_box.add_child(UITheme.label("%d / %d" % [_page + 1, PAGES.size()], UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	var card := UITheme.card()
	_box.add_child(card)
	var v := UITheme.vbox(UITheme.GAP)
	card.add_child(v)
	v.add_child(UITheme.ja(p["ja"], UITheme.SIZE_H1))
	v.add_child(UITheme.label(p["en"], UITheme.SIZE_H2, UITheme.TEXT_SECONDARY))
	v.add_child(UITheme.ja(p["body_ja"], UITheme.SIZE_BODY_L))
	v.add_child(UITheme.en(p["body_en"], UITheme.SIZE_BODY_L))
	UITheme.animate_in(card)
	if _page == PAGES.size() - 1:
		v.add_child(UITheme.ja("{英語|えいご}のサポート", UITheme.SIZE_H2))
		var modes := [["{日本語|にほんご}のみ", "Japanese only"], ["{日本語|にほんご}＋{説明|せつめい}", "Japanese + English explanations"],
			["{日本語|にほんご}＋{訳|やく}", "Japanese + translations (recommended)"], ["バイリンガル", "Full bilingual"]]
		var opts: Array = []
		for i in modes.size():
			var b := TileButton.new(modes[i][0], UITheme.SIZE_LABEL)
			b.tooltip_text = modes[i][1]
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if i == Progress.english_mode:
				b.set_state(UITheme.PRIMARY_TINT, UITheme.PRIMARY)
			b.pressed.connect(func() -> void:
				Progress.set_english_mode(i, false)
				_show())
			v.add_child(b)
			opts.append(b)
		set_options(opts)
	var row := UITheme.hbox(12)
	_box.add_child(row)
	if _page > 0:
		var back := UITheme.button("戻る", false)
		back.pressed.connect(func() -> void:
			_page -= 1
			_show())
		row.add_child(back)
	var next := UITheme.button("次へ" if _page < PAGES.size() - 1 else "はじめる")
	next.pressed.connect(_next)
	row.add_child(next)
	set_primary(next)


func _next() -> void:
	if _page < PAGES.size() - 1:
		_page += 1
		_show()
		return
	Progress.set_setting("onboarded", true)
	go(&"kana")
