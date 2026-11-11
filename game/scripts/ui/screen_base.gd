extends Control
class_name ScreenBase
## Base for every study screen: full-rect, one centred scrolling column (ART_BIBLE §2.7), and a
## navigate signal the main router listens to. Screens build their widgets in code in _ready().

signal navigate(target: StringName)

var column: VBoxContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Creates the scroll + centred column and returns the column to fill.
func make_column(width: int = UITheme.COLUMN_WIDTH) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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


## Remove every child of a container (deferred-free safe).
static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Feedback card: verdict label + Japanese explanation + optional English.
static func feedback_card(verdict: String, ja: String, en: String, tint: Color, ink: Color) -> PanelContainer:
	var card := UITheme.card(tint, ink)
	var v := UITheme.vbox(8)
	card.add_child(v)
	v.add_child(UITheme.ja(verdict, UITheme.SIZE_H2, ink))
	if ja != "":
		v.add_child(UITheme.ja(ja, UITheme.SIZE_BODY))
	if en != "" and Progress.show_explanations():
		v.add_child(UITheme.en(en))
	return card


static func shuffled(arr: Array) -> Array:
	var copy := arr.duplicate()
	copy.shuffle()
	return copy
