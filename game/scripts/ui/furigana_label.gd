@tool
extends Control
class_name FuriganaLabel
## Draws Japanese text with furigana (ruby) above every kanji group, following the typography
## rules in docs/ART_BIBLE.md §2.2: ruby at 50% of the base size (min 11 px), 2 px ruby gap,
## line height 1.9x the base, ruby centred over its base, wrapping at character boundaries with
## 禁則処理 (no line starts with closing punctuation or small kana). Ruby height is always
## reserved so lines never jump when ruby is hidden.
##
## Godot's RichTextLabel has no ruby tag, so this control does its own layout in _draw().

const RUBY_GAP := 2.0
const LINE_FACTOR := 1.9
const NO_LINE_START := "。、」』）!?！？・ーぁぃぅぇぉっゃゅょァィゥェォッャュョ"

@export_multiline var text: String = "":
	set(value):
		text = value
		_segments = Furigana.parse(text)
		_relayout()
@export_range(11, 96) var font_size: int = 24:
	set(value):
		font_size = value
		_relayout()
@export var color: Color = Color("#2B2520"):
	set(value):
		color = value
		queue_redraw()
@export var ruby_color: Color = Color("#6B6159"):
	set(value):
		ruby_color = value
		queue_redraw()
@export var show_ruby: bool = true:
	set(value):
		show_ruby = value
		queue_redraw()
@export var autowrap: bool = true:
	set(value):
		autowrap = value
		_relayout()
@export var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		alignment = value
		queue_redraw()

var _segments: Array[Dictionary] = []
var _lines: Array[Dictionary] = []   # {"cells": Array[Dictionary], "width": float}
var _layout_width := -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func ruby_size() -> int:
	return maxi(11, int(font_size / 2.0))


func line_height() -> float:
	return font_size * LINE_FACTOR


func _font() -> Font:
	return get_theme_default_font()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		_relayout()


func _get_minimum_size() -> Vector2:
	if _lines.is_empty():
		return Vector2(0, line_height())
	var height := _lines.size() * line_height()
	if autowrap:
		return Vector2(0, height)
	var width := 0.0
	for line in _lines:
		width = maxf(width, float(line["width"]))
	return Vector2(width, height)


## Split segments into drawable cells: one cell per kanji group, one per plain character.
func _cells() -> Array[Dictionary]:
	var font := _font()
	var cells: Array[Dictionary] = []
	for seg in _segments:
		if seg["ruby"] != "":
			var base_w := font.get_string_size(seg["base"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var ruby_w := font.get_string_size(seg["ruby"], HORIZONTAL_ALIGNMENT_LEFT, -1, ruby_size()).x
			cells.append({"base": seg["base"], "ruby": seg["ruby"], "base_w": base_w, "ruby_w": ruby_w, "w": maxf(base_w, ruby_w)})
		else:
			for ch in seg["base"]:
				if ch == "\n":
					cells.append({"base": "\n", "ruby": "", "base_w": 0.0, "ruby_w": 0.0, "w": 0.0})
					continue
				var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				cells.append({"base": ch, "ruby": "", "base_w": w, "ruby_w": 0.0, "w": w})
	return cells


func _relayout() -> void:
	var avail := size.x if autowrap and size.x > 0 else INF
	_lines.clear()
	var current: Array[Dictionary] = []
	var width := 0.0
	for cell in _cells():
		if cell["base"] == "\n":
			_lines.append({"cells": current, "width": width})
			current = []
			width = 0.0
			continue
		var cw := float(cell["w"])
		var forbidden_start := String(cell["base"]).length() == 1 and NO_LINE_START.contains(cell["base"])
		if width + cw > avail and not current.is_empty() and not forbidden_start:
			_lines.append({"cells": current, "width": width})
			current = []
			width = 0.0
		cell["x"] = width
		current.append(cell)
		width += cw
	if not current.is_empty() or _lines.is_empty():
		_lines.append({"cells": current, "width": width})
	_layout_width = avail
	update_minimum_size()
	queue_redraw()


func _draw() -> void:
	var font := _font()
	var ascent := font.get_ascent(font_size)
	var ruby_ascent := font.get_ascent(ruby_size())
	var lh := line_height()
	var ruby_band := ruby_size() + RUBY_GAP
	for i in _lines.size():
		var line := _lines[i]
		var top := i * lh
		var offset := 0.0
		if alignment == HORIZONTAL_ALIGNMENT_CENTER:
			offset = maxf(0.0, (size.x - float(line["width"])) * 0.5)
		elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			offset = maxf(0.0, size.x - float(line["width"]))
		# Centre the base + ruby block inside the 1.9x line box.
		var block := ruby_band + font.get_height(font_size)
		var block_top := top + (lh - block) * 0.5
		var baseline := block_top + ruby_band + ascent
		for cell in line["cells"]:
			var x := offset + float(cell["x"])
			var w := float(cell["w"])
			var bx := x + (w - float(cell["base_w"])) * 0.5
			draw_string(font, Vector2(bx, baseline), cell["base"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			if show_ruby and cell["ruby"] != "":
				var rx := x + (w - float(cell["ruby_w"])) * 0.5
				draw_string(font, Vector2(rx, block_top + ruby_ascent), cell["ruby"], HORIZONTAL_ALIGNMENT_LEFT, -1, ruby_size(), ruby_color)
