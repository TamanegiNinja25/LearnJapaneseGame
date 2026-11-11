extends Button
class_name TileButton
## A button whose face is a FuriganaLabel, so word tiles and answer options keep their ruby.
## Button.text stays empty; [member markup] holds the content.

var markup: String = ""
var label: FuriganaLabel


func _init(text_markup: String = "", size: int = UITheme.SIZE_BODY) -> void:
	markup = text_markup
	text = ""
	custom_minimum_size.y = 56
	UITheme.set_tile(self)
	label = FuriganaLabel.new()
	label.text = markup
	label.font_size = size
	label.autowrap = false
	label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var min := label.get_combined_minimum_size()
	custom_minimum_size = Vector2(min.x + 32, maxf(56.0, min.y + 8))


func set_state(fill: Color, border: Color) -> void:
	UITheme.set_tile(self, fill, border)


func plain() -> String:
	return Furigana.plain(markup)
