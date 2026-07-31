extends Node
## Headless behavior smoke for slot-scoped Echo Chase world progress.

var _failures: Array[String] = []


# Runs public LevelModule behavior checks and exits non-zero on failure.
func _ready() -> void:
	var original_level_module := LevelModule.instance
	_test_present_room_delay_switch_is_immediate()
	_test_progression_device_ids_are_unique()
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


# Collected slot data restores checkpoint and permanent world progress together.
func _test_progress_round_trip() -> void:
	var source := LevelModule.new()
	if not _require_progress_api(source):
		return
	source.set_checkpoint("res://map.tscn", "hub", Vector2(24.0, 48.0), 5.0, "delay_5s")
	source.activate_progression_device("long_route")
	_expect(source.unlock_present_hub(), "first present hub unlock should succeed")
	_expect(not source.unlock_present_hub(), "present hub unlock should be idempotent")
	var restored := LevelModule.new()
	restored.apply_data(source.collect_data())
	_expect(restored.get_checkpoint().get("checkpoint_id", "") == "hub", "checkpoint should survive round-trip")
	_expect(restored.is_progression_device_active("long_route"), "device state should survive round-trip")
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
	timeline.queue_free()


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
