extends Button
class_name TileButton
## A button whose face is a FuriganaLabel, so word tiles and answer options keep their ruby.
## An optional English subtitle sits under the Japanese (beginner help until N4).
## Button.text stays empty; [member markup] holds the content.

var markup: String = ""
var label: FuriganaLabel
var subtitle: Label
var _box: VBoxContainer


func _init(text_markup: String = "", size: int = UITheme.SIZE_BODY, english: String = "") -> void:
	markup = text_markup
	text = ""
	focus_mode = Control.FOCUS_ALL
	UITheme.set_tile(self)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label = FuriganaLabel.new()
	label.font_size = size
	label.weight = UITheme.weight_for(size)
	label.color = UITheme.TEXT_PRIMARY
	label.ruby_color = UITheme.TEXT_SECONDARY
	label.text = markup
	label.autowrap = false
	label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(label)
	if english != "":
		set_subtitle(english)
	_fit()


## Small English line under the Japanese (shown only when the caller decides to).
func set_subtitle(english: String) -> void:
	if subtitle == null:
		subtitle = Label.new()
		subtitle.add_theme_font_override("font", UITheme.font(400))
		subtitle.add_theme_font_size_override("font_size", UITheme.SIZE_EN_SUB)
		subtitle.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_box.add_child(subtitle)
	subtitle.text = english
	_fit()


func _fit() -> void:
	var min := label.get_minimum_size()
	var w := min.x
	var h := min.y
	if subtitle and subtitle.text != "":
		var f := UITheme.font(400)
		w = maxf(w, minf(f.get_string_size(subtitle.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.SIZE_EN_SUB).x, 420.0))
		h += UITheme.SIZE_EN_SUB + 6
	custom_minimum_size = Vector2(w + 32, maxf(56.0, h + 8))


## Let long options wrap inside a full-width button.
func enable_wrap() -> void:
	label.autowrap = true
	label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if subtitle:
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		subtitle.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_box.offset_left = 20
	_box.offset_right = -20
	custom_minimum_size.x = 0
	resized.connect(_fit_height)


func _fit_height() -> void:
	var h := label.get_minimum_size().y + 8
	if subtitle and subtitle.text != "":
		h += subtitle.get_minimum_size().y + 2
	if absf(custom_minimum_size.y - maxf(56.0, h)) > 1.0:
		custom_minimum_size.y = maxf(56.0, h)


func set_state(fill: Color, border: Color) -> void:
	UITheme.set_tile(self, fill, border)


func set_text_color(c: Color) -> void:
	label.color = c
	label.ruby_color = c
	if subtitle:
		subtitle.add_theme_color_override("font_color", c)


func plain() -> String:
	return Furigana.plain(markup)
