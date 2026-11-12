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
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	var vp := SubViewport.new()
	vp.handle_input_locally = true
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
	if Progress.show_english():
		v.add_child(UITheme.en("WASD / stick to walk · Shift to run · E / Ⓐ to talk · Esc to leave", UITheme.SIZE_LABEL))


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
