## A KayKit Adventurers character (Rig_Medium) with KayKit's own Rig_Medium clips attached.
## The animation .glb files share the character skeleton's node names, so their clips play on
## any Adventurers body without retargeting. Used for both the player avatar and the NPCs.
class_name TownActor
extends Node3D

const CHARACTER_DIR := "res://assets/kaykit_adventurers/"
const ANIM_FILES: Array[String] = [
	"res://assets/kaykit_adventurers/Rig_Medium_General.glb",
	"res://assets/kaykit_adventurers/Rig_Medium_MovementBasic.glb",
]
const LOOPING: Array[String] = ["Idle_A", "Idle_B", "Walking_A", "Running_A"]

const ANIM_IDLE := "Idle_A"
const ANIM_WALK := "Walking_A"
const ANIM_RUN := "Running_A"

## Clip library shared by every actor; built once from the two animation .glb files.
static var _library: AnimationLibrary

var anim: AnimationPlayer
var model: Node3D


## `character` is a file stem in kaykit_adventurers/, e.g. "Rogue".
func setup(character: String) -> void:
	var scene: PackedScene = load(CHARACTER_DIR + character + ".glb")
	model = scene.instantiate() as Node3D
	add_child(model)
	TownActor.use_nearest_filter(model)
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	model.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library(&"", shared_library())
	play(ANIM_IDLE, 0.0)


## Turns sun shadows on/off for every mesh of the body (NPCs skip them to save draw calls).
func set_shadow_casting(enabled: bool) -> void:
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var gi := node as GeometryInstance3D
		if gi != null:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled 				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func play(clip: String, blend: float = 0.2) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if anim.current_animation == clip:
		return
	anim.play(clip, blend)


static func shared_library() -> AnimationLibrary:
	if _library != null:
		return _library
	_library = AnimationLibrary.new()
	for path in ANIM_FILES:
		var src: Node = (load(path) as PackedScene).instantiate()
		var player: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null:
			for clip_name: StringName in player.get_animation_list():
				var clip: Animation = player.get_animation(clip_name)
				if String(clip_name) in LOOPING:
					clip.loop_mode = Animation.LOOP_LINEAR
				if not _library.has_animation(clip_name):
					_library.add_animation(clip_name, clip)
		src.free()
	return _library


## KayKit packs use one small gradient atlas; linear filtering bleeds neighbouring swatches
## (ART_BIBLE §4.4), so every imported material samples it with nearest filtering.
static func use_nearest_filter(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat.roughness = 1.0
				mat.metallic = 0.0
