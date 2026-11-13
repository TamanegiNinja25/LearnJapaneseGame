extends ScreenBase
## 町: the explorable 3D town (game/world/town.tscn) inside the menu. Locations unlock by stage
## (TownWorld.LOCATION_STAGE); talking to a location's NPC opens the matching activity:
## scenarios for that place, the dictionary at the library, review at home, grammar at school.

const TOWN_SCENE := "res://world/town.tscn"
const LOCATION_JA := {"home": "自宅", "school": "学校", "shopping": "商店街", "station": "駅",
	"restaurant": "レストラン", "office": "会社", "library": "図書館", "city": "都会"}

var _town: Node


func _ready() -> void:
	if not ResourceLoader.exists(TOWN_SCENE):
		make_column()
		column.add_child(UITheme.ja("{町|まち}のデータがありません。", UITheme.SIZE_BODY))
		return
	# The menus run in low-processor mode (redraw only on change). The 3D town must redraw
	# every frame, otherwise its SubViewport is never presented on some devices.
	OS.low_processor_usage_mode = false
	tree_exiting.connect(func() -> void: OS.low_processor_usage_mode = true)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	var vp := SubViewport.new()
	vp.handle_input_locally = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# MSAA on a SubViewport fails silently on many GLES3 (Compatibility) Android GPUs: the
	# viewport renders nothing. Only enable it on the desktop renderers.
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		vp.msaa_3d = Viewport.MSAA_2X
	container.add_child(vp)
	_town = (load(TOWN_SCENE) as PackedScene).instantiate()
	vp.add_child(_town)
	_town.call("set_unlocked", _unlocked())
	_town.connect("interact", _on_interact)
	_town.connect("exit_requested", func() -> void: go(&"dashboard"))
	container.focus_mode = Control.FOCUS_ALL
	container.call_deferred("grab_focus")

	var hud := UITheme.card(Color(UITheme.SURFACE, 0.92), UITheme.BORDER)
	hud.position = Vector2(16, 16)
	hud.custom_minimum_size.x = 620
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var v := UITheme.vbox(4)
	hud.add_child(v)
	v.add_child(UITheme.ja("{町|まち}を{歩|ある}いて、{人|ひと}に{話|はな}しかけましょう。", UITheme.SIZE_LABEL))
	var touch: bool = DisplayServer.is_touchscreen_available() or args.get("touch", false)
	if Progress.show_english():
		var hint := "Joystick to walk · drag the right side to look · 話す to talk" if touch 			else "WASD / stick to walk · Shift to run · E / Ⓐ to talk · Esc to leave"
		v.add_child(UITheme.en(hint, UITheme.SIZE_LABEL))
	if touch:
		_add_touch_controls()


## Phone/tablet controls: joystick (bottom left), camera drag (right half), talk and exit buttons.
func _add_touch_controls() -> void:
	var look := Control.new()
	look.anchor_left = 0.5
	look.anchor_right = 1.0
	look.anchor_top = 0.0
	look.anchor_bottom = 1.0
	look.mouse_filter = Control.MOUSE_FILTER_PASS
	look.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenDrag:
			var player: Node = _town.call("get_player")
			if player:
				player.call("rotate_camera", (e as InputEventScreenDrag).relative.x))
	add_child(look)

	var stick := TouchStick.new()
	stick.anchor_left = 0.0
	stick.anchor_top = 1.0
	stick.anchor_bottom = 1.0
	stick.offset_left = 24
	stick.offset_top = -stick.custom_minimum_size.y - 24
	stick.offset_right = 24 + stick.custom_minimum_size.x
	stick.offset_bottom = -24
	add_child(stick)

	var talk := UITheme.button("話す")
	talk.custom_minimum_size = Vector2(140, 96)
	talk.anchor_left = 1.0
	talk.anchor_right = 1.0
	talk.anchor_top = 1.0
	talk.anchor_bottom = 1.0
	talk.offset_left = -164
	talk.offset_top = -120
	talk.offset_right = -24
	talk.offset_bottom = -24
	talk.pressed.connect(func() -> void: _town.call("try_interact"))
	add_child(talk)

	var leave := UITheme.button("ホームへ", false)
	leave.anchor_left = 1.0
	leave.anchor_right = 1.0
	leave.offset_left = -180
	leave.offset_top = 16
	leave.offset_right = -16
	leave.offset_bottom = 64
	leave.pressed.connect(func() -> void: go(&"dashboard"))
	add_child(leave)


func _unlocked() -> Array:
	var stage_index := Mastery.STAGES.find(Progress.stage)
	var out: Array = []
	var table: Dictionary = _town.get("LOCATION_STAGE")
	for id: String in table:
		if Mastery.STAGES.find(StringName(table[id])) <= stage_index:
			out.append(id)
	return out


func _on_interact(location_id: String) -> void:
	match location_id:
		"home":
			go(&"review")
		"school":
			go(&"grammar")
		"library":
			go(&"dictionary")
		_:
			go(&"conversation", {"location": LOCATION_JA.get(location_id, ""), "from_town": true})


func _unhandled_input(event: InputEvent) -> void:
	# The town handles its own keys (Esc emits exit_requested); skip ScreenBase shortcuts.
	pass
