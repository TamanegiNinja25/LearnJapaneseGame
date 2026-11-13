extends Control
class_name TouchStick
## On-screen joystick for touch devices. Drives the move_* input actions with analogue strength,
## so anything reading Input.get_vector("move_left", "move_right", "move_forward", "move_back")
## works unchanged. Also accepts the mouse so it can be tested on desktop.

const RADIUS := 90.0
const KNOB := 38.0

var _touch := -2          # active finger index (-1 = mouse, -2 = none)
var _vector := Vector2.ZERO


func _init() -> void:
	custom_minimum_size = Vector2(RADIUS * 2 + 24, RADIUS * 2 + 24)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _center() -> Vector2:
	return size * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -2:
			_touch = t.index
			_move(t.position)
		elif not t.pressed and t.index == _touch:
			_release()
		accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch:
			_move(d.position)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _touch == -2:
			_touch = -1
			_move(event.position)
		elif not event.pressed and _touch == -1:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _touch == -1:
		_move(event.position)
		accept_event()


func _move(pos: Vector2) -> void:
	var v := (pos - _center()) / RADIUS
	_vector = v.limit_length(1.0)
	_apply()
	queue_redraw()


func _release() -> void:
	_touch = -2
	_vector = Vector2.ZERO
	_apply()
	queue_redraw()


func _apply() -> void:
	_set_action(&"move_left", maxf(0.0, -_vector.x))
	_set_action(&"move_right", maxf(0.0, _vector.x))
	_set_action(&"move_forward", maxf(0.0, -_vector.y))
	_set_action(&"move_back", maxf(0.0, _vector.y))


static func _set_action(action: StringName, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _exit_tree() -> void:
	_vector = Vector2.ZERO
	_apply()


func _draw() -> void:
	var c := _center()
	draw_circle(c, RADIUS, Color(UITheme.SURFACE, 0.55))
	draw_arc(c, RADIUS, 0.0, TAU, 64, Color(UITheme.BORDER, 0.9), 3.0, true)
	draw_circle(c + _vector * RADIUS, KNOB, Color(UITheme.PRIMARY, 0.85))
