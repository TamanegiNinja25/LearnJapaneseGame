extends Control
class_name ScreenBase
## Base for every screen: full-rect, one centred scrolling column (ART_BIBLE §2.7), a navigate
## signal the router listens to, optional [member args] from the caller, and keyboard/gamepad
## shortcuts: 1–4 pick the registered options, Enter presses the primary action, Esc goes home.

signal navigate(target: StringName, args: Dictionary)

var column: VBoxContainer
var args: Dictionary = {}
var _options: Array[Button] = []
var _primary: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Ask the router to open another screen.
func go(target: StringName, with_args: Dictionary = {}) -> void:
	navigate.emit(target, with_args)


## Creates the scroll + centred column and returns the column to fill.
func make_column(width: int = UITheme.COLUMN_WIDTH) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	scroll.add_child(margin)
	column = UITheme.vbox(UITheme.GAP)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.custom_minimum_size.x = width
	margin.add_child(column)
	return column


## Screen title (h1) with an optional English gloss beneath.
func add_title(markup: String, english: String = "") -> void:
	column.add_child(UITheme.ja(markup, UITheme.SIZE_H1))
	if english != "" and Progress.show_english():
		column.add_child(UITheme.en(english, UITheme.SIZE_H1))


## Register the answer buttons of the current card (keys 1–4) and focus the first.
func set_options(buttons: Array) -> void:
	_options.clear()
	for b in buttons:
		_options.append(b)
	if not _options.is_empty():
		_options[0].call_deferred("grab_focus")


## Register the button Enter should press (usually 次へ) and focus it.
func set_primary(b: Button) -> void:
	_primary = b
	if b:
		b.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			var i := k - KEY_1
			if i < _options.size() and is_instance_valid(_options[i]) and not _options[i].disabled and _options[i].is_visible_in_tree():
				_options[i].pressed.emit()
				get_viewport().set_input_as_handled()
		elif (k == KEY_ENTER or k == KEY_KP_ENTER) and is_instance_valid(_primary) and not _primary.disabled and _primary.is_visible_in_tree():
			if get_viewport().gui_get_focus_owner() is LineEdit:
				return
			_primary.pressed.emit()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			go(&"dashboard")
			get_viewport().set_input_as_handled()


## Remove every child of a container (deferred-free safe).
static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Feedback card: verdict + Japanese explanation + optional English, faded in (no bounce).
static func feedback_card(verdict: String, ja: String, en: String, tint: Color, ink: Color) -> PanelContainer:
	var card := UITheme.card(tint, ink)
	var v := UITheme.vbox(8)
	card.add_child(v)
	v.add_child(UITheme.ja(verdict, UITheme.SIZE_H2, ink))
	if ja != "":
		v.add_child(UITheme.ja(ja, UITheme.SIZE_BODY))
	if en != "" and Progress.show_explanations():
		v.add_child(UITheme.en(en))
	UITheme.animate_in(card)
	return card


## A small ▶ button that speaks [param text] with the system Japanese voice; hidden without one.
static func speak_button(text: String, slow: bool = false) -> Button:
	var b := Button.new()
	b.tooltip_text = "Play audio"
	b.icon = load("res://assets/icons/volume.svg") if ResourceLoader.exists("res://assets/icons/volume.svg") else null
	b.expand_icon = true
	b.custom_minimum_size = Vector2(48, 48)
	b.focus_mode = Control.FOCUS_ALL
	UITheme.set_icon_button(b)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: Speech.speak(text, Speech.RATE_SLOW if slow else -1.0))
	b.visible = Speech.available()
	return b


static func shuffled(arr: Array) -> Array:
	var copy := arr.duplicate()
	copy.shuffle()
	return copy
