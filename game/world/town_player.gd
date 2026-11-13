## Third-person town avatar: camera-relative movement, smooth turning, idle/walk/run clips.
## The follow camera is a separate top-level rig so it can lag smoothly behind the body.
class_name TownPlayer
extends CharacterBody3D

const WALK_SPEED := 2.4
const RUN_SPEED := 5.0
const ACCEL := 14.0
const TURN_RATE := 10.0
const GRAVITY := 18.0
const CAMERA_FOLLOW := 8.0
const CAMERA_YAW_SPEED := 2.2
const CAMERA_PITCH_DEG := -24.0
const CAMERA_DISTANCE := 7.0
const CAMERA_HEIGHT := 1.5

var actor: TownActor
var camera_rig: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
## Set false by the host (e.g. while a conversation is open) to freeze the avatar.
var controls_enabled: bool = true

var _yaw: float = 0.0
var _mouse_dragging: bool = false


func _init() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	actor = TownActor.new()
	actor.name = "Actor"
	add_child(actor)


func _ready() -> void:
	actor.setup("Rogue")
	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.top_level = true
	add_child(camera_rig)
	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = CAMERA_DISTANCE
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.2
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	spring_arm.shape = probe
	spring_arm.rotation_degrees = Vector3(CAMERA_PITCH_DEG, 0, 0)
	spring_arm.add_excluded_object(get_rid())
	camera_rig.add_child(spring_arm)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 60.0
	camera.far = 200.0
	spring_arm.add_child(camera)
	snap_camera()


## Places the camera behind the avatar immediately (no smoothing), facing `yaw` radians.
func snap_camera(yaw: float = _yaw) -> void:
	_yaw = yaw
	if camera_rig == null:
		return
	camera_rig.global_position = global_position + Vector3(0, CAMERA_HEIGHT, 0)
	camera_rig.rotation = Vector3(0, _yaw, 0)
	camera.position = Vector3(0, 0, CAMERA_DISTANCE)


## Turn the camera by a screen-space drag distance (used by the touch controls).
func rotate_camera(drag_x: float) -> void:
	_yaw -= drag_x * 0.006


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_dragging = mb.pressed
	var motion := event as InputEventMouseMotion
	if motion != null and _mouse_dragging:
		_yaw -= motion.relative.x * 0.006


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		_yaw -= Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) * CAMERA_YAW_SPEED * delta \
			if absf(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)) > 0.2 else 0.0
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, _yaw)
	var strength := minf(input.length(), 1.0)
	var running := Input.is_key_pressed(KEY_SHIFT) or (strength > 0.75 and _using_stick())
	var target_speed := (RUN_SPEED if running else WALK_SPEED) * (1.0 if strength > 0.0 else 0.0)
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.move_toward(dir.normalized() * target_speed, ACCEL * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var speed := Vector2(velocity.x, velocity.z).length()
	if dir.length_squared() > 0.01:
		var target_angle := atan2(dir.x, dir.z)
		actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, 1.0 - exp(-TURN_RATE * delta))
	if speed > 3.6:
		actor.play(TownActor.ANIM_RUN)
	elif speed > 0.4:
		actor.play(TownActor.ANIM_WALK)
	else:
		actor.play(TownActor.ANIM_IDLE)

	if camera_rig != null:
		var target := global_position + Vector3(0, CAMERA_HEIGHT, 0)
		camera_rig.global_position = camera_rig.global_position.lerp(target, 1.0 - exp(-CAMERA_FOLLOW * delta))
		camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, _yaw, 1.0 - exp(-CAMERA_FOLLOW * delta))


func _using_stick() -> bool:
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	return v.length() > 0.2
