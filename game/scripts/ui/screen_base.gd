extends Control
class_name ScreenBase
## Base for every screen: full-rect, one centred scrolling column (ART_BIBLE §2.7), a navigate
## signal the router listens to, optional [member args] from the caller, and keyboard/gamepad
## shortcuts: 1–4 pick the registered options, Enter presses the primary action, Esc goes home.

signal navigate(target: StringName, args: Dictionary)

var column: VBoxContainer
var args: Dictionary = {}
var scroll: ScrollContainer
var _max_width := UITheme.COLUMN_WIDTH
var _options: Array[Button] = []
var _primary: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Ask the router to open another screen.
func go(target: StringName, with_args: Dictionary = {}) -> void:
	navigate.emit(target, with_args)


## Creates the scroll + centred column and returns the column to fill. The column grows to use
## the screen (phones in landscape are wide) up to [param width] × 1.45, and shrinks on small
## windows. Touch drags anywhere in it scroll, even when they start on a button.
func make_column(width: int = UITheme.COLUMN_WIDTH) -> VBoxContainer:
	_max_width = width
	scroll = make_scroll(self)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	scroll.add_child(margin)
	column = UITheme.vbox(UITheme.GAP)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(column)
	_fit_column()
	resized.connect(_fit_column)
	return column


## Width available to the column right now.
func content_width() -> float:
	var area := size.x if size.x > 0 else get_parent_area_size().x
	return maxf(320.0, area - 48.0)


func _fit_column() -> void:
	if column:
		column.custom_minimum_size.x = minf(content_width(), _max_width * 1.45)


## A vertical ScrollContainer for touch: drags that start on buttons still scroll (buttons pass
## events up and cancel their press when the scroll begins), with a small deadzone.
static func make_scroll(parent: Node) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = not DisplayServer.is_touchscreen_available()
	sc.scroll_deadzone = 12
	parent.add_child(sc)
	enable_touch_scroll(sc)
	return sc


## Make every control added under [param sc] pass mouse/touch events up so the container can
## start a drag-scroll. Text fields and lists keep their own handling.
static func enable_touch_scroll(sc: ScrollContainer) -> void:
	var tree := sc.get_tree() if sc.is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	var hook := func(n: Node) -> void:
		if n is Control and sc.is_ancestor_of(n) and not (n is LineEdit or n is ItemList or n is Slider or n is ScrollBar or n is TextEdit):
			if (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
				(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	tree.node_added.connect(hook)
	sc.tree_exiting.connect(func() -> void:
		if tree.node_added.is_connected(hook):
			tree.node_added.disconnect(hook))


## Drag-to-scroll for an ItemList on touch screens (it has no built-in touch scrolling).
static func touch_scroll_list(list: ItemList) -> void:
	list.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenDrag:
			list.get_v_scroll_bar().value -= (e as InputEventScreenDrag).relative.y)


## Japanese heading/label with its English underneath when English help is on.
static func ja_en(markup: String, english: String, size: int = UITheme.SIZE_LABEL, color: Color = Color(0, 0, 0, 0)) -> Control:
	if english == "" or not Progress.show_english():
		return UITheme.ja(markup, size, color)
	var v := UITheme.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UITheme.ja(markup, size, color))
	v.add_child(UITheme.en(english, size))
	return v


## True on short screens (phones in landscape): titles shrink and sit on one line with English.
func compact() -> bool:
	return get_viewport_rect().size.y < 760.0


## Screen title (h1) with an optional English gloss beneath (beside it on compact screens).
func add_title(markup: String, english: String = "") -> void:
	var show_en := english != "" and Progress.show_english()
	if compact():
		var row := UITheme.hbox(16)
		var t := UITheme.ja(markup, UITheme.SIZE_H2)
		t.autowrap = false
		t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(t)
		if show_en:
			var e := UITheme.en(english, UITheme.SIZE_H2)
			e.size_flags_vertical = Control.SIZE_SHRINK_END
			row.add_child(e)
		column.add_child(row)
		return
	column.add_child(UITheme.ja(markup, UITheme.SIZE_H1))
	if show_en:
		column.add_child(UITheme.en(english, UITheme.SIZE_H1))


## Text input that behaves on phones: no automatic keyboard pop-up, and when tapped the page
## scrolls so the field sits near the top, above the on-screen keyboard.
func setup_text_input(input: LineEdit) -> void:
	if DisplayServer.is_touchscreen_available():
		input.focus_entered.connect(func() -> void:
			if scroll:
				var y := input.get_global_rect().position.y - scroll.get_global_rect().position.y + scroll.scroll_vertical
				scroll.scroll_vertical = int(maxf(0.0, y - 24.0)))
	else:
		input.call_deferred("grab_focus")


## Register the answer buttons of the current card (keys 1–4) and focus the first.
func set_options(buttons: Array) -> void:
	_options.clear()
	for b in buttons:
		_options.append(b)
	# Focus helps keyboards/gamepads; on touch screens it only makes the page jump to the button.
	if not _options.is_empty() and not DisplayServer.is_touchscreen_available():
		_options[0].call_deferred("grab_focus")


## Register the button Enter should press (usually 次へ) and focus it.
func set_primary(b: Button) -> void:
	_primary = b
	if b and not DisplayServer.is_touchscreen_available():
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
