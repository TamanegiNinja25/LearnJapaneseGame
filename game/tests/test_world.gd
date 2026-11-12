# Headless tests for the 3D town scene (game/world/town.tscn). Run from the repo root with:
#   godot --headless --path game --import          (once, on a fresh checkout)
#   godot --headless --path game --script res://tests/test_world.gd
# Exit code is 0 only when every test passes.
extends SceneTree

var passed := 0
var failed := 0
var town: Node3D

const TESTS: Array[String] = [
	"test_zones_exist",
	"test_default_unlocks",
	"test_set_unlocked",
	"test_player_exists",
	"test_interact_signal",
	"test_trigger_proximity",
	"test_exit_signal",
]


func _initialize() -> void:
	await process_frame
	var scene: PackedScene = load("res://world/town.tscn")
	town = scene.instantiate() as Node3D
	root.add_child(town)
	await process_frame
	await physics_frame
	for t in TESTS:
		var ok: Variant = await call(t)
		if ok != true:
			failed += 1
			push_error("FAIL %s: did not finish (runtime error?)" % t)
	town.queue_free()
	await process_frame
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s: expected %s, got %s" % [label, expected, actual])


func assert_true(cond: bool, label: String) -> void:
	assert_eq(cond, true, label)


func test_zones_exist() -> bool:
	assert_true(town is TownWorld, "root is a TownWorld")
	var ids: Array = town.get_zone_ids()
	assert_eq(ids.size(), 8, "eight location zones")
	for id: String in ["home", "school", "shopping", "station", "restaurant", "office", "library", "city"]:
		var zone: Node3D = town.get_zone(id)
		assert_true(zone != null and zone.is_inside_tree(), "zone %s is in the tree" % id)
		assert_true(TownWorld.LOCATION_STAGE.has(id), "stage defined for %s" % id)
		var sign := zone.get_node_or_null("Sign") as Label3D
		assert_true(sign != null and sign.text != "", "zone %s has a sign" % id)
		assert_true(zone.get_node_or_null("NPC/Trigger") is Area3D, "zone %s has an NPC trigger" % id)
	assert_eq(town.get_zone("nowhere"), null, "unknown zone is null")
	return true


func test_default_unlocks() -> bool:
	assert_true(town.is_unlocked("home"), "home unlocked by default")
	assert_true(town.is_unlocked("school"), "school unlocked by default")
	assert_true(town.is_unlocked("shopping"), "shopping unlocked by default")
	assert_true(not town.is_unlocked("station"), "station locked by default")
	var barrier := town.get_zone("station").get_node("Barrier") as Node3D
	assert_true(barrier.visible, "locked zone shows its barrier")
	var lock_label := town.get_zone("station").get_node("LockLabel") as Label3D
	assert_true(lock_label.visible and lock_label.text == "N4で解放", "locked zone shows N4で解放")
	assert_true(not (town.get_zone("home").get_node("Barrier") as Node3D).visible, "unlocked zone has no barrier")
	return true


func test_set_unlocked() -> bool:
	town.set_unlocked(["home", "station", "bogus"])
	assert_true(town.is_unlocked("station"), "station unlocked after set_unlocked")
	assert_true(not town.is_unlocked("school"), "school locked after set_unlocked")
	assert_true(not town.is_unlocked("bogus"), "unknown id ignored")
	assert_true(not (town.get_zone("station").get_node("Barrier") as Node3D).visible, "station barrier hidden")
	assert_true((town.get_zone("school").get_node("Barrier") as Node3D).visible, "school barrier shown")
	assert_true((town.get_zone("school").get_node("LockLabel") as Label3D).visible, "school lock label shown")
	town.set_unlocked(TownWorld.DEFAULT_UNLOCKED)
	assert_eq(town.get_unlocked().size(), 3, "back to defaults")
	return true


func test_player_exists() -> bool:
	var player: Node = town.get_player()
	assert_true(player is CharacterBody3D, "player is a CharacterBody3D")
	assert_true(town.get_node_or_null("Player") == player, "player node is named Player")
	assert_true(player.get_node_or_null("CameraRig/SpringArm3D/Camera3D") is Camera3D, "follow camera exists")
	var anim := (player as TownPlayer).actor.anim
	assert_true(anim != null and anim.has_animation("Idle_A") and anim.has_animation("Walking_A") \
		and anim.has_animation("Running_A"), "player has idle/walk/run clips")
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "interact"]:
		assert_true(InputMap.has_action(action), "input action %s exists" % action)
	return true


func test_interact_signal() -> bool:
	var got: Array[String] = []
	var cb := func(id: String) -> void: got.append(id)
	town.interact.connect(cb)
	assert_true(town.request_interact("home"), "interact with unlocked home")
	assert_true(not town.request_interact("library"), "locked library refuses")
	assert_true(not town.request_interact("bogus"), "unknown id refuses")
	assert_eq(got, ["home"] as Array[String], "interact fired once with home")
	town.interact.disconnect(cb)
	return true


func test_trigger_proximity() -> bool:
	var got: Array[String] = []
	var cb := func(id: String) -> void: got.append(id)
	town.interact.connect(cb)
	var player: TownPlayer = town.get_player()
	player.controls_enabled = false
	assert_true(not town.try_interact(), "nothing to talk to at the start")
	# Stand next to the school NPC (unlocked) and let physics register the overlap.
	var npc := town.get_zone("school").get_node("NPC") as Node3D
	player.global_position = npc.global_position + Vector3(0, 0.05, 0)
	player.controls_enabled = true
	for i in 6:
		await physics_frame
	assert_eq(town.current_location(), "school", "player is inside the school trigger")
	assert_true(town.is_prompt_visible(), "prompt shown near an unlocked NPC")
	assert_true(town.try_interact(), "try_interact succeeds near school")
	assert_eq(got, ["school"] as Array[String], "interact fired with school")
	# Next to a locked NPC nothing triggers.
	var locked_npc := town.get_zone("office").get_node("NPC") as Node3D
	player.global_position = locked_npc.global_position + Vector3(0, 0.05, 0)
	for i in 6:
		await physics_frame
	assert_eq(town.current_location(), "", "locked NPC does not trigger")
	assert_true(not town.is_prompt_visible(), "no prompt at a locked NPC")
	town.interact.disconnect(cb)
	return true


func test_exit_signal() -> bool:
	var fired := [false]
	var cb := func() -> void: fired[0] = true
	town.exit_requested.connect(cb)
	var ev := InputEventAction.new()
	ev.action = &"world_exit"
	ev.pressed = true
	town._unhandled_input(ev)
	assert_true(fired[0], "exit_requested fires on world_exit")
	town.exit_requested.disconnect(cb)
	return true
