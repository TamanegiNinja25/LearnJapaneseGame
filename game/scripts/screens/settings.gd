extends ScreenBase
## 設定: English assistance, theme, font, typed answers, voice and speed, data (export reports,
## reset progress) and 情報 (credits and licences).


func _ready() -> void:
	make_column(900)
	add_title("{設定|せってい}", "Settings")

	_section("{英語|えいご}のサポート", "English assistance")
	column.add_child(UITheme.segmented(["日本語のみ", "日本語＋説明", "日本語＋訳", "バイリンガル"], Progress.english_mode,
		func(i: int) -> void:
			Progress.set_english_mode(i)
			go(&"settings")))
	column.add_child(UITheme.toggle("ステージに{合|あ}わせて{自動|じどう}で{減|へ}らす", bool(Progress.setting("english_auto")),
		func(on: bool) -> void: Progress.set_setting("english_auto", on), "Reduce English automatically as you advance"))

	_section("{表示|ひょうじ}", "Display")
	column.add_child(UITheme.segmented(["ライト", "ダーク"], 1 if Progress.setting("theme") == "dark" else 0,
		func(i: int) -> void: Progress.set_setting("theme", "dark" if i == 1 else "light")))
	column.add_child(UITheme.segmented(["Noto Sans JP（{標準|ひょうじゅん}）", "BIZ UDPゴシック（{読|よ}みやすい）"], 1 if Progress.setting("font") == "bizud" else 0,
		func(i: int) -> void: Progress.set_setting("font", "bizud" if i == 1 else "noto")))
	if Progress.show_explanations():
		column.add_child(UITheme.en("BIZ UDPGothic is a universal-design font that separates similar kanji (末/未) clearly.", UITheme.SIZE_LABEL))
	column.add_child(UITheme.toggle("{会話|かいわ}でタイプして{答|こた}える", bool(Progress.setting("typed_answers")),
		func(on: bool) -> void: Progress.set_setting("typed_answers", on), "Answer conversations by typing (romaji converts to kana)"))

	_section("{音声|おんせい}", "Voice")
	var names := Speech.voice_names()
	if names.is_empty():
		column.add_child(UITheme.ja("{日本語|にほんご}の{音声|おんせい}がありません。", UITheme.SIZE_BODY, UITheme.TEXT_SECONDARY))
		column.add_child(UITheme.en("Install a Japanese text-to-speech voice in your operating system to enable listening practice."))
	else:
		var voice := OptionButton.new()
		var ids: Array = names.keys()
		for id in ids:
			voice.add_item(names[id])
		voice.selected = maxi(0, ids.find(Speech.voice_id()))
		voice.item_selected.connect(func(i: int) -> void: Progress.set_setting("voice", ids[i]))
		column.add_child(voice)
		var rate_row := UITheme.hbox(12)
		column.add_child(rate_row)
		rate_row.add_child(UITheme.ja("{速|はや}さ", UITheme.SIZE_LABEL))
		var rate := HSlider.new()
		rate.min_value = 0.5
		rate.max_value = 1.5
		rate.step = 0.1
		rate.value = float(Progress.setting("tts_rate"))
		rate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rate.drag_ended.connect(func(_changed: bool) -> void: Progress.set_setting("tts_rate", rate.value))
		rate_row.add_child(rate)
		var test := UITheme.button("▶ テスト", false)
		test.pressed.connect(func() -> void: Speech.speak("こんにちは。{日本語|にほんご}を{勉強|べんきょう}しましょう。"))
		rate_row.add_child(test)

	_section("データ", "Data")
	var reports := Progress.reports.size()
	var export := UITheme.button("報告を書き出す（%d）" % reports, false)
	export.tooltip_text = "Write sentence orders you reported as natural to user://reports.json"
	export.disabled = reports == 0
	export.pressed.connect(func() -> void:
		var f := FileAccess.open("user://reports.json", FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(Progress.reports, "\t"))
			f.close()
			UITheme.set_button_text(export, "書き出し済み")
			column.add_child(UITheme.label(ProjectSettings.globalize_path("user://reports.json"), UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY)))
	column.add_child(export)
	var reset := UITheme.button("学習データをリセット", false)
	reset.add_theme_color_override("font_color", UITheme.INCORRECT)
	reset.pressed.connect(_confirm_reset)
	column.add_child(reset)

	_section("{情報|じょうほう}", "About and credits")
	column.add_child(UITheme.ja("{日本語|にほんご}の{世界|せかい} — LearnJapaneseGame v%s (MIT licence)" % ProjectSettings.get_setting("application/config/version", "0"), UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	for line in [
		"Dictionary data: JMdict and KANJIDIC2 © EDRDG, CC BY-SA 4.0",
		"3D assets: KayKit by Kay Lousberg, CC0",
		"Fonts: Noto Sans JP, BIZ UDPGothic — SIL Open Font License 1.1",
		"Icons: Tabler Icons — MIT",
		"Engine: Godot Engine — MIT",
	]:
		column.add_child(UITheme.label(line, UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))


func _section(markup: String, english: String) -> void:
	column.add_child(UITheme.spacer(8))
	column.add_child(UITheme.ja(markup, UITheme.SIZE_H2))
	if Progress.show_english():
		column.add_child(UITheme.en(english))


func _confirm_reset() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "リセット"
	dlg.dialog_text = "すべての学習データを消します。元に戻せません。よろしいですか？\nThis erases all progress and cannot be undone."
	dlg.ok_button_text = "消す"
	dlg.cancel_button_text = "やめる"
	dlg.confirmed.connect(func() -> void:
		Progress.wipe()
		go(&"dashboard"))
	add_child(dlg)
	dlg.popup_centered()
