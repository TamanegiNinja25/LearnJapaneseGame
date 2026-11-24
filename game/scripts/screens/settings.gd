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

	column.add_child(UITheme.toggle("N4まで{英語|えいご}を{全部|ぜんぶ}{表示|ひょうじ}する", bool(Progress.setting("beginner_english")),
		func(on: bool) -> void:
			Progress.set_setting("beginner_english", on)
			go(&"settings"), "Show English everywhere until you reach N4"))

	_section("{表示|ひょうじ}", "Display")
	column.add_child(UITheme.ja("{文字|もじ}の{大|おお}きさ", UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	var scales := [0.0, 1.0, 1.15, 1.3, 1.45]
	var current := scales.find(float(Progress.setting("ui_scale")))
	column.add_child(UITheme.segmented(["{自動|じどう}", "小", "中", "大", "特大"], maxi(0, current), func(i: int) -> void:
		Progress.set_setting("ui_scale", scales[i])))
	column.add_child(UITheme.segmented(["ライト", "ダーク"], 1 if Progress.setting("theme") == "dark" else 0,
		func(i: int) -> void: Progress.set_setting("theme", "dark" if i == 1 else "light")))
	column.add_child(UITheme.segmented(["Noto Sans JP（{標準|ひょうじゅん}）", "BIZ UDPゴシック（{読|よ}みやすい）"], 1 if Progress.setting("font") == "bizud" else 0,
		func(i: int) -> void: Progress.set_setting("font", "bizud" if i == 1 else "noto")))
	if Progress.show_explanations():
		column.add_child(UITheme.en("BIZ UDPGothic is a universal-design font that separates similar kanji (末/未) clearly.", UITheme.SIZE_LABEL))
	column.add_child(UITheme.toggle("{会話|かいわ}でタイプして{答|こた}える", bool(Progress.setting("typed_answers")),
		func(on: bool) -> void: Progress.set_setting("typed_answers", on), "Answer conversations by typing (romaji converts to kana)"))
	if SpeechInput.available():
		column.add_child(UITheme.toggle("{会話|かいわ}をハンズフリーで（{声|こえ}で{答|こた}える）", bool(Progress.setting("hands_free")),
			func(on: bool) -> void: Progress.set_setting("hands_free", on), "Conversations listen for your spoken answer by themselves and move on after a correct one"))

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

	_section("サウンド", "Sound")
	column.add_child(UITheme.toggle("{効果音|こうかおん}", bool(Progress.setting("sfx")),
		func(on: bool) -> void: Progress.set_setting("sfx", on), "Sound effects for answers, strokes and rank-ups"))
	column.add_child(UITheme.toggle("{音楽|おんがく}", bool(Progress.setting("music")),
		func(on: bool) -> void: Progress.set_setting("music", on), "Quiet background music (it fades out while Japanese is spoken)"))

	_section("データ", "Data")
	_backup_section()
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
	column.add_child(UITheme.toggle("{起動時|きどうじ}に{更新|こうしん}を{確認|かくにん}する", bool(Progress.setting("check_updates")),
		func(on: bool) -> void: Progress.set_setting("check_updates", on), "Check GitHub for a new version at start (the only time the game goes online)"))
	column.add_child(UITheme.ja("{日本語|にほんご}の{世界|せかい} — LearnJapaneseGame v%s (MIT licence)" % ProjectSettings.get_setting("application/config/version", "0"), UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))
	for line in [
		"Dictionary data: JMdict and KANJIDIC2 © EDRDG, CC BY-SA 4.0",
		"3D assets: KayKit by Kay Lousberg, CC0",
		"Fonts: Noto Sans JP, BIZ UDPGothic — SIL Open Font License 1.1",
		"Icons: Tabler Icons — MIT",
		"Stroke order: KanjiVG © Ulrich Apel and contributors, CC BY-SA 3.0 (kanjivg.tagaini.net)",
		"Engine: Godot Engine — MIT",
	]:
		column.add_child(UITheme.label(line, UITheme.SIZE_CAPTION, UITheme.TEXT_SECONDARY))


## Backups: a one-line code on the clipboard (works on phones, where the save file is private),
## plus a file in Documents on desktop.
func _backup_section() -> void:
	if Progress.show_explanations():
		column.add_child(UITheme.en("Your progress is stored only on this device. Copy a backup and keep it in your notes, e-mail or cloud drive; restore it on a new device or after reinstalling.", UITheme.SIZE_LABEL))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	column.add_child(row)
	var status := UITheme.vbox(2)
	var copy := UITheme.button("バックアップをコピー", false)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(Progress.backup_code())
		_status(status, "コピーしました。メモやメールに{貼|は}り{付|つ}けて{保存|ほぞん}してください。", "Copied. Paste it into a note or e-mail to keep it."))
	row.add_child(copy)
	var paste := UITheme.button("クリップボードから復元", false)
	paste.pressed.connect(func() -> void: _confirm_restore(DisplayServer.clipboard_get(), status))
	row.add_child(paste)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var save_file := UITheme.button("ファイルに書き出す", false)
		save_file.pressed.connect(func() -> void:
			var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			var path := dir.path_join("NihongoNoSekai-backup-%s.txt" % Time.get_date_string_from_system())
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(Progress.backup_code())
				f.close()
				_status(status, "{保存|ほぞん}しました。", path)
			else:
				_status(status, "{保存|ほぞん}できませんでした。", error_string(FileAccess.get_open_error())))
		row.add_child(save_file)
		var load_file := UITheme.button("ファイルから読み込む", false)
		load_file.pressed.connect(func() -> void:
			var dlg := FileDialog.new()
			dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			dlg.access = FileDialog.ACCESS_FILESYSTEM
			dlg.filters = PackedStringArray(["*.txt, *.json ; Backup"])
			dlg.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			dlg.file_selected.connect(func(path: String) -> void:
				_confirm_restore(FileAccess.get_file_as_string(path), status))
			add_child(dlg)
			dlg.popup_centered_ratio(0.7))
		row.add_child(load_file)
	column.add_child(status)


func _status(box: VBoxContainer, markup: String, english: String) -> void:
	ScreenBase.clear(box)
	box.add_child(UITheme.ja(markup, UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	if english != "":
		box.add_child(UITheme.en(english, UITheme.SIZE_LABEL))


func _confirm_restore(text: String, status: VBoxContainer) -> void:
	if not text.strip_edges().begins_with(Progress.BACKUP_PREFIX) and not text.strip_edges().begins_with("{"):
		_status(status, "バックアップが{見|み}つかりません。", "Copy your backup code first, then press restore.")
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "復元"
	dlg.dialog_text = "今の学習データをバックアップで上書きします。よろしいですか？\nThis replaces your current progress with the backup."
	dlg.ok_button_text = "復元する"
	dlg.cancel_button_text = "やめる"
	dlg.confirmed.connect(func() -> void:
		if Progress.restore_backup(text):
			go(&"dashboard")
		else:
			_status(status, "バックアップを{読|よ}めませんでした。", "That text is not a valid backup."))
	add_child(dlg)
	dlg.popup_centered()


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
