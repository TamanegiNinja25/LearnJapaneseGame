extends RefCounted
class_name SpeechInput
## Speech recognition for speaking practice: the Android plugin "NihongoSpeech"
## (tools/android/speech_plugin/, on-device and offline once the phone's Japanese speech pack is
## installed). Other platforms have no recogniser, so available() is false there and screens hide
## their speak buttons. Safe to call anywhere: without the plugin every call does nothing.
##
## listen() hands back the recogniser's alternatives (best first) or an error message in markup.

const SINGLETON := "NihongoSpeech"  # must differ from this class name: Android singletons become globals
const PERMISSION := "android.permission.RECORD_AUDIO"
const LANGUAGE := "ja-JP"

## android.speech.SpeechRecognizer.ERROR_* -> what to tell the player.
const ERRORS := {
	1: "{通信|つうしん}エラーです。もう{一度|いちど}。",
	2: "{通信|つうしん}エラーです。もう{一度|いちど}。",
	3: "マイクを{使|つか}えませんでした。",
	5: "もう{一度|いちど}{押|お}してください。",
	6: "{声|こえ}が{聞|き}こえませんでした。",
	7: "{聞|き}き{取|と}れませんでした。もう{一度|いちど}。",
	8: "{少|すこ}し{待|ま}ってからもう{一度|いちど}。",
	9: "マイクの{許可|きょか}が{必要|ひつよう}です。",
	12: "{日本語|にほんご}の{音声認識|おんせいにんしき}がありません。",
	13: "{日本語|にほんご}の{音声認識|おんせいにんしき}をダウンロードしてください。",
}


static func _plugin() -> Object:
	return Engine.get_singleton(SINGLETON) if Engine.has_singleton(SINGLETON) else null


## True when this device can turn speech into text (an Android phone with a recogniser).
static func available() -> bool:
	var p := _plugin()
	return p != null and bool(p.call("isAvailable"))


## Why speaking is or is not possible here, for 設定 (markup).
static func status() -> String:
	if not OS.has_feature("android"):
		return "{音声認識|おんせいにんしき}：このデバイスでは{使|つか}えません（Android{専用|せんよう}）"
	if _plugin() == null:
		return "{音声認識|おんせいにんしき}：プラグインがありません"
	return "{音声認識|おんせいにんしき}：" + ("{使|つか}えます" if available() else "{使|つか}えません（{音声認識|おんせいにんしき}アプリが{見|み}つかりません）")


## Ask for microphone access if needed. Returns true when it is already granted; otherwise the
## system dialog opens and the player presses the speak button again.
static func ensure_permission() -> bool:
	if not OS.has_feature("android"):
		return true
	if PERMISSION in OS.get_granted_permissions():
		return true
	OS.request_permission(PERMISSION)
	return false


## Listen once. [param on_result] gets (alternatives: Array[String]); [param on_error] gets
## (message markup); [param on_partial] (optional) gets the words heard so far.
static func listen(on_result: Callable, on_error: Callable, on_partial: Callable = Callable()) -> void:
	var p := _plugin()
	if p == null:
		on_error.call("{音声認識|おんせいにんしき}が{使|つか}えません。")
		return
	if not ensure_permission():
		on_error.call(ERRORS[9])
		return
	DisplayServer.tts_stop()  # the game's own voice must not be heard by the microphone
	_disconnect(p)
	p.connect("speech_result", func(best: String, all: String) -> void:
		_disconnect(p)
		var alts: Array[String] = []
		for line in all.split("\n", false):
			alts.append(line)
		if alts.is_empty():
			alts.append(best)
		on_result.call(alts))
	p.connect("speech_error", func(code: int) -> void:
		_disconnect(p)
		on_error.call(ERRORS.get(code, "{聞|き}き{取|と}れませんでした。もう{一度|いちど}。")))
	if on_partial.is_valid():
		p.connect("speech_partial", func(text: String) -> void: on_partial.call(text))
	p.call("start", LANGUAGE)


## Stop listening and deliver what was heard so far.
static func stop() -> void:
	var p := _plugin()
	if p:
		p.call("stop")


## Stop listening and drop the result.
static func cancel() -> void:
	var p := _plugin()
	if p:
		_disconnect(p)
		p.call("cancel")


static func _disconnect(p: Object) -> void:
	for sig in ["speech_result", "speech_error", "speech_partial"]:
		for c: Dictionary in p.get_signal_connection_list(sig):
			p.disconnect(sig, c["callable"])
