extends VBoxContainer
class_name MicButton
## A "speak your answer" control: a button plus a status line. Tap to listen, tap again to finish
## early; the recogniser also stops by itself after a pause. Emits [signal heard] with the
## alternatives (best first). Errors and the words heard so far show in the status line.
## Only add it when SpeechInput.available() is true.

signal heard(alternatives: Array[String])

var _button: Button
var _status: VBoxContainer
var _listening := false


func _init(label: String = "● 話して答える") -> void:
	add_theme_constant_override("separation", 4)
	_button = UITheme.button(label, false)
	_button.pressed.connect(_toggle)
	add_child(_button)
	_status = UITheme.vbox(2)
	add_child(_status)


func _exit_tree() -> void:
	if _listening:
		SpeechInput.cancel()


## Start listening (also used by hands-free mode).
func listen() -> void:
	if _listening:
		return
	_listening = true
	UITheme.set_button_text(_button, "■ {聞|き}いています…")
	say("{日本語|にほんご}で{話|はな}してください。", "Speak in Japanese. Tap again to finish.")
	SpeechInput.listen(_on_result, _on_error, func(text: String) -> void: say("「%s」" % text, ""))


## Show a line under the button (markup, optional English).
func say(markup: String, english: String = "") -> void:
	ScreenBase.clear(_status)
	if markup != "":
		_status.add_child(UITheme.ja(markup, UITheme.SIZE_LABEL, UITheme.TEXT_SECONDARY))
	if english != "" and UITheme.beginner():
		_status.add_child(UITheme.en(english, UITheme.SIZE_LABEL))


func _toggle() -> void:
	if _listening:
		SpeechInput.stop()
	else:
		listen()


func _reset() -> void:
	_listening = false
	if is_instance_valid(_button):
		UITheme.set_button_text(_button, "● もう一度話す")


func _on_result(alternatives: Array[String]) -> void:
	_reset()
	say("{聞|き}こえた{言葉|ことば}：「%s」" % alternatives[0], "")
	heard.emit(alternatives)


func _on_error(message: String) -> void:
	_reset()
	say(message, "")
