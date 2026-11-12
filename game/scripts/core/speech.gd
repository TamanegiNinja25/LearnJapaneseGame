extends RefCounted
class_name Speech
## Japanese text-to-speech through the operating system (DisplayServer TTS). Needs the project
## setting audio/general/text_to_speech = true and an installed Japanese voice (on Windows:
## Settings › Time & language › Speech › Add voices › 日本語). Every call is safe without a voice.

const RATE_SLOW := 0.7


static func voices() -> Array:
	if DisplayServer.get_name() == "headless":
		return []
	return DisplayServer.tts_get_voices_for_language("ja")


static func available() -> bool:
	return not voices().is_empty()


## The configured voice id, or the first Japanese voice.
static func voice_id() -> String:
	var all := voices()
	if all.is_empty():
		return ""
	var chosen := String(Progress.setting("voice")) if Engine.get_main_loop() else ""
	return chosen if chosen in all else String(all[0])


## Speak plain text (markup is converted to its kana reading so the voice reads it correctly).
static func speak(text: String, rate: float = -1.0) -> void:
	var id := voice_id()
	if id == "":
		return
	var spoken := Furigana.reading(text) if text.contains("{") else text
	var r := rate if rate > 0.0 else float(Progress.setting("tts_rate"))
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(spoken, id, 80, 1.0, clampf(r, 0.1, 10.0))


static func stop() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.tts_stop()


static func is_speaking() -> bool:
	return DisplayServer.get_name() != "headless" and DisplayServer.tts_is_speaking()


## Human-readable voice names keyed by id (for the settings screen).
static func voice_names() -> Dictionary:
	var out := {}
	if DisplayServer.get_name() == "headless":
		return out
	for v in DisplayServer.tts_get_voices():
		if String(v["language"]).begins_with("ja"):
			out[v["id"]] = v["name"]
	return out
