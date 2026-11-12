extends Button
class_name TileButton
## A button whose face is a FuriganaLabel, so word tiles and answer options keep their ruby.
## Button.text stays empty; [member markup] holds the content.

var markup: String = ""
var label: FuriganaLabel


func _init(text_markup: String = "", size: int = UITheme.SIZE_BODY) -> void:
	markup = text_markup
	text = ""
	focus_mode = Control.FOCUS_ALL
	UITheme.set_tile(self)
	label = FuriganaLabel.new()
	label.font_size = size
	label.weight = UITheme.weight_for(size)
	label.color = UITheme.TEXT_PRIMARY
	label.ruby_color = UITheme.TEXT_SECONDARY
	label.text = markup
	label.autowrap = false
	label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var min := label.get_minimum_size()
	custom_minimum_size = Vector2(min.x + 32, maxf(56.0, min.y + 8))


## Let long options wrap inside a full-width button.
func enable_wrap() -> void:
	label.autowrap = true
	label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 20
	label.offset_right = -20
	custom_minimum_size.x = 0
	resized.connect(_fit_height)


func _fit_height() -> void:
	var h := label.get_minimum_size().y + 8
	if absf(custom_minimum_size.y - maxf(56.0, h)) > 1.0:
		custom_minimum_size.y = maxf(56.0, h)


func set_state(fill: Color, border: Color) -> void:
	UITheme.set_tile(self, fill, border)


func set_text_color(c: Color) -> void:
	label.color = c
	label.ruby_color = c


func plain() -> String:
	return Furigana.plain(markup)
