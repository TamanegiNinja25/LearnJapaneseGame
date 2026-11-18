extends Control
class_name WritingPad
## Square writing pad for kanji practice. The player draws strokes with a finger or the mouse;
## each finished stroke is emitted in KanjiVG's 109 x 109 box for StrokeMatch to judge.
##
## Draws, back to front: the paper with a dashed guide cross, the faint model (tracing mode),
## the accepted strokes (drawn from the model, so they look clean), a hint for the next stroke,
## a red flash of a rejected stroke, and the stroke in progress. play_demo() animates the
## stroke order. Touch arrives as emulated mouse events (Godot's default), so only mouse input
## is handled; a drag on the pad never scrolls the page.

signal stroke_drawn(points: PackedVector2Array)

const BOX := 109.0

## The kanji's strokes in writing order (109 box).
var model: Array[PackedVector2Array] = []
## Strokes already written correctly.
var done_count: int = 0
## Show the whole model faintly underneath (なぞる mode).
var show_guide: bool = true
## Index of a stroke to highlight with its start point, or -1.
var hint_stroke: int = -1
var enabled: bool = true

var _current := PackedVector2Array()
var _drawing := false
var _wrong := PackedVector2Array()
var _wrong_alpha := 0.0
var _demo_t := -1.0  # strokes shown so far during play_demo(), fractional; -1 = no demo
var _demo_tween: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_CROSS


func _ready() -> void:
	# Screens make controls pass input to their scroll containers; the pad must keep its drags.
	mouse_filter = Control.MOUSE_FILTER_STOP


## Show a new kanji and clear everything drawn.
func set_model(strokes: Array[PackedVector2Array], guide: bool) -> void:
	model = strokes
	show_guide = guide
	done_count = 0
	hint_stroke = -1
	_current = PackedVector2Array()
	_wrong = PackedVector2Array()
	_stop_demo()
	queue_redraw()


func accept_stroke() -> void:
	done_count = mini(done_count + 1, model.size())
	hint_stroke = -1
	queue_redraw()


## Flash the rejected stroke (box coordinates) in red, fading out.
func reject_stroke(points_box: PackedVector2Array) -> void:
	_wrong = points_box
	_wrong_alpha = 1.0
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void:
		_wrong_alpha = a
		queue_redraw(), 1.0, 0.0, 0.7)


## Animate the stroke order once, over [param seconds_per_stroke] per stroke.
func play_demo(seconds_per_stroke: float = 0.45) -> void:
	if model.is_empty():
		return
	_stop_demo()
	_demo_t = 0.0
	_demo_tween = create_tween()
	_demo_tween.tween_method(func(t: float) -> void:
		_demo_t = t
		queue_redraw(), 0.0, float(model.size()), seconds_per_stroke * model.size())
	_demo_tween.tween_interval(0.6)
	_demo_tween.tween_callback(_stop_demo)


func _stop_demo() -> void:
	if _demo_tween and _demo_tween.is_valid():
		_demo_tween.kill()
	_demo_t = -1.0
	queue_redraw()


func side() -> float:
	return minf(size.x, size.y)


func _origin() -> Vector2:
	return (size - Vector2(side(), side())) * 0.5


func _to_pad(p: Vector2) -> Vector2:
	return _origin() + p * (side() / BOX)


func _to_box(p: Vector2) -> Vector2:
	return (p - _origin()) * (BOX / maxf(1.0, side()))


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_stop_demo()
			_drawing = true
			_current = PackedVector2Array([_to_box(mb.position)])
		elif _drawing:
			_drawing = false
			var finished := _current
			_current = PackedVector2Array()
			queue_redraw()
			stroke_drawn.emit(finished)
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm and _drawing:
		var p := _to_box(mm.position)
		if _current.is_empty() or _current[_current.size() - 1].distance_to(p) > 0.6:
			_current.append(p)
			queue_redraw()
		accept_event()


func _draw() -> void:
	var s := side()
	var o := _origin()
	var rect := Rect2(o, Vector2(s, s))
	draw_style_box(UITheme._card(UITheme.SURFACE, UITheme.BORDER), rect)
	var mid := o + Vector2(s, s) * 0.5
	draw_dashed_line(Vector2(o.x + 12, mid.y), Vector2(o.x + s - 12, mid.y), UITheme.BORDER, 2.0, 10.0)
	draw_dashed_line(Vector2(mid.x, o.y + 12), Vector2(mid.x, o.y + s - 12), UITheme.BORDER, 2.0, 10.0)
	var ink_w := s * 0.045
	if _demo_t >= 0.0:
		for i in model.size():
			var part := clampf(_demo_t - i, 0.0, 1.0)
			if part > 0.0:
				_stroke(_partial(model[i], part), UITheme.TEXT_PRIMARY, ink_w)
		return
	if show_guide:
		# Translucent colours darken where the round joints overlap, so faint strokes are drawn
		# with solid colours mixed towards the paper instead.
		var guide := UITheme.SURFACE.lerp(UITheme.TEXT_DISABLED, 0.45)
		for i in range(done_count, model.size()):
			_stroke(model[i], guide, ink_w)
	for i in mini(done_count, model.size()):
		_stroke(model[i], UITheme.TEXT_PRIMARY, ink_w)
	var next := hint_stroke if hint_stroke >= 0 else (done_count if show_guide else -1)
	if next >= 0 and next < model.size():
		if hint_stroke >= 0:
			_stroke(model[next], UITheme.SURFACE.lerp(UITheme.PRIMARY, 0.55), ink_w)
		draw_circle(_to_pad(model[next][0]), ink_w * 0.75, UITheme.PRIMARY)
	if _wrong_alpha > 0.0 and _wrong.size() > 1:
		_stroke(_wrong, UITheme.SURFACE.lerp(UITheme.INCORRECT, _wrong_alpha), ink_w * 0.8)
	if _current.size() > 1:
		_stroke(_current, UITheme.PRIMARY, ink_w * 0.8)


## The first [param part] (0..1) of a stroke, by length.
func _partial(pts: PackedVector2Array, part: float) -> PackedVector2Array:
	if part >= 1.0:
		return pts
	var target := StrokeMatch.length(pts) * part
	var out := PackedVector2Array([pts[0]])
	var walked := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if walked + seg >= target:
			out.append(pts[i - 1].lerp(pts[i], (target - walked) / maxf(seg, 0.001)))
			return out
		walked += seg
		out.append(pts[i])
	return out


func _stroke(box_pts: PackedVector2Array, color: Color, width: float) -> void:
	if box_pts.size() < 2:
		return
	var pts := PackedVector2Array()
	for p in box_pts:
		pts.append(_to_pad(p))
	draw_polyline(pts, color, width, true)
	# Round caps and joints: the brush-pen look, and no gaps where segments meet.
	for p in pts:
		draw_circle(p, width * 0.5, color)
