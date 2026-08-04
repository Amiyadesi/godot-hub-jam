extends Node

const TEMPORAL_FRAME_SCRIPT := preload("res://Scripts/EchoChase/temporal_frame.gd")
const TEMPORAL_TRACK_SCRIPT := preload("res://Scripts/EchoChase/temporal_track.gd")
const PLAYER_SCENE := preload("res://Scenes/EchoChase/Prefabs/echo_player.tscn")
const PRESSURE_PLATE_SCENE := preload("res://Scenes/EchoChase/Prefabs/temporal_pressure_plate.tscn")
const TEMPORAL_DOOR_SCENE := preload("res://Scenes/EchoChase/Prefabs/temporal_door.tscn")
const FUTURE_ECHO_SCENE := preload("res://Scenes/EchoChase/Prefabs/future_echo.tscn")
const FUTURE_RECORDER_SCENE := preload("res://Scenes/EchoChase/Prefabs/future_recorder.tscn")
const FUTURE_BARRIER_SCENE := preload("res://Scenes/EchoChase/Prefabs/future_condensation_barrier.tscn")
const PROGRESSION_SHORTCUT_SCENE := preload("res://Scenes/EchoChase/Prefabs/progression_shortcut.tscn")

const PHYSICS_STEP := 1.0 / 60.0
const TILE_SIZE := 16.0

var _failures: Array[String] = []


# 在项目树中检查不会随着关卡、美术或手感调参变化的轨迹语义。
func _ready() -> void:
	_test_track_interpolates_continuous_motion()
	_test_track_keeps_recall_until_its_exact_time()
	_test_player_tuning_matches_authored_envelope()
	await _test_run_countdown_lifecycle()
	await _test_past_catch_reports_recording_source()
	_test_dash_charge_marker_follows_player_state()
	_test_dash_input_consumes_single_charge()
	await _test_landing_restores_single_dash()
	_test_temporal_door_requires_all_sources()
	_test_temporal_door_latches_after_all_sources()
	_test_temporal_door_modes_and_indicators()
	_test_temporal_door_latched_state_round_trip()
	_test_temporal_pressure_plate_feedback()
	_test_future_echo_reports_active_playback()
	_test_future_barrier_follows_its_recorder()
	await _test_progression_shortcut_follows_device()
	await _test_future_collision_refills_single_dash()
	_finish()


# 验证普通相邻样本按时间连续插值。
func _test_track_interpolates_continuous_motion() -> void:
	var track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
	track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(100.0, 20.0)))
	var sample: TemporalFrame = track.sample_at(0.5)
	_expect(sample != null, "TemporalTrack returns a midpoint sample")
	if sample != null:
		_expect(sample.position.is_equal_approx(Vector2(50.0, 10.0)), "TemporalTrack interpolates continuous position")


# 验证回传只在精确时刻跳变，绝不提前插值到目的地。
func _test_track_keeps_recall_until_its_exact_time() -> void:
	var track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
	track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(100.0, 0.0)))
	var recall := TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(12.0, 0.0))
	recall.flags = TemporalFrame.Flag.RECALL
	track.append(recall)
	var before_recall: TemporalFrame = track.sample_at(0.99)
	var at_recall: TemporalFrame = track.sample_at(1.0)
	_expect(before_recall != null and before_recall.position.x > 90.0, "TemporalTrack keeps the pre-recall path until recall time")
	_expect(at_recall != null and at_recall.is_recall(), "TemporalTrack returns the recall frame at its exact time")
	if at_recall != null:
		_expect(is_equal_approx(at_recall.position.x, 12.0), "TemporalTrack applies the recall destination at recall time")


# 验证玩家 prefab 只继承脚本调参，并保持关卡采用的移动包线。
func _test_player_tuning_matches_authored_envelope() -> void:
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	_expect(is_equal_approx(player.run_speed, 144.0), "EchoPlayer runs at 9 tiles per second")
	_expect(is_equal_approx(player.run_acceleration, 2304.0), "EchoPlayer reaches run speed in one tile")
	_expect(is_equal_approx(player.jump_speed, 320.0), "EchoPlayer uses the authored jump speed")
	_expect(is_equal_approx(player.jump_release_multiplier, 0.65), "EchoPlayer keeps the authored short-hop cut")
	_expect(is_equal_approx(player.gravity, 1200.0), "EchoPlayer uses the authored gravity")
	_expect(is_equal_approx(player.wall_slide_speed, 48.0), "EchoPlayer wall-slides at 3 tiles per second")
	_expect(is_equal_approx(player.wall_jump_speed_x, 176.0), "EchoPlayer uses the authored wall-jump push")
	_expect(is_equal_approx(player.wall_push_seconds, 0.10), "EchoPlayer keeps the authored wall push window")
	_expect(player.get_node_or_null("RayCast2D") is RayCast2D, "EchoPlayer has an authored head wall ray")
	_expect(player.get_node_or_null("RayCast2D2") is RayCast2D, "EchoPlayer has an authored foot wall ray")
	_expect(is_equal_approx(player.dash_aim_seconds, 0.04), "EchoPlayer keeps the short dash aim window")
	_expect(is_equal_approx(player.dash_speed, 336.0), "EchoPlayer uses the authored dash speed")
	_expect(is_equal_approx(player.dash_seconds, 0.10), "EchoPlayer keeps the authored dash duration")
	_expect(is_equal_approx(player.dash_input_recovery_seconds, 0.06), "EchoPlayer keeps the authored dash recovery")
	_expect(is_equal_approx(player.dash_jump_momentum, 0.65), "EchoPlayer keeps the authored dash-jump momentum")
	_expect(is_equal_approx(player.dash_speed_cap_multiplier, 1.60), "EchoPlayer keeps the authored dash-jump cap")
	var full_jump_height := _simulate_jump_height(player.jump_speed, player.gravity)
	var short_jump_height := _simulate_short_jump_height(
		player.jump_speed,
		player.gravity,
		player.jump_release_multiplier
	)
	var dash_distance := _simulate_dash_distance(
		player.dash_speed,
		player.dash_seconds,
		player.dash_input_recovery_seconds,
		player.run_acceleration
	)
	_expect(is_equal_approx(full_jump_height / TILE_SIZE, 2.5), "EchoPlayer full jump reaches 2.5 tiles")
	_expect(short_jump_height / TILE_SIZE >= 1.15 and short_jump_height / TILE_SIZE <= 1.25, "EchoPlayer short jump stays near 1.2 tiles")
	_expect(dash_distance / TILE_SIZE >= 3.0 and dash_distance / TILE_SIZE <= 3.3, "EchoPlayer dash stays near 3.25 tiles")
	player.free()


# 验证整局倒计时只在 Hub 内暂停，并在 Future 提交后回到录像起点。
func _test_run_countdown_lifecycle() -> void:
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	add_child(player)
	player.set_physics_process(false)
	await get_tree().process_frame
	EchoTimeline.start_run_countdown()
	EchoTimeline.resume_run_countdown()
	var start_remaining := EchoTimeline.get_run_countdown_remaining()
	EchoTimeline._advance_run_countdown(2.0)
	_expect(
		is_equal_approx(EchoTimeline.get_run_countdown_remaining(), start_remaining - 2.0),
		"whole-run countdown decreases while gameplay is active"
	)
	EchoTimeline.enter_present_room()
	var hub_remaining := EchoTimeline.get_run_countdown_remaining()
	EchoTimeline._advance_run_countdown(2.0)
	_expect(
		is_equal_approx(EchoTimeline.get_run_countdown_remaining(), hub_remaining),
		"PresentHub pauses the whole-run countdown"
	)
	EchoTimeline.leave_present_room()
	EchoTimeline._advance_run_countdown(2.0)
	_expect(
		is_equal_approx(EchoTimeline.get_run_countdown_remaining(), hub_remaining - 2.0),
		"leaving PresentHub resumes the whole-run countdown"
	)
	EchoTimeline.reset_timeline()
	EchoTimeline.start_run_countdown()
	EchoTimeline.resume_run_countdown()
	EchoTimeline._set_run_countdown_remaining(1234.0)
	var recorder := FUTURE_RECORDER_SCENE.instantiate() as FutureRecorder
	add_child(recorder)
	_expect(EchoTimeline.start_future_recording(recorder), "Future recording starts for countdown snapshot")
	var recording_start_remaining := EchoTimeline.get_run_countdown_remaining()
	EchoTimeline._physics_process(PHYSICS_STEP)
	_expect(EchoTimeline.get_run_countdown_remaining() < recording_start_remaining, "recording consumes run time before commit")
	_expect(EchoTimeline.commit_future_recording(), "Future recording commits for countdown restore")
	_expect(
		is_equal_approx(EchoTimeline.get_run_countdown_remaining(), 1234.0),
		"Future commit restores the recording-start run time"
	)
	var expiration_count: Array[int] = [0]
	var on_expired := func() -> void:
		expiration_count[0] += 1
	EchoTimeline.run_countdown_expired.connect(on_expired)
	EchoTimeline._set_run_countdown_remaining(0.0)
	EchoTimeline._set_run_countdown_remaining(0.0)
	_expect(expiration_count[0] == 1, "whole-run countdown expires once without failing the run")
	EchoTimeline.run_countdown_expired.disconnect(on_expired)
	EchoTimeline.reset_timeline()
	recorder.free()
	player.free()


# 验证知识锁能识别“录像中主动被 Past 追上”的 Recorder。
func _test_past_catch_reports_recording_source() -> void:
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	add_child(player)
	player.set_physics_process(false)
	var recorder := FUTURE_RECORDER_SCENE.instantiate() as FutureRecorder
	add_child(recorder)
	await get_tree().process_frame
	var reported_recorder: Array[FutureRecorder] = [null]
	var on_committed := func(value: FutureRecorder) -> void:
		reported_recorder[0] = value
	EchoTimeline.future_recording_committed_by_past.connect(on_committed)
	_expect(EchoTimeline.start_future_recording(recorder), "Future recording starts for Past-catch reporting")
	EchoTimeline._on_past_echo_caught_player()
	_expect(reported_recorder[0] == recorder, "Past catch reports the recorder used by the knowledge lock")
	EchoTimeline.future_recording_committed_by_past.disconnect(on_committed)
	EchoTimeline.reset_timeline()
	recorder.free()
	player.free()


# 验证 authored 冲刺菱晶只显示唯一真实充能，并区分回充与满充接触。
func _test_dash_charge_marker_follows_player_state() -> void:
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	add_child(player)
	player.set_physics_process(false)
	var marker := player.get_node_or_null("DashChargeMarker") as Node2D
	_expect(marker != null, "EchoPlayer authors a dash charge marker")
	if marker == null:
		player.free()
		return
	var animation_player := marker.get_node("AnimationPlayer") as AnimationPlayer
	_expect(marker.visible, "dash marker is visible with the spawn charge")
	_set_player_dash_available(player, false)
	_expect(not marker.visible, "Recall sync hides the marker for an empty anchor")
	var refill_audio := marker.get_node("FutureRefillAudio") as AudioStreamPlayer2D
	player.reset_dash()
	_expect(marker.visible, "Future refill immediately restores the marker")
	_expect(animation_player.current_animation in [&"future_refill", &"future_refill_reduced"], "empty Future contact plays refill feedback")
	_expect(refill_audio.playing, "empty Future contact plays the refill sound")
	refill_audio.stop()
	player.reset_dash()
	_expect(animation_player.current_animation in [&"future_full", &"future_full_reduced"], "full Future contact plays overflow feedback")
	_expect(not refill_audio.playing, "full Future contact does not replay the refill sound")
	player.facing = -1.0
	player.reset_player(Vector2.ZERO)
	_expect(player.facing > 0.0 and marker.position.x < 0.0, "player reset restores the marker behind its right-facing spawn pose")
	player.free()


# 验证一次冲刺在输入帧消耗菱晶，未恢复前不能再次启动。
func _test_dash_input_consumes_single_charge() -> void:
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	add_child(player)
	player.set_physics_process(false)
	var dash_count: Array[int] = [0]
	player.dash_started.connect(func(_direction: Vector2) -> void:
		dash_count[0] += 1
	)
	var dash_event := InputEventAction.new()
	dash_event.action = &"echo_dash"
	dash_event.pressed = true
	player._input(dash_event)
	player._physics_process(PHYSICS_STEP)
	_expect(not bool(player.capture_temporal_anchor(0.0)["dash_available"]), "dash input consumes the single charge immediately")
	var animation_player := player.get_node("DashChargeMarker/AnimationPlayer") as AnimationPlayer
	_expect(animation_player.current_animation == &"consume", "dash input plays authored marker consumption")
	player._input(dash_event)
	player._physics_process(PHYSICS_STEP)
	_expect(dash_count[0] == 1, "empty dash charge cannot start a second dash")
	animation_player.advance(0.1)
	_expect(not player.get_node("DashChargeMarker").visible, "consumed dash marker hides after its authored animation")
	player.free()


# 验证空槽玩家真实落地时恢复冲刺并播放轻量菱晶回充。
func _test_landing_restores_single_dash() -> void:
	var floor := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(128.0, 16.0)
	floor_shape.shape = floor_rectangle
	floor.add_child(floor_shape)
	floor.position = Vector2(0.0, 16.0)
	add_child(floor)
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	add_child(player)
	player.set_physics_process(false)
	await get_tree().physics_frame
	player.global_position = Vector2(0.0, -48.0)
	player.velocity = Vector2.ZERO
	_set_player_dash_available(player, false)
	var landed := false
	for _frame in 60:
		player._physics_process(PHYSICS_STEP)
		if player.is_on_floor():
			landed = true
			break
	_expect(landed, "landing refill test reaches authored ground")
	_expect(bool(player.capture_temporal_anchor(0.0)["dash_available"]), "landing restores the single dash charge")
	var animation_player := player.get_node("DashChargeMarker/AnimationPlayer") as AnimationPlayer
	_expect(animation_player.current_animation == &"landing_refill", "landing plays authored marker refill feedback")
	player.free()
	floor.free()


# 验证标准门只在全部 authored 压力板同时按下时保持开启。
func _test_temporal_door_requires_all_sources() -> void:
	var plate_a := PRESSURE_PLATE_SCENE.instantiate() as TemporalPressurePlate
	var plate_b := PRESSURE_PLATE_SCENE.instantiate() as TemporalPressurePlate
	add_child(plate_a)
	add_child(plate_b)
	var door := TEMPORAL_DOOR_SCENE.instantiate() as TemporalDoor
	door.source_plates = [plate_a, plate_b]
	add_child(door)
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	_expect(not door.is_open(), "TemporalDoor starts closed")
	plate_a.body_entered.emit(player)
	_expect(not door.is_open(), "TemporalDoor stays closed while one source is missing")
	plate_b.body_entered.emit(player)
	_expect(door.is_open(), "TemporalDoor opens when every source is pressed")
	plate_a.body_exited.emit(player)
	_expect(not door.is_open(), "Momentary TemporalDoor closes when any source releases")
	player.free()
	door.free()
	plate_a.free()
	plate_b.free()


# 验证锁存门首次满足全部输入后不随压力板释放而关闭。
func _test_temporal_door_latches_after_all_sources() -> void:
	var plate_a := PRESSURE_PLATE_SCENE.instantiate() as TemporalPressurePlate
	var plate_b := PRESSURE_PLATE_SCENE.instantiate() as TemporalPressurePlate
	var plate_c := PRESSURE_PLATE_SCENE.instantiate() as TemporalPressurePlate
	add_child(plate_a)
	add_child(plate_b)
	add_child(plate_c)
	var door := TEMPORAL_DOOR_SCENE.instantiate() as TemporalDoor
	door.mode = TemporalDoor.Mode.LATCHED_ALL
	door.source_plates = [plate_a, plate_b, plate_c]
	add_child(door)
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	plate_a.body_entered.emit(player)
	plate_b.body_entered.emit(player)
	_expect(not door.is_open(), "Latched TemporalDoor waits for its third source")
	plate_c.body_entered.emit(player)
	_expect(door.is_open(), "Latched TemporalDoor opens when every source is pressed")
	plate_a.body_exited.emit(player)
	plate_b.body_exited.emit(player)
	plate_c.body_exited.emit(player)
	_expect(door.is_open(), "Latched TemporalDoor stays open after every source releases")
	player.free()
	door.free()
	plate_a.free()
	plate_b.free()
	plate_c.free()


# 验证两种门模式使用不同颜色，并只显示已接线的指示格。
func _test_temporal_door_modes_and_indicators() -> void:
	var plate_a := PRESSURE_PLATE_SCENE.instantiate() as TemporalPressurePlate
	var plate_b := PRESSURE_PLATE_SCENE.instantiate() as TemporalPressurePlate
	add_child(plate_a)
	add_child(plate_b)
	var player := PLAYER_SCENE.instantiate()
	var momentary := TEMPORAL_DOOR_SCENE.instantiate() as TemporalDoor
	momentary.source_plates = [plate_a]
	add_child(momentary)
	_expect(momentary.get_node("Indicators/IndicatorA").visible, "Momentary door shows its connected source indicator")
	_expect(not momentary.get_node("Indicators/IndicatorB").visible, "Momentary door hides unused source indicators")
	_expect(momentary.visual.modulate.is_equal_approx(TemporalDoor.MOMENTARY_CLOSED_COLOR), "Momentary door uses its closed color")
	plate_a.body_entered.emit(player)
	_expect(momentary.is_open(), "Momentary door opens with its only source")
	_expect(momentary.visual.modulate.is_equal_approx(TemporalDoor.MOMENTARY_OPEN_COLOR), "Momentary door uses its open color")
	var latched := TEMPORAL_DOOR_SCENE.instantiate() as TemporalDoor
	latched.mode = TemporalDoor.Mode.LATCHED_ALL
	latched.source_plates = [plate_a, plate_b]
	add_child(latched)
	_expect(latched.visual.modulate.is_equal_approx(TemporalDoor.LATCHED_CLOSED_COLOR), "Latched door uses a distinct closed color")
	plate_b.body_entered.emit(player)
	_expect(latched.is_open(), "Latched door opens after all sources press")
	_expect(latched.visual.modulate.is_equal_approx(TemporalDoor.LATCHED_OPEN_COLOR), "Latched door uses a distinct open color")
	latched.free()
	momentary.free()
	plate_a.free()
	plate_b.free()
	player.free()


# 验证带 authored ID 的 Latched ALL 门可跨 LevelModule round-trip 恢复。
func _test_temporal_door_latched_state_round_trip() -> void:
	var original_level_module := LevelModule.instance
	var module := LevelModule.new()
	LevelModule.instance = module
	var plate_a := PRESSURE_PLATE_SCENE.instantiate() as TemporalPressurePlate
	var plate_b := PRESSURE_PLATE_SCENE.instantiate() as TemporalPressurePlate
	add_child(plate_a)
	add_child(plate_b)
	var door := TEMPORAL_DOOR_SCENE.instantiate() as TemporalDoor
	door.mode = TemporalDoor.Mode.LATCHED_ALL
	door.latched_door_id = &"latched_round_trip"
	door.source_plates = [plate_a, plate_b]
	add_child(door)
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	plate_a.body_entered.emit(player)
	plate_b.body_entered.emit(player)
	_expect(door.is_open(), "identified Latched door opens after all sources press")
	_expect(module.is_latched_door_open("latched_round_trip"), "identified Latched door writes checkpoint progress in memory")
	module.activate_progression_device("runtime_branch")
	module.collect_item("memory_shard_test")
	var restored := LevelModule.new()
	restored.apply_data(module.collect_data())
	_expect(restored.is_latched_door_open("latched_round_trip"), "identified Latched door survives data round-trip")
	_expect(restored.is_item_collected("memory_shard_test"), "MemoryShard state survives data round-trip")
	_expect(restored.is_progression_device_active("runtime_branch"), "Branch device survives data round-trip")
	player.free()
	door.free()
	plate_a.free()
	plate_b.free()
	LevelModule.instance = original_level_module


# 验证压板按下与释放都切换 authored 动画，并保留两种音效资源。
func _test_temporal_pressure_plate_feedback() -> void:
	var plate := PRESSURE_PLATE_SCENE.instantiate() as TemporalPressurePlate
	add_child(plate)
	var player := PLAYER_SCENE.instantiate()
	plate.body_entered.emit(player)
	_expect(plate.animation_player.current_animation == &"pressed", "Pressure plate plays its pressed animation")
	_expect(plate.press_audio.stream != null, "Pressure plate has a press sound")
	plate.body_exited.emit(player)
	_expect(plate.animation_player.current_animation == &"released", "Pressure plate plays its released animation")
	_expect(plate.release_audio.stream != null, "Pressure plate has a release sound")
	plate.free()
	player.free()


# 验证未来体只在真实回放生命周期变化时广播活跃状态。
func _test_future_echo_reports_active_playback() -> void:
	var future_echo := FUTURE_ECHO_SCENE.instantiate() as FutureEcho
	add_child(future_echo)
	var active_states: Array[bool] = []
	future_echo.active_changed.connect(func(active: bool) -> void:
		active_states.append(active)
	)
	var track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
	track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(32.0, 0.0)))
	_expect(not future_echo.is_active(), "FutureEcho starts inactive")
	future_echo.start_playback(track, 1.0, 0.0)
	_expect(future_echo.is_active(), "FutureEcho becomes active when playback starts")
	future_echo.advance(1.0)
	_expect(not future_echo.is_active(), "FutureEcho becomes inactive when playback ends")
	_expect(active_states == [true, false], "FutureEcho emits one signal per real active-state change")
	future_echo.free()


# 验证金色屏障只跟随绑定记录器的真实 Future 回放生命周期。
func _test_future_barrier_follows_its_recorder() -> void:
	var recorder := FUTURE_RECORDER_SCENE.instantiate() as FutureRecorder
	add_child(recorder)
	var barrier := FUTURE_BARRIER_SCENE.instantiate() as FutureCondensationBarrier
	barrier.source_recorder = recorder
	add_child(barrier)
	var future_echo := recorder.get_future_echo()
	var track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
	track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(32.0, 0.0)))
	_expect(barrier.get_visual_phase() == &"outline", "Future barrier shows an outline before recording")
	recorder.recording_started()
	_expect(not barrier.is_condensed(), "recording reservation does not condense a Future barrier")
	_expect(barrier.get_visual_phase() == &"recording", "Future barrier flickers while its recorder is recording")
	future_echo.start_playback(track, 1.0, 0.0)
	_expect(barrier.is_condensed(), "Future playback condenses its bound barrier")
	_expect(barrier.get_visual_phase() == &"solid", "Future playback makes its barrier solid")
	var playback_state := future_echo.capture_playback_state()
	future_echo.dissipate()
	_expect(not barrier.is_condensed(), "Future collision dissipation clears its bound barrier")
	_expect(barrier.get_visual_phase() == &"outline", "Future dissipation returns the barrier to its outline")
	future_echo.restore_playback_state(playback_state)
	_expect(barrier.is_condensed(), "restored Future playback restores its bound barrier")
	future_echo.reset_echo()


	_expect(not barrier.is_condensed(), "timeline reset clears its bound barrier")
	future_echo.start_playback(track, 1.0, 0.0)
	future_echo.advance(1.0)
	_expect(not barrier.is_condensed(), "natural Future completion clears its bound barrier")
	barrier.free()
	recorder.free()


# 验证回 Hub 捷径只响应绑定装置，并在打开后关闭实体碰撞。
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
	await get_tree().process_frame
	_expect(shortcut.is_open(), "progression shortcut opens for its matching device")
	_expect(shortcut.collision_shape.disabled, "opened progression shortcut disables collision")
	shortcut.free()
	LevelModule.instance = original_level_module


# 验证地面与空中的现在体撞散 Future 都恢复唯一一格冲刺。
func _test_future_collision_refills_single_dash() -> void:
	var floor := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(128.0, 16.0)
	floor_shape.shape = floor_rectangle
	floor.add_child(floor_shape)
	floor.position = Vector2(0.0, 16.0)
	add_child(floor)
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	add_child(player)
	player.set_physics_process(false)
	var future_echo := FUTURE_ECHO_SCENE.instantiate() as FutureEcho
	add_child(future_echo)
	await get_tree().physics_frame
	player.global_position = Vector2.ZERO
	player.velocity = Vector2(0.0, 120.0)
	player.move_and_slide()
	_expect(player.is_on_floor(), "dash refill test places EchoPlayer on authored ground")
	_set_player_dash_available(player, false)
	future_echo.start_playback(_make_test_future_track(), 1.0, 0.0)
	future_echo.body_entered.emit(player)
	_expect(bool(player.capture_temporal_anchor(0.0)["dash_available"]), "ground Future collision refills dash")
	player.global_position = Vector2(0.0, -64.0)
	player.velocity = Vector2.UP
	player.move_and_slide()
	_expect(not player.is_on_floor(), "dash refill test moves EchoPlayer airborne")
	_set_player_dash_available(player, false)
	future_echo.start_playback(_make_test_future_track(), 1.0, 0.0)
	future_echo.body_entered.emit(player)
	_expect(bool(player.capture_temporal_anchor(0.0)["dash_available"]), "airborne Future collision refills dash")
	future_echo.start_playback(_make_test_future_track(), 1.0, 0.0)
	future_echo.body_entered.emit(player)
	_expect(bool(player.capture_temporal_anchor(0.0)["dash_available"]), "full Future collision keeps dash capped at one charge")
	future_echo.free()
	player.free()
	floor.free()


# 通过公开锚点接口设置测试所需的冲刺存量。
func _set_player_dash_available(player: EchoPlayer, value: bool) -> void:
	var anchor := player.capture_temporal_anchor(0.0)
	anchor["dash_available"] = value
	player.apply_temporal_recall(anchor, 0.0)


# 构造一条最小有效 Future 回放轨迹。
func _make_test_future_track() -> TemporalTrack:
	var track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
	track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(32.0, 0.0)))
	return track


# 模拟脚本采用的先加重力、后移动的固定物理步。
func _simulate_jump_height(jump_speed: float, gravity: float) -> float:
	var velocity_y := -jump_speed
	var position_y := 0.0
	while velocity_y < 0.0:
		velocity_y += gravity * PHYSICS_STEP
		position_y += velocity_y * PHYSICS_STEP
	return -position_y


# 模拟起跳后一帧松键的最短稳定跳跃。
func _simulate_short_jump_height(jump_speed: float, gravity: float, release_multiplier: float) -> float:
	var velocity_y := -jump_speed
	var position_y := 0.0
	velocity_y += gravity * PHYSICS_STEP
	position_y += velocity_y * PHYSICS_STEP
	velocity_y *= release_multiplier
	while velocity_y < 0.0:
		velocity_y += gravity * PHYSICS_STEP
		position_y += velocity_y * PHYSICS_STEP
	return -position_y


# 模拟冲刺定速段与现有整向量恢复段的水平位移。
func _simulate_dash_distance(speed: float, seconds: float, recovery_seconds: float, acceleration: float) -> float:
	var distance := 0.0
	for _frame in ceili(seconds / PHYSICS_STEP):
		distance += speed * PHYSICS_STEP
	var velocity_x := speed
	for _frame in ceili(recovery_seconds / PHYSICS_STEP):
		velocity_x = move_toward(velocity_x, 0.0, acceleration * PHYSICS_STEP)
		distance += velocity_x * PHYSICS_STEP
	return distance


# 收集失败并以稳定的进程状态交给命令行。
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# 输出结果后退出，避免原型阶段引入额外测试框架。
func _finish() -> void:
	if _failures.is_empty():
		print("Echo Chase temporal path checks passed")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("PATH CHECK FAILED: %s" % failure)
	get_tree().quit(1)
