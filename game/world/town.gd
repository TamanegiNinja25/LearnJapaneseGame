## The explorable low-poly town (Phase 2). Built in code from greybox boxes plus KayKit Forest
## and Dungeon props, like the Phase 1 screens. The host listens to `interact` / `exit_requested`
## and calls `set_unlocked()`; nothing here touches Progress or ContentDB.
## 1 unit = 1 m. North is -Z; the player starts at the south end of the main street.
class_name TownWorld
extends Node3D

## Emitted when the player presses interact next to the NPC of an unlocked location.
signal interact(location_id: String)
## Emitted on Escape / gamepad B.
signal exit_requested

## Stage that unlocks each location (read by the host).
const LOCATION_STAGE := {
	"home": "N5", "school": "N5", "shopping": "N5", "station": "N4",
	"restaurant": "N4", "office": "N3", "library": "N2", "city": "N1",
}
const LOCATION_IDS: Array[String] = [
	"home", "school", "shopping", "station", "restaurant", "office", "library", "city",
]
const DEFAULT_UNLOCKED: Array[String] = ["home", "school", "shopping"]
const TRIGGER_RADIUS := 2.5
const FONT_PATH := "res://assets/fonts/NotoSansJP-Variable.ttf"
const PROMPT_TEXT := "E：はなす"
const PLAYER_START := Vector3(0, 0, 33)

const LAYER_WORLD := 1
const LAYER_PLAYER := 2

# Palette (ART_BIBLE §2.4 / §3.3): warm neutrals, persimmon accent, slate tile roofs.
const C_GROUND := Color("#B3BA7C")
const C_PATH := Color("#E6D5B3")
const C_PATH_EDGE := Color("#CDBB98")
const C_TEXT := Color("#2B2520")
const C_SIGN := Color("#FFFDF8")
const C_LOCK := Color("#F3D9B0")
const C_DOOR := Color("#5A4636")
const C_WINDOW := Color("#6F8FA8")
const C_ROOF := Color("#4E5866")
const C_PERSIMMON := Color("#C4521F")

## Layout + look of each location. side: -1 = west of the street, +1 = east.
## size = width (along the street) x depth x wall height; roof: "gable" | "flat" | "tower".
const ZONES := {
	"home": {"ja": "自宅", "rd": "じたく", "side": -1, "z": 27.0, "size": Vector3(7, 7, 3.2), "roof": "gable",
		"wall": "#EFE3CC", "roof_color": "#4E5866", "accent": "#8A5A3B", "npc": "Mage"},
	"school": {"ja": "学校", "rd": "がっこう", "side": 1, "z": 27.0, "size": Vector3(14, 8, 7), "roof": "flat",
		"wall": "#F3EBDC", "roof_color": "#8E9AA6", "accent": "#3A6EA5", "npc": "Knight"},
	"shopping": {"ja": "商店街", "rd": "しょうてんがい", "side": -1, "z": 9.0, "size": Vector3(12, 7, 4), "roof": "flat",
		"wall": "#E8D6B5", "roof_color": "#7A6A5A", "accent": "#C4521F", "npc": "Barbarian"},
	"station": {"ja": "駅", "rd": "えき", "side": 1, "z": 9.0, "size": Vector3(14, 7, 5), "roof": "flat",
		"wall": "#D9D2C5", "roof_color": "#5B6670", "accent": "#2F7D5B", "npc": "Ranger"},
	"restaurant": {"ja": "レストラン", "side": -1, "z": -9.0, "size": Vector3(9, 7, 3.6), "roof": "gable",
		"wall": "#E9D9BF", "roof_color": "#3F4A57", "accent": "#B83A4B", "npc": "Rogue_Hooded"},
	"office": {"ja": "会社", "rd": "かいしゃ", "side": 1, "z": -9.0, "size": Vector3(10, 8, 10), "roof": "flat",
		"wall": "#C9CED3", "roof_color": "#7D8790", "accent": "#3A6EA5", "npc": "Knight"},
	"library": {"ja": "図書館", "rd": "としょかん", "side": -1, "z": -27.0, "size": Vector3(13, 9, 6), "roof": "gable",
		"wall": "#D8C3A0", "roof_color": "#5A4A3E", "accent": "#8A5A3B", "npc": "Mage"},
	"city": {"ja": "都会", "rd": "とかい", "side": 1, "z": -27.0, "size": Vector3(9, 9, 16), "roof": "tower",
		"wall": "#B9C2CC", "roof_color": "#6B7580", "accent": "#B8860B", "npc": "Ranger"},
}
const STREET_HALF_WIDTH := 2.0
const FRONTAGE_X := 13.0
const STREET_LENGTH := 84.0
const WORLD_HALF := 46.0

var player: TownPlayer
## location_id -> {"root": Node3D, "npc": TownActor, "trigger": Area3D, "barrier": StaticBody3D,
##                 "lock_label": Label3D, "sign": Label3D}
var zones: Dictionary = {}

var _unlocked: Array[String] = DEFAULT_UNLOCKED.duplicate()
var _nearby: Array[String] = []
var _font: Font
var _materials: Dictionary = {}
var _prompt_layer: CanvasLayer
var _prompt: Label
var _built: bool = false


func _ready() -> void:
	TownWorld.ensure_input_actions()
	var variation := FontVariation.new()
	variation.base_font = load(FONT_PATH) as Font
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	_font = variation
	_build_environment()
	_build_ground()
	for id in LOCATION_IDS:
		_build_zone(id)
	_build_nature()
	_build_props()
	_build_player()
	_build_prompt()
	_built = true
	_apply_unlocks()


# --- public API --------------------------------------------------------------------------------

## Unlocks exactly the given location ids; every other zone gets a barrier and a stage label.
func set_unlocked(location_ids: Array) -> void:
	_unlocked.clear()
	for id: Variant in location_ids:
		var s := String(id)
		if LOCATION_STAGE.has(s) and not _unlocked.has(s):
			_unlocked.append(s)
	if _built:
		_apply_unlocks()


func is_unlocked(location_id: String) -> bool:
	return _unlocked.has(location_id)


func get_unlocked() -> Array[String]:
	return _unlocked.duplicate()


func get_zone_ids() -> Array[String]:
	return LOCATION_IDS.duplicate()


func get_zone(location_id: String) -> Node3D:
	if not zones.has(location_id):
		return null
	return (zones[location_id] as Dictionary)["root"] as Node3D


func get_player() -> TownPlayer:
	return player


## The unlocked location whose NPC trigger the player is standing in, or "" if none.
func current_location() -> String:
	for id in _nearby:
		if is_unlocked(id):
			return id
	return ""


## What the interact button does: talk to the NPC the player is standing next to.
func try_interact() -> bool:
	var id := current_location()
	if id == "":
		return false
	return request_interact(id)


## Emits `interact` for an unlocked location (used by try_interact and by the host/tests).
func request_interact(location_id: String) -> bool:
	if not LOCATION_STAGE.has(location_id) or not is_unlocked(location_id):
		return false
	interact.emit(location_id)
	return true


## Freezes or releases player movement and hides the prompt (e.g. while a dialogue is open).
func set_controls_enabled(enabled: bool) -> void:
	if player != null:
		player.controls_enabled = enabled
	set_process_unhandled_input(enabled)
	_update_prompt()


## Adds the town's input actions if the project does not define them (project.godot untouched).
static func ensure_input_actions() -> void:
	var keys := {
		&"move_forward": [KEY_W, KEY_UP], &"move_back": [KEY_S, KEY_DOWN],
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"interact": [KEY_E], &"world_exit": [KEY_ESCAPE],
	}
	var axes := {
		&"move_forward": [JOY_AXIS_LEFT_Y, -1.0], &"move_back": [JOY_AXIS_LEFT_Y, 1.0],
		&"move_left": [JOY_AXIS_LEFT_X, -1.0], &"move_right": [JOY_AXIS_LEFT_X, 1.0],
	}
	var buttons := {&"interact": JOY_BUTTON_A, &"world_exit": JOY_BUTTON_B}
	for action: StringName in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key: int in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
		if axes.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = (axes[action] as Array)[0] as JoyAxis
			jm.axis_value = (axes[action] as Array)[1]
			InputMap.action_add_event(action, jm)
		if buttons.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = buttons[action] as JoyButton
			InputMap.action_add_event(action, jb)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and not event.is_echo():
		if try_interact():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"world_exit") and not event.is_echo():
		exit_requested.emit()
		get_viewport().set_input_as_handled()


# --- building ----------------------------------------------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#8FB8E0")
	sky_mat.sky_horizon_color = Color("#F5D2A6")
	sky_mat.ground_horizon_color = Color("#F5D2A6")
	sky_mat.ground_bottom_color = Color("#B8A68A")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color("#F2DDC2")
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#FFD9A8")
	sun.light_energy = 1.25
	# Low golden-hour sun (~24 deg) from the south-west.
	sun.rotation_degrees = Vector3(-24, -135, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.5
	add_child(sun)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = LAYER_WORLD
	add_child(ground)
	var plane := PlaneMesh.new()
	plane.size = Vector2(WORLD_HALF * 2 + 40, WORLD_HALF * 2 + 40)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = _mat(C_GROUND)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.add_child(mi)
	_add_box_collider(ground, Vector3(0, -0.5, 0), Vector3(WORLD_HALF * 2 + 40, 1, WORLD_HALF * 2 + 40))
	# Invisible edge walls keep the player inside the town.
	for s: float in [-1.0, 1.0]:
		_add_box_collider(ground, Vector3(s * WORLD_HALF, 2, 0), Vector3(1, 4, WORLD_HALF * 2))
		_add_box_collider(ground, Vector3(0, 2, s * WORLD_HALF), Vector3(WORLD_HALF * 2, 4, 1))

	# Main street (north-south) with a slightly darker kerb either side.
	_flat(Vector3(0, 0.02, 0), Vector2(STREET_HALF_WIDTH * 2, STREET_LENGTH), C_PATH)
	for s: float in [-1.0, 1.0]:
		_flat(Vector3(s * (STREET_HALF_WIDTH + 0.2), 0.015, 0), Vector2(0.4, STREET_LENGTH), C_PATH_EDGE)
	# A small square at the centre of town.
	_flat(Vector3(0, 0.018, 0), Vector2(9, 9), C_PATH_EDGE)
	_flat(Vector3(0, 0.022, 0), Vector2(8.2, 8.2), C_PATH)


func _build_zone(id: String) -> void:
	var spec: Dictionary = ZONES[id]
	var side: int = spec["side"]
	var size: Vector3 = spec["size"]
	var root := Node3D.new()
	root.name = "Zone_" + id
	root.position = Vector3(side * FRONTAGE_X, 0, float(spec["z"]))
	# Local +Z is the building front; turn it to face the street.
	root.rotation_degrees = Vector3(0, -90.0 * side, 0)
	add_child(root)
	# Side path from the street to the entrance (in world space, local z = 0 is the front).
	var path_len := FRONTAGE_X - STREET_HALF_WIDTH + 0.5
	_flat(Vector3(side * (STREET_HALF_WIDTH + path_len * 0.5 - 0.5), 0.02, float(spec["z"])),
		Vector2(path_len, 2.4), C_PATH)

	var body := StaticBody3D.new()
	body.name = "Building"
	body.collision_layer = LAYER_WORLD
	root.add_child(body)
	var wall := _mat(Color(String(spec["wall"])))
	var roof := _mat(Color(String(spec["roof_color"])))
	var accent := _mat(Color(String(spec["accent"])))
	# Main volume: front face at local z = 0.
	_box(body, Vector3(0, size.y * 0.5, -size.z * 0.5), size, wall)
	_add_box_collider(body, Vector3(0, size.y * 0.5, -size.z * 0.5), size)
	# Low stone plinth.
	_box(body, Vector3(0, 0.15, -size.z * 0.5), Vector3(size.x + 0.3, 0.3, size.z + 0.3), _mat(Color("#B5A58C")), false)
	# Door and a noren/awning strip in the accent colour above it.
	_box(body, Vector3(0, 1.1, 0.03), Vector3(1.6, 2.2, 0.1), _mat(C_DOOR), false)
	_box(body, Vector3(0, 2.45, 0.35), Vector3(size.x * 0.7, 0.18, 0.8), accent, false)
	# One window band per floor (3 m floors), split either side of the door on the ground floor.
	var floors := maxi(1, int(size.y / 3.2))
	for f in floors:
		var y := 1.6 + f * 3.2 if f > 0 else 1.5
		if f == 0:
			var w := (size.x - 3.2) * 0.5 - 0.8
			if w > 0.8:
				for s: float in [-1.0, 1.0]:
					_box(body, Vector3(s * (1.6 + 0.4 + w * 0.5), y, 0.03), Vector3(w, 1.0, 0.08), _mat(C_WINDOW), false)
		else:
			_box(body, Vector3(0, y, 0.03), Vector3(size.x - 1.4, 1.1, 0.08), _mat(C_WINDOW), false)
	match String(spec["roof"]):
		"gable":
			var prism := PrismMesh.new()
			prism.size = Vector3(size.x + 1.2, 2.0 if size.x < 10 else 2.6, size.z + 1.2)
			var rmi := MeshInstance3D.new()
			rmi.mesh = prism
			rmi.material_override = roof
			# Ridge runs along the street (local X) so the gable faces sideways, eaves face the street.
			rmi.rotation_degrees = Vector3(0, 90, 0)
			prism.size = Vector3(size.z + 1.2, prism.size.y, size.x + 1.2)
			rmi.position = Vector3(0, size.y + prism.size.y * 0.5, -size.z * 0.5)
			body.add_child(rmi)
		"flat":
			_box(body, Vector3(0, size.y + 0.15, -size.z * 0.5 + 0.3), Vector3(size.x + 0.6, 0.3, size.z + 1.2), roof)
		"tower":
			_box(body, Vector3(0, size.y + 0.2, -size.z * 0.5), Vector3(size.x + 0.4, 0.4, size.z + 0.4), roof)
			_box(body, Vector3(0, size.y + 1.4, -size.z * 0.5), Vector3(size.x * 0.5, 2.0, size.z * 0.5), roof)
	var roof_top: float = size.y + (2.6 if String(spec["roof"]) == "gable" else 0.4)

	# Sign: billboard Japanese name above the entrance.
	var sign := _label(String(spec["ja"]), 150, C_SIGN, C_TEXT)
	sign.name = "Sign"
	sign.position = Vector3(0, minf(roof_top, 4.6) + 1.2, 1.2)
	root.add_child(sign)
	# Furigana for the sign (the game's rule: every kanji carries its reading).
	if spec.has("rd"):
		var ruby := _label(String(spec["rd"]), 70, C_SIGN, C_TEXT)
		ruby.name = "SignRuby"
		ruby.position = sign.position + Vector3(0, 0.95, 0)
		root.add_child(ruby)
	var lock_label := _label(LOCATION_STAGE[id] + "でかいほう", 80, C_LOCK, C_TEXT)
	lock_label.name = "LockLabel"
	lock_label.position = sign.position + Vector3(0, -1.2, 0)
	root.add_child(lock_label)

	# NPC at the entrance, facing the street.
	var npc := TownActor.new()
	npc.name = "NPC"
	npc.position = Vector3(1.6, 0, 1.4)
	root.add_child(npc)
	npc.setup(String(spec["npc"]))
	npc.set_shadow_casting(false)
	npc.add_child(_blob_shadow())
	var trigger := Area3D.new()
	trigger.name = "Trigger"
	trigger.collision_layer = 0
	trigger.collision_mask = LAYER_PLAYER
	trigger.monitorable = false
	var tshape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = TRIGGER_RADIUS
	tshape.shape = sphere
	tshape.position = Vector3(0, 0.9, 0)
	trigger.add_child(tshape)
	npc.add_child(trigger)
	trigger.body_entered.connect(_on_trigger_entered.bind(id))
	trigger.body_exited.connect(_on_trigger_exited.bind(id))
	# Small collider so the player cannot walk through the NPC.
	var npc_body := StaticBody3D.new()
	npc_body.collision_layer = LAYER_WORLD
	_add_box_collider(npc_body, Vector3(0, 0.9, 0), Vector3(0.7, 1.8, 0.7))
	npc.add_child(npc_body)

	# Translucent barrier across the forecourt, shown while locked.
	var barrier := StaticBody3D.new()
	barrier.name = "Barrier"
	barrier.collision_layer = LAYER_WORLD
	barrier.position = Vector3(0, 0, 3.6)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.77, 0.32, 0.12, 0.28)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bmi := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(6.0, 2.4, 0.08)
	bmi.mesh = bbox
	bmi.material_override = bmat
	bmi.position = Vector3(0, 1.2, 0)
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	barrier.add_child(bmi)
	_add_box_collider(barrier, Vector3(0, 1.2, 0), Vector3(6.0, 2.4, 0.3))
	root.add_child(barrier)

	zones[id] = {"root": root, "npc": npc, "trigger": trigger, "barrier": barrier,
		"lock_label": lock_label, "sign": sign}


func _build_nature() -> void:
	var trees: Array[String] = ["Tree_1_A_Color1", "Tree_2_A_Color1", "Tree_3_A_Color1", "Tree_4_A_Color1"]
	# Street trees on the kerb between the zones.
	var i := 0
	for z: float in [-36.0, -18.0, 0.0, 18.0, 36.0]:
		for s: float in [-1.0, 1.0]:
			if absf(z) < 0.5:
				_tree(trees[i % trees.size()], Vector3(s * 5.4, 0, 3.5))
				_tree(trees[(i + 1) % trees.size()], Vector3(s * 5.4, 0, -3.5))
			else:
				_tree(trees[i % trees.size()], Vector3(s * 4.0, 0, z))
			i += 1
	# A belt of trees, bushes and rocks around the town edge (deterministic scatter).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed := 0
	var guard := 0
	while placed < 16 and guard < 500:
		guard += 1
		var p := Vector3(rng.randf_range(-WORLD_HALF + 3, WORLD_HALF - 3), 0, rng.randf_range(-WORLD_HALF + 3, WORLD_HALF - 3))
		if (absf(p.x) < 31.0 and absf(p.z) < 39.0) or absf(p.x) < 9.0:
			continue
		_tree(trees[placed % trees.size()], p, rng.randf() * TAU, rng.randf_range(0.9, 1.25))
		placed += 1
	var small: Array[String] = ["Bush_1_A_Color1", "Bush_2_A_Color1", "Rock_1_A_Color1", "Rock_2_A_Color1"]
	# Bushes and rocks dressing the building fronts and the square.
	var spots: Array[Vector3] = []
	for id in LOCATION_IDS:
		var spec: Dictionary = ZONES[id]
		var side: int = spec["side"]
		var half_w: float = (spec["size"] as Vector3).x * 0.5
		spots.append(Vector3(side * (FRONTAGE_X - 1.0), 0, float(spec["z"]) + half_w - 0.6))
		spots.append(Vector3(side * (FRONTAGE_X - 1.0), 0, float(spec["z"]) - half_w + 0.6))
	for c: Vector3 in [Vector3(3.6, 0, 3.6), Vector3(-3.6, 0, -3.6)]:
		spots.append(c)
	for k in spots.size():
		var model_name := small[k % 2] if k < spots.size() - 2 else small[2 + k % 2]
		_prop("res://assets/kaykit_forest/%s.gltf" % model_name, spots[k], rng.randf() * TAU, 1.0, 0.45)
	for k in 12:
		var p := Vector3(rng.randf_range(-WORLD_HALF + 4, WORLD_HALF - 4), 0, rng.randf_range(-WORLD_HALF + 4, WORLD_HALF - 4))
		if absf(p.x) < 28.0 and absf(p.z) < 38.0:
			continue
		_prop("res://assets/kaykit_forest/%s.gltf" % small[2 + k % 2], p, rng.randf() * TAU, rng.randf_range(1.0, 1.8), 0.6)


func _build_props() -> void:
	var dungeon := "res://assets/kaykit_dungeon/%s.gltf"
	var shop: Dictionary = ZONES["shopping"]
	var resto: Dictionary = ZONES["restaurant"]
	_prop(dungeon % "crates_stacked", Vector3(-FRONTAGE_X + 0.9, 0, float(shop["z"]) - 3.6), 0.3, 1.0, 0.8)
	_prop(dungeon % "barrel_large", Vector3(-FRONTAGE_X + 0.8, 0, float(shop["z"]) + 3.4), 0.0, 1.0, 0.5)
	_prop(dungeon % "barrel_large", Vector3(-FRONTAGE_X + 0.8, 0, float(resto["z"]) + 2.6), 0.0, 1.0, 0.5)
	_prop(dungeon % "box_small", Vector3(-FRONTAGE_X + 0.8, 0, float(resto["z"]) - 2.6), 0.6, 1.0, 0.4)


func _build_player() -> void:
	player = TownPlayer.new()
	player.position = PLAYER_START
	add_child(player)
	player.snap_camera(0.0)
	# Face up the street (north, -Z), away from the camera.
	player.actor.rotation.y = PI


func _build_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "PromptLayer"
	add_child(_prompt_layer)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.145, 0.125, 0.78)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override(&"panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -64
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.text = PROMPT_TEXT
	_prompt.add_theme_font_override(&"font", _font)
	_prompt.add_theme_font_size_override(&"font_size", 30)
	_prompt.add_theme_color_override(&"font_color", Color("#FBF6EC"))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_prompt)
	_prompt_layer.add_child(panel)
	panel.visible = false


func is_prompt_visible() -> bool:
	return _prompt != null and _prompt.get_parent().visible


# --- state -------------------------------------------------------------------------------------

func _apply_unlocks() -> void:
	for id in LOCATION_IDS:
		var z: Dictionary = zones[id]
		var open := is_unlocked(id)
		var barrier := z["barrier"] as StaticBody3D
		barrier.visible = not open
		for c in barrier.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = open
		(z["lock_label"] as Label3D).visible = not open
		(z["sign"] as Label3D).modulate = C_SIGN if open else Color("#D9CFC2")
	_update_prompt()


func _on_trigger_entered(body: Node3D, id: String) -> void:
	if body == player and not _nearby.has(id):
		_nearby.append(id)
		_update_prompt()


func _on_trigger_exited(body: Node3D, id: String) -> void:
	if body == player:
		_nearby.erase(id)
		_update_prompt()


func _update_prompt() -> void:
	if _prompt == null:
		return
	var enabled := player == null or player.controls_enabled
	_prompt.get_parent().visible = enabled and current_location() != ""


# --- helpers -----------------------------------------------------------------------------------

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic = 0.0
	_materials[key] = m
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, shadows: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Soft contact shadow for NPCs, whose meshes skip the sun shadow pass (one draw call vs ~8).
func _blob_shadow() -> MeshInstance3D:
	if not _materials.has("blob"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.17, 0.145, 0.125, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials["blob"] = m
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.01
	disc.radial_segments = 16
	disc.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = _materials["blob"]
	mi.position = Vector3(0, 0.03, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _flat(pos: Vector3, size: Vector2, color: Color) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = _mat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _add_box_collider(body: CollisionObject3D, pos: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)


func _label(text: String, size: int, color: Color, outline: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.pixel_size = 0.0085
	l.modulate = color
	l.outline_modulate = outline
	l.outline_size = 36
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.double_sided = true
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.render_priority = 2
	l.outline_render_priority = 1
	return l


func _tree(model: String, pos: Vector3, yaw: float = 0.0, scale_k: float = 1.0) -> void:
	_prop("res://assets/kaykit_forest/%s.gltf" % model, pos, yaw, scale_k, 0.45)


## Places a pack model with a simple cylinder collider of `radius` (0 = no collider).
func _prop(path: String, pos: Vector3, yaw: float, scale_k: float, radius: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * scale_k
	body.add_child(model)
	TownActor.use_nearest_filter(model)
	if radius > 0.0:
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = radius * scale_k
		cyl.height = 2.0
		shape.shape = cyl
		shape.position = Vector3(0, 1.0, 0)
		body.add_child(shape)
