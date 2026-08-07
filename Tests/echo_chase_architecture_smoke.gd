extends Node
## Headless behavior smoke for slot-scoped Echo Chase world progress.

const PROGRESSION_SHORTCUT_SCENE := preload("res://Scenes/EchoChase/Prefabs/progression_shortcut.tscn")

var _failures: Array[String] = []


# Runs public LevelModule behavior checks and exits non-zero on failure.
func _ready() -> void:
	var original_level_module := LevelModule.instance
	_test_dash_afterimages_restart_cleanly()
	_test_temporal_reset_clears_past_vfx()
	_test_present_departure_vfx_finishes_cleanly()
	_test_start_scene_camera_layout()
	_test_present_room_ambient_vfx()
	_test_present_room_delay_switch_is_immediate()
	_test_progression_device_ids_are_unique()
	_test_progression_shortcut_follows_device()
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


# Every authored room trigger pairs with a camera that follows it; no room counts
# or coordinates are locked so the author can freely add, move, or remove rooms.
func _test_start_scene_camera_layout() -> void:
	var scene := load("res://Scenes/EchoChase/echo_chase_start.tscn") as PackedScene
	var root := scene.instantiate()
	var present_time_label := root.get_node("World/PresentHub/Label") as Label
	var final_time_label := root.get_node("World/Finnal/Label") as Label
	var pause_time_label := root.get_node("UI/PauseScreen/PanelRoot/RunCountdownLabel") as Label
	_expect(present_time_label.text == "30:00", "PresentHub should author the run countdown label")
	_expect(final_time_label.text == "30:00", "Finnal should author the run countdown label")
	_expect(pause_time_label.text == "30:00", "pause screen should author the run countdown label")
	var cameras := root.get_node("World/RoomCameras") as Node2D
	var triggers := root.get_node("World/RoomCameraTriggers") as Node2D
	_expect(cameras.get_child_count() > 0, "scene should author at least one room camera")
	_expect(cameras.get_child_count() == triggers.get_child_count(), "each room trigger should pair with a camera")
	var referenced_camera_ids: Dictionary = {}
	for index in range(triggers.get_child_count()):
		var area := triggers.get_child(index) as Area2D
		_expect(area is Area2D, "every room trigger should be an Area2D")
		var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_expect(shape_node is CollisionShape2D, "every room trigger should own a CollisionShape2D")
		_expect(shape_node != null and shape_node.shape is RectangleShape2D, "every room trigger should use a rectangular camera bounds")
		var camera = area.get("area_pcam")
		_expect(camera is Node2D and cameras.is_ancestor_of(camera), "every room trigger should point at a camera under RoomCameras")
		if not (camera is Node2D):
			continue
		var camera_id: int = camera.get_instance_id()
		_expect(not referenced_camera_ids.has(camera_id), "each room trigger should use a distinct room camera")
		referenced_camera_ids[camera_id] = true
		_expect(camera.global_position.is_equal_approx(area.global_position), "every room camera should align with its trigger")
		var limit_path = camera.get("limit_target")
		_expect(limit_path is NodePath and camera.get_node_or_null(limit_path) == shape_node, "every room camera should bound its own trigger shape")
	for camera in cameras.get_children():
		_expect(referenced_camera_ids.has(camera.get_instance_id()), "every authored room camera should be bound to a room trigger")
	root.free()


# PresentHub starts quiet until the saved central-room conversion is complete.
func _test_present_room_ambient_vfx() -> void:
	var scene := load("res://Scenes/EchoChase/echo_chase_start.tscn") as PackedScene
	var root := scene.instantiate()
	var particles := root.get_node("World/PresentHub/AmbientParticles") as GPUParticles2D
	var glow := root.get_node("World/PresentHub/AmbientGlow") as Polygon2D
	_expect(not particles.emitting, "locked PresentHub ambient particles should be idle")
	_expect(not glow.visible, "locked PresentHub ambient glow should be hidden")
	_expect(particles.process_mode == Node.PROCESS_MODE_ALWAYS, "PresentHub ambient particles should continue during dialogue pause")
	root.free()


# A failure reset must remove both the Past body and any departure snapshot.
func _test_temporal_reset_clears_past_vfx() -> void:
	var past_echo := EchoTimeline.past_echo
	past_echo.show()
	past_echo.visual.show()
	past_echo.outline_visual.show()
	past_echo.dissipate()
	_expect(not past_echo.visual.visible, "Past dissipate should keep the body hidden")
	past_echo.departure_vfx.animation_player.advance(0.3)
	_expect(not past_echo.visible, "Past should hide after its departure VFX finishes")
	past_echo.departure_vfx.show()
	EchoTimeline.reset_timeline()
	_expect(not past_echo.visible, "timeline reset should hide the Past echo")
	_expect(not past_echo.departure_vfx.is_playing(), "timeline reset should stop Past departure VFX")


# A present-room shockwave must finish with both its active flag and visuals cleared.
func _test_present_departure_vfx_finishes_cleanly() -> void:
	var vfx_scene := load("res://Scenes/EchoChase/Prefabs/temporal_departure_vfx.tscn") as PackedScene
	var vfx := vfx_scene.instantiate() as TemporalDepartureVfx
	add_child(vfx)
	vfx.play_room_departure()
	vfx.animation_player.advance(0.7)
	_expect(not vfx.is_playing(), "present-room departure VFX should stop after its authored animation")
	_expect(not vfx.visible, "present-room departure VFX should hide after its authored animation")
	vfx.free()

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


# A branch shortcut starts solid and clears only for its matching device ID.
func _test_progression_shortcut_follows_device() -> void:
	var original_level_module := LevelModule.instance
	var module := LevelModule.new()
	LevelModule.instance = module
	var shortcut := PROGRESSION_SHORTCUT_SCENE.instantiate() as ProgressionShortcut
	shortcut.required_device_id = &"shortcut_test"
	add_child(shortcut)
	_expect(not shortcut.is_open(), "progression shortcut starts closed")
	module.activate_progression_device("other_device")
	_expect(not shortcut.is_open(), "progression shortcut ignores other device IDs")
	module.activate_progression_device("shortcut_test")
	_expect(shortcut.is_open(), "progression shortcut opens for its matching device")
	_expect(shortcut.animation_player.current_animation == &"open", "progression shortcut plays its fade animation")
	shortcut.free()
	LevelModule.instance = original_level_module


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
	source.open_latched_door("delay_5s_latched_1")
	source.commit_latched_doors()
	_expect(source.unlock_present_hub(), "first present hub unlock should succeed")
	_expect(not source.unlock_present_hub(), "present hub unlock should be idempotent")
	_expect(source.mark_run_countdown_expired(), "first run countdown expiration should be stored")
	_expect(not source.mark_run_countdown_expired(), "run countdown expiration should be idempotent")
	var restored := LevelModule.new()
	restored.apply_data(source.collect_data())
	_expect(restored.get_checkpoint().get("checkpoint_id", "") == "hub", "checkpoint should survive round-trip")
	_expect(restored.is_progression_device_active("long_route"), "device state should survive round-trip")
	_expect(restored.is_item_collected("memory_shard_a"), "collectible state should survive round-trip")
	_expect(restored.is_latched_door_open("delay_5s_latched_1"), "latched door state should survive round-trip")
	_expect(restored.is_present_hub_unlocked(), "present hub state should survive round-trip")
	_expect(restored.get_collected_item_count() == 1, "collected item count should survive round-trip")
	_expect(restored.has_run_countdown_expired(), "run countdown expiration should survive round-trip")


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
	_expect(not module.is_latched_door_open("missing"), "legacy latched doors should default closed")
	_expect(not module.is_present_hub_unlocked(), "legacy present hub state should default locked")
	_expect(not module.has_run_countdown_expired(), "legacy run countdown state should default active")


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
		and module.has_method("open_latched_door")
		and module.has_method("is_latched_door_open")
		and module.has_method("unlock_present_hub")
		and module.has_method("is_present_hub_unlocked")
		and module.has_method("get_collected_item_count")
		and module.has_method("mark_run_countdown_expired")
		and module.has_method("has_run_countdown_expired")
	)
	_expect(available, "LevelModule permanent progression API should exist")
	return available
