extends Node
## Headless behavior smoke for slot-scoped Echo Chase world progress.

var _failures: Array[String] = []


# Runs public LevelModule behavior checks and exits non-zero on failure.
func _ready() -> void:
	var original_level_module := LevelModule.instance
	_test_dash_afterimages_restart_cleanly()
	_test_temporal_reset_clears_past_vfx()
	_test_start_scene_camera_layout()
	_test_present_room_delay_switch_is_immediate()
	_test_progression_device_ids_are_unique()
	_test_collectible_ids_are_unique()
	_test_progress_round_trip()
	_test_legacy_checkpoint_defaults_progress()
	LevelModule.instance = original_level_module
	if _failures.is_empty():
		print("Echo Chase architecture smoke: PASS")
		get_tree().quit()
		return
	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)


# Authored camera centers and trigger rectangles cover every occupied 480x270 room.
func _test_start_scene_camera_layout() -> void:
	var scene := load("res://Scenes/EchoChase/echo_chase_start.tscn") as PackedScene
	var root := scene.instantiate()
	var default_camera := root.get_node("World/RoomCamera/Camera2D") as Camera2D
	_expect(default_camera.position.is_equal_approx(Vector2(240.0, 808.0)), "default camera should center on room A")
	var expected_centers := {
		"A": Vector2(240.0, 808.0), "B": Vector2(720.0, 808.0), "C": Vector2(1200.0, 808.0),
		"D": Vector2(1680.0, 808.0), "E": Vector2(2160.0, 808.0), "F": Vector2(2640.0, 808.0),
		"G": Vector2(240.0, 538.0), "H": Vector2(720.0, 538.0), "I": Vector2(1200.0, 538.0),
		"J": Vector2(1680.0, 538.0), "K": Vector2(720.0, 1078.0), "L": Vector2(1200.0, 1078.0),
		"M": Vector2(1680.0, 1078.0), "N": Vector2(2160.0, 1078.0), "O": Vector2(2640.0, 1078.0),
		"P": Vector2(720.0, 1348.0), "Q": Vector2(1200.0, 1348.0), "R": Vector2(1680.0, 1348.0),
		"S": Vector2(2160.0, 1348.0),
	}
	var cameras := root.get_node("World/RoomCameras") as Node2D
	var triggers := root.get_node("World/RoomCameraTriggers") as Node2D
	_expect(cameras.get_child_count() == expected_centers.size(), "room camera count should match authored rooms")
	_expect(triggers.get_child_count() == expected_centers.size(), "room trigger count should match authored rooms")
	for suffix in expected_centers:
		var center: Vector2 = expected_centers[suffix]
		var area := root.get_node("World/RoomCameraTriggers/RoomArea%s" % suffix) as Area2D
		var shape := area.get_node("CollisionShape2D") as CollisionShape2D
		var rectangle := shape.shape as RectangleShape2D
		_expect(area.global_position.is_equal_approx(center), "room trigger %s should use the authored room center" % suffix)
		_expect(rectangle.size.is_equal_approx(Vector2(480.0, 270.0)), "room trigger %s should cover one room" % suffix)
		var camera := root.get_node("World/RoomCameras/RoomPcam%s" % suffix) as Node2D
		_expect(camera.global_position.is_equal_approx(center), "room camera %s should align with its trigger" % suffix)
		_expect(camera.get("limit_target") == NodePath("../../RoomCameraTriggers/RoomArea%s/CollisionShape2D" % suffix), "room camera %s should use its trigger limits" % suffix)
		_expect(area.get("area_pcam") == camera, "room trigger %s should activate its camera" % suffix)
	root.free()


# A failure reset must remove both the Past body and any departure snapshot.
func _test_temporal_reset_clears_past_vfx() -> void:
	var past_echo := EchoTimeline.past_echo
	past_echo.show()
	past_echo.departure_vfx.show()
	EchoTimeline.reset_timeline()
	_expect(not past_echo.visible, "timeline reset should hide the Past echo")
	_expect(not past_echo.departure_vfx.is_playing(), "timeline reset should stop Past departure VFX")

# A second dash must not inherit image slots from the first dash's world position.
func _test_dash_afterimages_restart_cleanly() -> void:
	var vfx_scene := load("res://Scenes/EchoChase/Prefabs/echo_dash_vfx.tscn") as PackedScene
	var source := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", GradientTexture2D.new())
	source.sprite_frames = frames
	source.animation = &"idle"
	add_child(source)
	var vfx := vfx_scene.instantiate() as EchoDashVfx
	add_child(vfx)
	source.global_position = Vector2(24.0, 48.0)
	vfx.begin(source, Vector2.RIGHT)
	vfx.finish(source.global_position, Vector2.RIGHT)
	source.global_position = Vector2(144.0, 48.0)
	vfx.begin(source, Vector2.RIGHT)
	var afterimage_a := vfx.get_node("Afterimages/AfterimageA") as Sprite2D
	var afterimage_b := vfx.get_node("Afterimages/AfterimageB") as Sprite2D
	_expect(afterimage_a.global_position.is_equal_approx(source.global_position), "new dash afterimage should use the new world position")
	_expect(afterimage_b.texture == null, "new dash should not reuse the previous dash image slot")
	vfx.free()
	source.free()


# One authored device ID activates once and emits once.
func _test_progression_device_ids_are_unique() -> void:
	var module := LevelModule.new()
	if not _require_progress_api(module):
		return
	var emitted_ids: Array[String] = []
	module.progression_device_activated.connect(func(device_id: String) -> void:
		emitted_ids.append(device_id)
	)
	_expect(module.activate_progression_device("short_route"), "first device activation should succeed")
	_expect(not module.activate_progression_device("short_route"), "duplicate device activation should be ignored")
	_expect(module.is_progression_device_active("short_route"), "activated device should be queryable")
	_expect(emitted_ids == ["short_route"], "device activation signal should emit once")


# One collectible ID is stored once and emits once.
func _test_collectible_ids_are_unique() -> void:
	var module := LevelModule.new()
	var api_available := (
		module.has_signal("collectible_collected")
		and module.has_method("collect_item")
		and module.has_method("is_item_collected")
	)
	_expect(api_available, "LevelModule collectible API should exist")
	if not api_available:
		return
	var emitted_ids: Array[String] = []
	module.collectible_collected.connect(func(item_id: String) -> void:
		emitted_ids.append(item_id)
	)
	_expect(module.collect_item("memory_shard_a"), "first collectible should be stored")
	_expect(not module.collect_item("memory_shard_a"), "duplicate collectible should be ignored")
	_expect(module.is_item_collected("memory_shard_a"), "collected item should be queryable")
	_expect(emitted_ids == ["memory_shard_a"], "collectible signal should emit once")


# Collected slot data restores checkpoint and permanent world progress together.
func _test_progress_round_trip() -> void:
	var source := LevelModule.new()
	if not _require_progress_api(source):
		return
	source.set_checkpoint("res://map.tscn", "hub", Vector2(24.0, 48.0), 5.0, "delay_5s")
	source.activate_progression_device("long_route")
	source.collect_item("memory_shard_a")
	_expect(source.unlock_present_hub(), "first present hub unlock should succeed")
	_expect(not source.unlock_present_hub(), "present hub unlock should be idempotent")
	var restored := LevelModule.new()
	restored.apply_data(source.collect_data())
	_expect(restored.get_checkpoint().get("checkpoint_id", "") == "hub", "checkpoint should survive round-trip")
	_expect(restored.is_progression_device_active("long_route"), "device state should survive round-trip")
	_expect(restored.is_item_collected("memory_shard_a"), "collectible state should survive round-trip")
	_expect(restored.is_present_hub_unlocked(), "present hub state should survive round-trip")


# Saves from the checkpoint-only schema remain valid with empty new progress.
func _test_legacy_checkpoint_defaults_progress() -> void:
	var module := LevelModule.new()
	if not _require_progress_api(module):
		return
	module.apply_data({
		"checkpoint_scene_path": "res://legacy_map.tscn",
		"checkpoint_id": "legacy_checkpoint",
		"checkpoint_position": {"x": 10.0, "y": 20.0},
		"past_delay_seconds": 3.0,
		"delay_switch_id": "delay_3s",
	})
	_expect(module.has_continue_point(), "legacy checkpoint should remain valid")
	_expect(not module.is_progression_device_active("missing"), "legacy progress should default empty")
	_expect(not module.is_item_collected("missing"), "legacy collectibles should default empty")
	_expect(not module.is_present_hub_unlocked(), "legacy present hub state should default locked")


# Present rooms suppress phase warning and keep the selected delay for the next run.
func _test_present_room_delay_switch_is_immediate() -> void:
	var timeline_scene := load("res://Scenes/Autoload/echo_timeline_controller.tscn") as PackedScene
	var timeline := timeline_scene.instantiate()
	add_child(timeline)
	var api_available := (
		timeline.has_method("enter_present_room")
		and timeline.has_method("leave_present_room")
		and timeline.has_method("is_present_room_active")
		and timeline.has_signal("present_room_changed")
	)
	_expect(api_available, "EchoTimeline present-room API should exist")
	if not api_available:
		return
	var switch_started_count := 0
	var changed_delays: Array[float] = []
	var on_switch_started := func(_seconds: float, _switch_id: StringName) -> void:
		switch_started_count += 1
	var on_delay_changed := func(seconds: float, _switch_id: StringName) -> void:
		changed_delays.append(seconds)
	timeline.past_delay_switch_started.connect(on_switch_started)
	timeline.past_delay_changed.connect(on_delay_changed)
	timeline.reset_timeline(3.0, &"delay_3s")
	timeline.enter_present_room()
	_expect(timeline.is_present_room_active(), "enter_present_room should activate the present state")
	_expect(timeline.request_past_delay(5.0, &"delay_5s"), "present room should accept a new delay")
	_expect(switch_started_count == 0, "present room delay should skip phase warning")
	_expect(changed_delays.has(5.0), "present room delay should apply immediately")
	timeline.leave_present_room()
	_expect(not timeline.is_present_room_active(), "leave_present_room should resume a new timeline")
	timeline.past_delay_switch_started.disconnect(on_switch_started)
	timeline.past_delay_changed.disconnect(on_delay_changed)
	timeline.free()


# Records one failed behavior without stopping later checks.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# Stops one test cleanly when the requested public API is not implemented yet.
func _require_progress_api(module: LevelModule) -> bool:
	var available := (
		module.has_signal("progression_device_activated")
		and module.has_method("activate_progression_device")
		and module.has_method("is_progression_device_active")
		and module.has_method("unlock_present_hub")
		and module.has_method("is_present_hub_unlocked")
	)
	_expect(available, "LevelModule permanent progression API should exist")
	return available
