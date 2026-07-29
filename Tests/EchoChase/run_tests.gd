extends SceneTree

const TEMPORAL_FRAME_SCRIPT := preload("res://Scripts/EchoChase/temporal_frame.gd")
const TEMPORAL_TRACK_SCRIPT := preload("res://Scripts/EchoChase/temporal_track.gd")
const TIMELINE_FIXTURE := preload("res://Tests/EchoChase/fixtures/echo_timeline_fixture.tscn")
const START_SCENE_PATH := "res://Scenes/EchoChase/echo_chase_start.tscn"

var _failures: Array[String] = []


# Runs the current focused Echo Chase behavior checks in headless Godot.
func _init() -> void:
	call_deferred("_run")


# Runs synchronous path checks, then fixture checks that need physics frames.
func _run() -> void:
	_test_track_interpolates_continuous_motion()
	_test_track_keeps_recall_until_its_exact_time()
	_test_character_sprite_frames_contract()
	_test_checkpoint_save_schema()
	_test_settings_reset_emits_changed_values()
	await _test_temporal_prefab_visual_contract()
	await _test_temporal_entities_follow_low_flash_mode()
	await _test_temporal_departure_snapshots()
	await _test_checkpoint_activation_contract()
	await _test_active_devices_follow_low_flash_mode()
	await _test_start_scene_contract()
	await _test_gameplay_entry_intro()
	await _test_start_scene_checkpoint_and_reset()
	await _test_continue_restores_checkpoint_delay_station()
	await _test_start_scene_pause_settings_route()
	await _test_temporal_recording_hud()
	_test_menu_entry_scene_contract()
	await _test_menu_follows_low_flash_mode()
	_test_ui_visual_contract()
	await _test_toggle_changes_on_release()
	await _test_feedback_toast_mouse_passthrough()
	_test_player_state_and_tuning_contract()
	await _test_player_movement_state_transitions()
	await _test_player_moves_from_authored_input()
	await _test_dash_vfx_follows_low_flash_mode()
	await _test_physics_layer_and_trap_contract()
	await _test_past_echo_starts_out_of_the_world()
	await _test_past_echo_previews_each_clean_timeline()
	await _test_future_echo_releases_a_pressure_plate()
	await _test_future_echoes_use_independent_durations()
	await _test_past_dissipates_overlapping_futures_together()
	await _test_recorder_commits_a_future_echo_from_recall_input()
	await _test_recorder_state_feedback_and_reuse()
	await _test_first_frame_recording_and_past_contact_commit()
	await _test_delay_pickup_values_apply_after_a_phase_warning()
	await _test_delay_station_reuses_authored_node()
	await _test_two_future_slots_reject_a_third_recording()
	await _test_temporal_collision_matrix()
	await _test_timeline_reset_clears_transient_time_state()
	_finish()


# 验证三种时态共用的角色动画资源包含约定动画和帧数。
func _test_character_sprite_frames_contract() -> void:
	var resource_path := "res://assets/echo_chase/character/echo_character_frames.tres"
	_expect(ResourceLoader.exists(resource_path), "Echo character SpriteFrames resource exists")
	if not ResourceLoader.exists(resource_path):
		return
	var frames := load(resource_path) as SpriteFrames
	var expected_counts := {
		&"idle": 4,
		&"run": 5,
		&"jump": 1,
		&"fall": 1,
		&"wallslide": 4,
		&"climb": 2,
		&"dash": 1,
		&"hit": 7,
		&"death": 1,
	}
	_expect(frames != null, "Echo character SpriteFrames resource loads")
	if frames == null:
		return
	for animation_name: StringName in expected_counts:
		_expect(frames.has_animation(animation_name), "Echo character has %s animation" % animation_name)
		if frames.has_animation(animation_name):
			_expect(
				frames.get_frame_count(animation_name) == expected_counts[animation_name],
				"Echo character %s animation has expected frame count" % animation_name
			)
	var outline_path := "res://assets/echo_chase/character/echo_character_outline_frames.tres"
	_expect(ResourceLoader.exists(outline_path), "Echo character padded outline SpriteFrames resource exists")
	if not ResourceLoader.exists(outline_path):
		return
	var outline_frames := load(outline_path) as SpriteFrames
	for animation_name: StringName in expected_counts:
		_expect(outline_frames.has_animation(animation_name), "Padded outline has %s animation" % animation_name)
		if not outline_frames.has_animation(animation_name):
			continue
		_expect(
			outline_frames.get_frame_count(animation_name) == expected_counts[animation_name],
			"Padded outline %s keeps the Core frame count" % animation_name
		)
		for frame_index in outline_frames.get_frame_count(animation_name):
			_expect(
				outline_frames.get_frame_texture(animation_name, frame_index).get_size() == Vector2(24.0, 24.0),
				"Padded outline %s frame %d uses a 24x24 canvas" % [animation_name, frame_index]
			)


# 验证 checkpoint 坐标可 JSON 往返，且旧开发格式不会被当成有效进度。
func _test_checkpoint_save_schema() -> void:
	var previous_instance := LevelModule.instance
	var module := LevelModule.new()
	module.apply_data({
		"checkpoint_scene_path": "res://Scenes/EchoChase/echo_chase_start.tscn",
		"checkpoint_id": "start_checkpoint",
		"checkpoint_position": {"x": 320.5, "y": 640.0},
		"past_delay_seconds": 5.0,
		"delay_switch_id": "delay_5s",
	})
	_expect(module.has_continue_point(), "LevelModule accepts the coordinate checkpoint schema")
	var checkpoint := module.get_checkpoint()
	_expect(
		checkpoint.get("position", Vector2.ZERO).is_equal_approx(Vector2(320.5, 640.0)),
		"LevelModule restores checkpoint coordinates as Vector2"
	)
	var saved_data := module.collect_data()
	_expect(saved_data.get("checkpoint_position", {}) == {"x": 320.5, "y": 640.0}, "LevelModule serializes checkpoint coordinates as JSON data")
	_expect(saved_data.get("past_delay_seconds", 0.0) == 5.0, "LevelModule serializes the selected past delay")
	_expect(saved_data.get("delay_switch_id", "") == "delay_5s", "LevelModule serializes the exact delay switch id")
	_expect(checkpoint.get("past_delay_seconds", 0.0) == 5.0, "LevelModule restores the selected past delay")
	_expect(checkpoint.get("delay_switch_id", "") == "delay_5s", "LevelModule restores the exact delay switch id")
	module.apply_data({
		"checkpoint_scene_path": "res://Scenes/EchoChase/echo_chase_start.tscn",
		"checkpoint_id": "coordinate_only_checkpoint",
		"checkpoint_position": {"x": 320.5, "y": 640.0},
	})
	_expect(not module.has_continue_point(), "LevelModule rejects checkpoint data without delay station state")
	LevelModule.instance = previous_instance


# 验证恢复默认值会通知真实变化项，未变化设置不会产生伪事件。
func _test_settings_reset_emits_changed_values() -> void:
	var original_values := SettingsModule.instance.get_all()
	SettingsModule.instance.set_value("low_flash_mode", true)
	SettingsModule.instance.set_value("screen_shake", 0.25)
	var changed_keys: Array[String] = []
	var listener := func(key: String, _value: Variant) -> void:
		changed_keys.append(key)
	SettingsModule.instance.settings_changed.connect(listener)
	SettingsModule.instance.reset_to_defaults()
	SettingsModule.instance.settings_changed.disconnect(listener)
	_expect(changed_keys.has("low_flash_mode"), "Resetting settings emits the changed low-flash value")
	_expect(changed_keys.has("screen_shake"), "Resetting settings emits the changed screen-shake value")
	_expect(not changed_keys.has("language"), "Resetting settings does not emit unchanged values")
	SettingsModule.instance.apply_data(original_values)
	SettingsModule.instance.apply_all()


# 验证三种时态使用 authored 动画节点、统一碰撞和动作音效。
func _test_temporal_prefab_visual_contract() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	if player != null and timeline != null:
		var player_visual := player.get_node("Visual") as AnimatedSprite2D
		var past_visual := timeline.past_echo.get_node("Visual") as AnimatedSprite2D
		var future_visual := timeline.future_echo_a.get_node("Visual") as AnimatedSprite2D
		_expect(player_visual != null, "EchoPlayer uses an authored AnimatedSprite2D")
		_expect(past_visual != null, "PastEcho uses an authored AnimatedSprite2D")
		_expect(future_visual != null, "FutureEcho uses an authored AnimatedSprite2D")
		var player_shape := player.get_node("CollisionShape2D") as CollisionShape2D
		var rectangle := player_shape.shape as RectangleShape2D
		_expect(rectangle != null and rectangle.size.is_equal_approx(Vector2(10.0, 15.0)), "EchoPlayer uses the 10x15 collision contract")
		_expect(player.has_node("DashAudio") and player.has_node("LandAudio"), "EchoPlayer authors dash and landing audio nodes")
		var dash_vfx := player.get_node_or_null("DashVfx")
		_expect(dash_vfx != null, "EchoPlayer authors a dedicated dash VFX controller")
		if dash_vfx != null:
			_expect(dash_vfx.has_node("StartBurst") and dash_vfx.has_node("DirectionParticles"), "Dash VFX authors start and directional particles")
			_expect(dash_vfx.has_node("Afterimages/AfterimageA") and dash_vfx.has_node("Afterimages/AfterimageC"), "Dash VFX authors a fixed short afterimage pool")
			_expect(dash_vfx.has_node("EndBurst") and dash_vfx.has_node("EndRing"), "Dash VFX authors finish convergence feedback")
		_expect(timeline.past_echo.has_node("AppearAudio"), "PastEcho authors its appearance audio node")
		_expect(timeline.past_echo.has_node("OutlineVisual"), "PastEcho authors its materialization outline")
		_expect(timeline.past_echo.has_node("HistoryTrail"), "PastEcho authors a backward history trail")
		_expect(timeline.past_echo.has_node("HistoryTrailFar"), "PastEcho authors a second backward history trail")
		_expect(timeline.past_echo.has_node("PixelBurst"), "PastEcho authors its phase particles")
		_expect(timeline.past_echo.has_node("VfxAnimationPlayer"), "PastEcho authors its VFX animation player")
		_expect(timeline.past_echo.has_node("DepartureVfx"), "PastEcho authors an independent departure snapshot")
		_expect(timeline.future_echo_a.has_node("OutlineVisual"), "FutureEcho authors its materialization outline")
		_expect(timeline.future_echo_a.has_node("OuterOutlineVisual"), "FutureEcho authors a second outer outline")
		_expect(timeline.future_echo_a.has_node("PredictionVisual"), "FutureEcho authors a forward prediction ghost")
		_expect(timeline.future_echo_a.has_node("PixelBurst"), "FutureEcho authors its phase particles")
		_expect(timeline.future_echo_a.has_node("VfxAnimationPlayer"), "FutureEcho authors its VFX animation player")
		_expect(timeline.future_echo_a.has_node("DepartureVfx"), "FutureEcho authors an independent departure snapshot")
		_expect(player_visual.material == null, "EchoPlayer Core preserves original character pixels")
		var present_outline := player.get_node("TemporalOutline") as AnimatedSprite2D
		var recording_outline := player.get_node("RecordingOutline") as AnimatedSprite2D
		_expect(
			present_outline.sprite_frames.resource_path == "res://assets/echo_chase/character/echo_character_outline_frames.tres",
			"EchoPlayer uses a separate padded cyan temporal outline"
		)
		_expect(
			recording_outline.sprite_frames.resource_path == "res://assets/echo_chase/character/echo_character_outline_frames.tres",
			"Player recording halo uses padded outline frames"
		)
		_expect(past_visual.material == null, "PastEcho Core preserves original character pixels")
		_expect(future_visual.material == null, "FutureEcho Core preserves original character pixels")
		var past_outline := timeline.past_echo.get_node("OutlineVisual") as AnimatedSprite2D
		var future_outline := timeline.future_echo_a.get_node("OutlineVisual") as AnimatedSprite2D
		var past_outline_material := past_outline.material as ShaderMaterial
		_expect(
			past_outline_material != null and not past_outline_material.shader.code.contains("pattern_mode"),
			"PastEcho uses a continuous magenta outline"
		)
		if past_outline_material != null:
			var outline_code := past_outline_material.shader.code
			_expect(
				outline_code.contains("vec2(TEXTURE_PIXEL_SIZE.x, TEXTURE_PIXEL_SIZE.y)")
				and outline_code.contains("vec2(-TEXTURE_PIXEL_SIZE.x, TEXTURE_PIXEL_SIZE.y)")
				and outline_code.contains("vec2(TEXTURE_PIXEL_SIZE.x, -TEXTURE_PIXEL_SIZE.y)")
				and outline_code.contains("vec2(-TEXTURE_PIXEL_SIZE.x, -TEXTURE_PIXEL_SIZE.y)"),
				"Temporal outline samples all four diagonal neighbors"
			)
		_expect(
			past_outline.sprite_frames.resource_path == "res://assets/echo_chase/character/echo_character_outline_frames.tres",
			"PastEcho materialization uses padded outline frames"
		)
		_expect(
			future_outline.sprite_frames.resource_path == "res://assets/echo_chase/character/echo_character_outline_frames.tres",
			"FutureEcho materialization uses padded outline frames"
		)
		var replay_frame := TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2(500.0, 0.0), Vector2.ZERO, -1.0, &"run")
		var replay_end := replay_frame.copy()
		replay_end.time_seconds = 1.0
		var track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		track.append(replay_frame)
		track.append(replay_end)
		timeline.set_physics_process(false)
		timeline.past_echo.play_at(track, 0.0)
		timeline.future_echo_a.start_playback(track, 1.0, 0.0)
		(timeline.past_echo.get_node("VfxAnimationPlayer") as AnimationPlayer).advance(0.06)
		if past_visual != null:
			_expect(past_visual.animation == &"run" and past_visual.flip_h, "PastEcho replays animation and facing")
			_expect(
				past_outline.visible
				and past_outline.scale.is_equal_approx(Vector2.ONE)
				and is_equal_approx(past_outline.modulate.a, 1.0),
				"PastEcho solid state fully restores its continuous outline"
			)
		if future_visual != null:
			_expect(future_visual.animation == &"run" and future_visual.flip_h, "FutureEcho replays animation and facing")
	fixture.queue_free()
	await process_frame


# 验证过去与未来实体化途中切换低闪只替换表现，不重置时态进度。
func _test_temporal_entities_follow_low_flash_mode() -> void:
	var original_low_flash := bool(SettingsModule.instance.get_value("low_flash_mode", false))
	SettingsModule.instance.set_value("low_flash_mode", false)
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var past := timeline.past_echo
	var future := timeline.future_echo_a
	var past_animation := past.get_node("VfxAnimationPlayer") as AnimationPlayer
	var future_animation := future.get_node("VfxAnimationPlayer") as AnimationPlayer
	var delayed_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	delayed_track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(120.0, 80.0), Vector2.ZERO, 1.0, &"idle"))
	delayed_track.append(TEMPORAL_FRAME_SCRIPT.new(2.0, Vector2(180.0, 80.0), Vector2(60.0, 0.0), 1.0, &"run"))
	past.play_at(delayed_track, 0.7)
	past_animation.advance(0.14)
	var past_ratio := past_animation.current_animation_position / past_animation.current_animation_length
	SettingsModule.instance.set_value("low_flash_mode", true)
	_expect(past_animation.current_animation == &"materialize_reduced", "Past materialization immediately enters reduced feedback")
	_expect(
		is_equal_approx(past_animation.current_animation_position / past_animation.current_animation_length, past_ratio),
		"Past materialization preserves normalized progress"
	)
	SettingsModule.instance.set_value("low_flash_mode", false)
	past.begin_phase_shift()
	past.preview_phase_target(delayed_track, 1.0, 0.24)
	var phase_ratio := past_animation.current_animation_position / past_animation.current_animation_length
	SettingsModule.instance.set_value("low_flash_mode", true)
	_expect(past_animation.current_animation == &"phase_target_reduced", "Past phase target immediately enters reduced feedback")
	_expect(
		is_equal_approx(past_animation.current_animation_position / past_animation.current_animation_length, phase_ratio),
		"Past phase target preserves normalized progress"
	)
	SettingsModule.instance.set_value("low_flash_mode", false)
	var future_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	future_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2(220.0, 80.0), Vector2.ZERO, 1.0, &"idle"))
	future_track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(280.0, 80.0), Vector2(60.0, 0.0), 1.0, &"run"))
	future.start_playback(future_track, 1.0, 0.0)
	future_animation.advance(0.14)
	var future_ratio := future_animation.current_animation_position / future_animation.current_animation_length
	SettingsModule.instance.set_value("low_flash_mode", true)
	_expect(future_animation.current_animation == &"materialize_reduced", "Future materialization immediately enters reduced feedback")
	_expect(
		is_equal_approx(future_animation.current_animation_position / future_animation.current_animation_length, future_ratio),
		"Future materialization preserves normalized progress"
	)
	fixture.queue_free()
	await process_frame
	SettingsModule.instance.set_value("low_flash_mode", original_low_flash)


# 验证旧位置裂解与新实体回放解耦，槽位复用不会拖走尾效。
func _test_temporal_departure_snapshots() -> void:
	var original_low_flash := bool(SettingsModule.instance.get_value("low_flash_mode", false))
	SettingsModule.instance.set_value("low_flash_mode", false)
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var past := timeline.past_echo
	var future := timeline.future_echo_a
	var past_departure := past.get_node_or_null("DepartureVfx") as TemporalDepartureVfx
	var future_departure := future.get_node_or_null("DepartureVfx") as TemporalDepartureVfx
	if past_departure != null and future_departure != null:
		_expect(past_departure.has_node("CoreSnapshot") and past_departure.has_node("ImpactRing"), "Temporal departure preserves the full core and ring feedback")
		var past_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		past_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2(120.0, 80.0), Vector2(40.0, 0.0), 1.0, &"run"))
		past_track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(360.0, 80.0), Vector2(40.0, 0.0), 1.0, &"run"))
		past.play_at(past_track, 0.0)
		past.begin_phase_shift()
		past.preview_phase_target(past_track, 1.0, 0.0)
		_expect(past_departure.is_playing(), "Past delay switch keeps an old-position departure snapshot")
		_expect(past_departure.global_position.is_equal_approx(Vector2(120.0, 80.0)), "Past departure stays at the old history position")
		_expect(past.global_position.is_equal_approx(Vector2(360.0, 80.0)), "Past body simultaneously previews the new history position")
		_expect(past.is_materializing(), "Past new position runs its independent materialization")

		var first_future_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		first_future_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2(220.0, 100.0), Vector2(80.0, 0.0), 1.0, &"run"))
		first_future_track.append(TEMPORAL_FRAME_SCRIPT.new(0.1, Vector2(228.0, 100.0), Vector2(80.0, 0.0), 1.0, &"run"))
		var dissipated_events: Array[bool] = []
		future.dissipated.connect(func(_future_echo: FutureEcho) -> void: dissipated_events.append(true))
		future.start_playback(first_future_track, 0.1, 0.0)
		future.advance(0.11)
		var future_core_snapshot := future_departure.get_node("CoreSnapshot") as Sprite2D
		var old_snapshot_position := future_departure.global_position
		_expect(future.is_available(), "Future slot releases before its departure finishes")
		_expect(future_departure.is_playing(), "Future keeps an authored departure after slot release")
		_expect(future_core_snapshot.texture != null, "Future departure copies the visible core instead of only a thin outline")
		future_departure.animation_player.advance(0.08)
		var departure_ratio := future_departure.animation_player.current_animation_position / future_departure.animation_player.current_animation_length
		SettingsModule.instance.set_value("low_flash_mode", true)
		_expect(future_departure.animation_player.current_animation == &"depart_reduced", "Active departure immediately enters reduced feedback")
		_expect(not future_departure.particles.emitting, "Enabling low-flash immediately stops active departure particles")
		_expect(
			is_equal_approx(future_departure.animation_player.current_animation_position / future_departure.animation_player.current_animation_length, departure_ratio),
			"Departure preserves normalized progress when low-flash changes"
		)
		SettingsModule.instance.set_value("low_flash_mode", false)
		_expect(future_departure.animation_player.current_animation == &"depart", "Active departure returns to standard fade without restarting")
		_expect(not future_departure.particles.emitting, "Disabling low-flash does not replay an active departure burst")
		var second_future_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		second_future_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2(520.0, 100.0), Vector2.ZERO, 1.0, &"idle"))
		second_future_track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(520.0, 100.0), Vector2.ZERO, 1.0, &"idle"))
		future.start_playback(second_future_track, 1.0, 0.0)
		_expect(future.global_position.is_equal_approx(Vector2(520.0, 100.0)), "Released Future slot starts its next playback immediately")
		_expect(future_departure.global_position.is_equal_approx(old_snapshot_position), "Reused Future body does not move the old departure snapshot")
		future_departure.animation_player.advance(0.3)
		_expect(dissipated_events.size() == 1, "Future dissipated reports visual-tail completion after slot release")
		_expect(not future.is_available(), "Finishing an old departure does not cancel the reused Future playback")
		future.reset_echo()
		past.reset_echo()
		_expect(not future_departure.is_playing() and not past_departure.is_playing(), "Timeline reset clears every departure snapshot")
	fixture.queue_free()
	await process_frame
	SettingsModule.instance.set_value("low_flash_mode", original_low_flash)


# 验证 authored 存档点只在首次玩家触碰时请求激活。
func _test_checkpoint_activation_contract() -> void:
	var checkpoint_path := "res://Scenes/EchoChase/Prefabs/echo_checkpoint.tscn"
	_expect(ResourceLoader.exists(checkpoint_path), "EchoCheckpoint prefab exists")
	if not ResourceLoader.exists(checkpoint_path):
		return
	var fixture := TIMELINE_FIXTURE.instantiate()
	var checkpoint := (load(checkpoint_path) as PackedScene).instantiate() as EchoCheckpoint
	root.add_child(fixture)
	root.add_child(checkpoint)
	await physics_frame
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	var activations: Array[bool] = []
	checkpoint.activation_requested.connect(func(requested_checkpoint: EchoCheckpoint) -> void:
		activations.append(true)
		requested_checkpoint.set_active(true, false)
	)
	checkpoint.body_entered.emit(player)
	checkpoint.body_entered.emit(player)
	_expect(activations.size() == 1, "EchoCheckpoint ignores duplicate player activation")
	_expect(not checkpoint.get_checkpoint_id().is_empty(), "EchoCheckpoint exposes an authored id")
	_expect(checkpoint.get_respawn_position().is_equal_approx(checkpoint.get_node("RespawnPoint").global_position), "EchoCheckpoint exposes its authored respawn point")
	_expect((checkpoint.get_node("ActivationAudio") as AudioStreamPlayer2D).stream != null, "EchoCheckpoint authors its activation audio")
	fixture.queue_free()
	checkpoint.queue_free()
	await process_frame


# 验证持续机关在运行中切换低闪时保留动画进度，不重新播放反馈。
func _test_active_devices_follow_low_flash_mode() -> void:
	var original_low_flash := bool(SettingsModule.instance.get_value("low_flash_mode", false))
	SettingsModule.instance.set_value("low_flash_mode", false)
	var scene := (load(START_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var checkpoint := scene.get_node("World/EchoCheckpoint") as EchoCheckpoint
	var delay_station := scene.get_node("World/DelayPickup3s") as DelayPickup
	var checkpoint_animation := checkpoint.get_node("AnimationPlayer") as AnimationPlayer
	var delay_animation := delay_station.get_node("StateAnimationPlayer") as AnimationPlayer
	checkpoint.set_active(true)
	checkpoint_animation.advance(0.4)
	delay_animation.advance(0.4)
	var checkpoint_ratio := checkpoint_animation.current_animation_position / checkpoint_animation.current_animation_length
	var delay_ratio := delay_animation.current_animation_position / delay_animation.current_animation_length
	SettingsModule.instance.set_value("low_flash_mode", true)
	_expect(checkpoint_animation.current_animation == &"active_reduced", "Active checkpoint immediately enters reduced feedback")
	_expect(delay_animation.current_animation == &"active_reduced", "Active delay station immediately enters reduced feedback")
	_expect(
		is_equal_approx(checkpoint_animation.current_animation_position / checkpoint_animation.current_animation_length, checkpoint_ratio),
		"Checkpoint preserves normalized animation progress when low-flash is enabled"
	)
	_expect(
		is_equal_approx(delay_animation.current_animation_position / delay_animation.current_animation_length, delay_ratio),
		"Delay station preserves normalized animation progress when low-flash is enabled"
	)
	checkpoint_animation.advance(0.2)
	delay_animation.advance(0.2)
	checkpoint_ratio = checkpoint_animation.current_animation_position / checkpoint_animation.current_animation_length
	delay_ratio = delay_animation.current_animation_position / delay_animation.current_animation_length
	SettingsModule.instance.set_value("low_flash_mode", false)
	_expect(checkpoint_animation.current_animation == &"active", "Active checkpoint returns to standard feedback without reactivation")
	_expect(delay_animation.current_animation == &"active", "Active delay station returns to standard feedback without reactivation")
	_expect(
		is_equal_approx(checkpoint_animation.current_animation_position / checkpoint_animation.current_animation_length, checkpoint_ratio),
		"Checkpoint preserves normalized animation progress when low-flash is disabled"
	)
	_expect(
		is_equal_approx(delay_animation.current_animation_position / delay_animation.current_animation_length, delay_ratio),
		"Delay station preserves normalized animation progress when low-flash is disabled"
	)
	scene.queue_free()
	await process_frame
	SettingsModule.instance.set_value("low_flash_mode", original_low_flash)


# 验证起始场景包含相机、完整时间机制展台、存档点和暂停界面。
func _test_start_scene_contract() -> void:
	_expect(ResourceLoader.exists(START_SCENE_PATH), "Echo Chase start scene exists")
	if not ResourceLoader.exists(START_SCENE_PATH):
		return
	var scene := (load(START_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	var tile_maps := scene.find_children("*", "TileMapLayer", true, false)
	_expect(tile_maps.size() == 1, "Start scene authors exactly one TileMapLayer")
	if tile_maps.size() == 1:
		_expect(not (tile_maps[0] as TileMapLayer).get_used_cells().is_empty(), "Start scene keeps the user-authored playable TileMap")
	var camera := scene.get_node_or_null("World/EchoPlayer/Camera2D") as Camera2D
	_expect(camera != null, "Start scene authors one player Camera2D")
	if camera != null:
		_expect(camera.zoom.is_equal_approx(Vector2(4.0, 4.0)), "Start camera uses 4x pixel-art zoom")
		_expect(camera.limit_right == 1920, "Start camera is limited to the authored test corridor")
	_expect(scene.find_children("*", "Camera3D", true, false).is_empty(), "Start scene contains no Camera3D")
	var delay_pickup_1 := scene.get_node_or_null("World/DelayPickup1s") as DelayPickup
	var delay_pickup_3 := scene.get_node_or_null("World/DelayPickup3s") as DelayPickup
	var delay_pickup_5 := scene.get_node_or_null("World/DelayPickup5s") as DelayPickup
	_expect(delay_pickup_1 != null and delay_pickup_1.delay_seconds == 1, "Start scene authors the 1-second delay pickup")
	_expect(delay_pickup_3 != null and delay_pickup_3.delay_seconds == 3, "Start scene authors the 3-second delay pickup")
	_expect(delay_pickup_5 != null and delay_pickup_5.delay_seconds == 5, "Start scene authors the 5-second delay pickup")
	if delay_pickup_1 != null and delay_pickup_3 != null and delay_pickup_5 != null:
		var switch_ids := [delay_pickup_1.get_delay_switch_id(), delay_pickup_3.get_delay_switch_id(), delay_pickup_5.get_delay_switch_id()]
		_expect(switch_ids == [&"delay_1s", &"delay_3s", &"delay_5s"], "Authored delay stations use unique stable ids")
		_expect(delay_pickup_3.default_active, "Start scene authors the 3-second station as default")
		_expect(delay_pickup_3.is_active(), "Default 3-second station starts active")
	_expect(scene.get_node_or_null("World/FutureRecorderA") is FutureRecorder, "Start scene authors future recorder A")
	_expect(scene.get_node_or_null("World/FutureRecorderB") is FutureRecorder, "Start scene authors future recorder B")
	var door := scene.get_node_or_null("World/TemporalDoor") as TemporalDoor
	var plate := scene.get_node_or_null("World/TemporalPressurePlate") as TemporalPressurePlate
	_expect(door != null, "Start scene authors one TemporalDoor")
	_expect(plate != null and plate.target_door == door, "Start pressure plate is explicitly wired to the TemporalDoor")
	_expect(scene.find_children("*", "EchoPlayer", true, false).size() == 1, "Start scene authors one EchoPlayer")
	_expect(scene.find_children("*", "PastEcho", true, false).size() == 1, "Start scene authors one PastEcho")
	_expect(scene.find_children("*", "FutureEcho", true, false).size() == 2, "Start scene authors two FutureEcho slots")
	_expect(scene.find_children("*", "EchoCheckpoint", true, false).size() == 1, "Start scene authors one EchoCheckpoint")
	_expect(scene.has_node("World/SpawnPoint"), "Start scene authors SpawnPoint")
	_expect(scene.has_node("World/FallResetArea"), "Start scene authors FallResetArea")
	_expect(scene.has_node("Backdrop/BaseColor"), "Start scene keeps a plain authored backdrop color")
	_expect(not scene.has_node("Backdrop/MapTexture"), "Start scene removes the temporary image backdrop")
	_expect(scene.has_node("UI/PauseScreen"), "Start scene authors PauseScreen")
	_expect(scene.has_node("UI/SettingScreen"), "Start scene authors SettingScreen")
	_expect(not scene.has_node("UI/TemporalEntryOverlay"), "Start scene removes the retired three-figure entry overlay")
	var pause_screen := scene.get_node_or_null("UI/PauseScreen") as PauseScreen
	if pause_screen != null:
		_expect(pause_screen.hint_button.disabled, "Start scene disables Hint")
	scene.queue_free()
	await process_frame


# 验证玩法入场冻结整条时间线，且普通离散输入只跳过一次入场。
func _test_gameplay_entry_intro() -> void:
	var original_low_flash := bool(SettingsModule.instance.get_value("low_flash_mode", false))
	SettingsModule.instance.set_value("low_flash_mode", false)
	LevelModule.instance.clear_checkpoint()
	var scene := (load(START_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	var controller := scene.get_node("SceneController")
	var timeline := scene.get_node("World/EchoTimelineController") as EchoTimelineController
	var world := scene.get_node("World") as Node2D
	_expect(bool(controller.call("is_entry_intro_active")), "Gameplay entry intro starts on new game and Continue scene load")
	_expect(world.process_mode == Node.PROCESS_MODE_DISABLED, "Gameplay entry intro freezes the authored world")
	var frozen_time := timeline.get_timeline_seconds()
	for _frame in 3:
		await physics_frame
	_expect(is_equal_approx(timeline.get_timeline_seconds(), frozen_time), "Gameplay entry time does not count toward the past delay")
	_send_key_event(KEY_SPACE, true)
	await process_frame
	_send_key_event(KEY_SPACE, false)
	_expect(not bool(controller.call("is_entry_intro_active")), "Any keyboard press skips the gameplay entry intro")
	_expect(world.process_mode == Node.PROCESS_MODE_PAUSABLE, "Skipping entry restores authored world processing")
	scene.queue_free()
	await process_frame

	SettingsModule.instance.set_value("low_flash_mode", true)
	var reduced_scene := (load(START_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(reduced_scene)
	await physics_frame
	var reduced_controller := reduced_scene.get_node("SceneController")
	_expect(
		reduced_controller.get("present_entry_transition") is SceneTransition
		and reduced_controller.get("past_entry_transition") is SceneTransition,
		"Gameplay entry authors matching present and past color fades"
	)
	reduced_scene.get_node("SceneController").call("skip_entry_intro")
	reduced_scene.queue_free()
	await process_frame
	SettingsModule.instance.set_value("low_flash_mode", original_low_flash)


# 验证激活存档点不清时间线，失败后从最新坐标建立干净时间线。
func _test_start_scene_checkpoint_and_reset() -> void:
	if not ResourceLoader.exists(START_SCENE_PATH):
		return
	LevelModule.instance.clear_checkpoint()
	var scene := (load(START_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	var player := scene.get_node("World/EchoPlayer") as EchoPlayer
	var timeline := scene.get_node("World/EchoTimelineController") as EchoTimelineController
	var checkpoint := scene.get_node("World/EchoCheckpoint") as EchoCheckpoint
	var delay_1s := scene.get_node("World/DelayPickup1s") as DelayPickup
	var delay_5s := scene.get_node("World/DelayPickup5s") as DelayPickup
	var controller := scene.get_node("SceneController")
	controller.call("skip_entry_intro")
	for _frame in 4:
		await physics_frame
	delay_5s.body_entered.emit(player)
	for _frame in 40:
		await physics_frame
	var time_before_checkpoint := timeline.get_timeline_seconds()
	checkpoint.body_entered.emit(player)
	await process_frame
	_expect(LevelModule.instance.has_continue_point(), "Checkpoint activation enables Continue data")
	var saved_checkpoint := LevelModule.instance.get_checkpoint()
	_expect(saved_checkpoint.get("past_delay_seconds", 0.0) == 5.0, "Checkpoint captures the selected 5-second delay")
	_expect(saved_checkpoint.get("delay_switch_id", "") == "delay_5s", "Checkpoint captures the exact 5-second station")
	_expect(timeline.get_timeline_seconds() >= time_before_checkpoint, "Checkpoint activation preserves the live timeline")
	var respawn_position := checkpoint.get_respawn_position()
	var completed_positions: Array[Vector2] = []
	var completed_timeline_seconds: Array[float] = []
	controller.connect(&"reset_completed", func(completed_position: Vector2) -> void:
		completed_positions.append(completed_position)
		completed_timeline_seconds.append(timeline.get_timeline_seconds())
	)
	delay_1s.body_entered.emit(player)
	for _frame in 40:
		await physics_frame
	_expect(timeline.get_selected_past_delay_seconds() == 1.0, "Live timeline may change after checkpoint activation")
	player.global_position = Vector2(1200.0, 100.0)
	timeline.player_caught.emit()
	for _frame in 40:
		if not completed_positions.is_empty():
			break
		await physics_frame
	_expect(not completed_positions.is_empty(), "Failure reset completes after its authored delay")
	if not completed_positions.is_empty():
		_expect(completed_positions.back().is_equal_approx(respawn_position), "Failure restores the latest checkpoint position")
		_expect(is_zero_approx(completed_timeline_seconds.back()), "Failure restarts from a clean timeline after repositioning")
		_expect(timeline.get_selected_past_delay_seconds() == 5.0, "Failure restores checkpoint delay instead of current live selection")
		_expect(timeline.get_selected_delay_switch_id() == &"delay_5s", "Failure restores checkpoint station id")
		_expect(delay_5s.is_active(), "Failure restores the checkpoint station visual")
	scene.queue_free()
	await process_frame


# 验证销毁并重建玩法场景后，Continue 恢复坐标、延迟台和干净时间线。
func _test_continue_restores_checkpoint_delay_station() -> void:
	if not ResourceLoader.exists(START_SCENE_PATH):
		return
	LevelModule.instance.clear_checkpoint()
	var first_scene := (load(START_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(first_scene)
	await physics_frame
	var first_player := first_scene.get_node("World/EchoPlayer") as EchoPlayer
	var first_checkpoint := first_scene.get_node("World/EchoCheckpoint") as EchoCheckpoint
	var first_delay_5s := first_scene.get_node("World/DelayPickup5s") as DelayPickup
	first_scene.get_node("SceneController").call("skip_entry_intro")
	first_delay_5s.body_entered.emit(first_player)
	first_checkpoint.body_entered.emit(first_player)
	await process_frame
	var expected_position := first_checkpoint.get_respawn_position()
	_expect(LevelModule.instance.has_continue_point(), "Activated checkpoint creates Continue data before scene reload")
	first_scene.queue_free()
	await process_frame

	var continued_scene := (load(START_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(continued_scene)
	await physics_frame
	var continued_player := continued_scene.get_node("World/EchoPlayer") as EchoPlayer
	var continued_timeline := continued_scene.get_node("World/EchoTimelineController") as EchoTimelineController
	var continued_delay_5s := continued_scene.get_node("World/DelayPickup5s") as DelayPickup
	_expect(continued_player.global_position.is_equal_approx(expected_position), "Continue restores the saved checkpoint position")
	_expect(continued_timeline.get_selected_past_delay_seconds() == 5.0, "Continue restores the saved five-second past delay")
	_expect(continued_timeline.get_selected_delay_switch_id() == &"delay_5s", "Continue restores the exact saved delay station id")
	_expect(continued_delay_5s.is_active(), "Continue restores the saved delay station visual")
	_expect(is_zero_approx(continued_timeline.get_timeline_seconds()), "Continue starts from a clean timeline")
	_expect(not continued_timeline.is_future_recording(), "Continue does not restore an in-progress future recording")
	_expect(continued_timeline.future_echo_a.is_available() and continued_timeline.future_echo_b.is_available(), "Continue starts with both future slots available")
	_expect(not continued_timeline.past_echo.is_active(), "Continue waits for the first delayed PastEcho materialization")
	continued_scene.queue_free()
	await process_frame
	LevelModule.instance.clear_checkpoint()


# 验证暂停页进入设置后，返回仍停在暂停页且不会提前恢复游戏。
func _test_start_scene_pause_settings_route() -> void:
	if not ResourceLoader.exists(START_SCENE_PATH):
		return
	LevelModule.instance.clear_checkpoint()
	var scene := (load(START_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	var pause_screen := scene.get_node("UI/PauseScreen") as PauseScreen
	var setting_screen := scene.get_node("UI/SettingScreen")
	pause_screen.opening_duration = 0.0
	pause_screen.closing_duration = 0.0
	setting_screen.set("opening_duration", 0.0)
	setting_screen.set("closing_duration", 0.0)
	_send_key_event(KEY_ESCAPE, true)
	await process_frame
	_send_key_event(KEY_ESCAPE, false)
	for _frame in 2:
		await process_frame
	_expect(paused and pause_screen.visible, "Escape opens the authored pause screen")
	pause_screen.setting_pressed.emit()
	for _frame in 3:
		await process_frame
	_expect(
		paused and bool(setting_screen.get("visible")) and not pause_screen.visible,
		"Settings opens while gameplay stays paused (paused=%s pause=%s settings=%s)" % [paused, pause_screen.visible, setting_screen.get("visible")]
	)
	setting_screen.call("request_return")
	for _frame in 3:
		await process_frame
	_expect(
		paused and pause_screen.visible and not bool(setting_screen.get("visible")),
		"Settings returns to pause without unpausing (paused=%s pause=%s settings=%s)" % [paused, pause_screen.visible, setting_screen.get("visible")]
	)
	pause_screen.continue_pressed.emit()
	for _frame in 3:
		await process_frame
	_expect(not paused and not pause_screen.visible, "Continue closes pause and resumes gameplay")
	paused = false
	scene.queue_free()
	await process_frame


# 验证未来录像使用 authored HUD、真实绑定文本及不拦截鼠标的装饰层。
func _test_temporal_recording_hud() -> void:
	if not ResourceLoader.exists(START_SCENE_PATH):
		return
	var original_low_flash := bool(SettingsModule.instance.get_value("low_flash_mode", false))
	var original_recall_event := KeybindingModule.instance.get_primary_event("echo_recall").duplicate() as InputEvent
	SettingsModule.instance.set_value("low_flash_mode", false)
	LevelModule.instance.clear_checkpoint()
	var scene := (load(START_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	var hud := scene.get_node_or_null("UI/TemporalRecordingHUD") as TemporalRecordingHUD
	var timeline := scene.get_node("World/EchoTimelineController") as EchoTimelineController
	var player := scene.get_node("World/EchoPlayer") as EchoPlayer
	var recorder := scene.get_node("World/FutureRecorderA") as FutureRecorder
	scene.get_node("SceneController").call("skip_entry_intro")
	_expect(hud != null, "Start scene authors TemporalRecordingHUD")
	if hud != null:
		_expect(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Recording HUD root ignores mouse input")
		for control in hud.find_children("*", "Control", true, false):
			_expect((control as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "Recording HUD decoration ignores mouse input")
		timeline.set_physics_process(false)
		player.set_physics_process(false)
		_expect(timeline.start_future_recording(recorder), "Recording HUD test starts a future recording")
		_expect(hud.is_recording_visible(), "Recording HUD appears when recording starts")
		_expect(player.is_recording_outline_visible(), "Player gains the authored gold recording outline")
		_advance_timeline(timeline, player, 2.5)
		_expect(is_equal_approx(hud.get_progress_ratio(), 0.5), "Recording HUD shows deterministic 0-5 second progress")
		var expected_binding := KeybindingModule.instance.get_primary_display_string("echo_recall")
		_expect(hud.get_recall_binding_text() == expected_binding, "Recording HUD shows the current echo_recall binding")
		var rebound_event := InputEventKey.new()
		rebound_event.physical_keycode = KEY_R
		KeybindingModule.instance.rebind_action_primary("echo_recall", rebound_event)
		_expect(
			hud.get_recall_binding_text() == KeybindingModule.instance.get_primary_display_string("echo_recall"),
			"Recording HUD refreshes immediately after echo_recall is rebound"
		)
		var hud_animation := hud.get_node("AnimationPlayer") as AnimationPlayer
		var player_animation := player.get_node("RecordingAnimationPlayer") as AnimationPlayer
		hud_animation.advance(0.36)
		player_animation.advance(0.3)
		var hud_ratio := hud_animation.current_animation_position / hud_animation.current_animation_length
		var player_ratio := player_animation.current_animation_position / player_animation.current_animation_length
		SettingsModule.instance.set_value("low_flash_mode", true)
		_expect(hud_animation.current_animation == &"recording_reduced", "Low-flash recording HUD uses the stable gold edge")
		_expect(player_animation.current_animation == &"recording_reduced", "Low-flash recording outline uses the stable authored animation")
		_expect(
			is_equal_approx(hud_animation.current_animation_position / hud_animation.current_animation_length, hud_ratio),
			"Recording HUD preserves normalized progress when low-flash changes"
		)
		_expect(
			is_equal_approx(player_animation.current_animation_position / player_animation.current_animation_length, player_ratio),
			"Player recording outline preserves normalized progress when low-flash changes"
		)
		SettingsModule.instance.set_value("low_flash_mode", false)
		_expect(hud_animation.current_animation == &"recording", "Recording HUD returns to its standard loop without restarting")
		_expect(player_animation.current_animation == &"recording", "Player recording outline returns to its standard loop without restarting")
		_expect(timeline.commit_future_recording(), "Recording HUD test commits the recording")
		_expect(not hud.is_recording_visible(), "Recording HUD hides after recall")
		_expect(not player.is_recording_outline_visible(), "Player recording outline hides after recall")
	KeybindingModule.instance.rebind_action_primary("echo_recall", original_recall_event)
	SettingsModule.instance.set_value("low_flash_mode", original_low_flash)
	scene.queue_free()
	await process_frame


# 验证主菜单的新游戏与继续游戏都指向用户可继续搭建的起始场景。
func _test_menu_entry_scene_contract() -> void:
	var menu := (load("res://Scenes/UI/Menu/menu.tscn") as PackedScene).instantiate()
	_expect(ProjectSettings.get_setting("application/config/name") == "延迟追迹 Delay Trace", "Project window uses the Delay Trace display name")
	var title_reveal := menu.get_node("ButtonLayer/TitleReveal") as Control
	var title := title_reveal.get_node("Title") as Label
	_expect(title.text == "延迟追迹 / DELAY TRACE", "Main menu uses the bilingual Delay Trace title")
	var title_width := title.get_theme_font(&"font").get_string_size(
		title.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		title.get_theme_font_size(&"font_size")
	).x
	_expect(
		(title_reveal.anchor_right - title_reveal.anchor_left) * 1280.0 >= title_width,
		"Delay Trace title fits the authored reveal at 1280x720"
	)
	_expect(menu.get("echo_chase_entry_scene_path") == START_SCENE_PATH, "Main menu authors the Echo Chase start scene path")
	var menu_music := menu.get("menu_music") as AudioStream
	_expect(
		menu_music != null and menu_music.resource_path == "res://assets/echo_chase/audio/music/mysterious_futuristic_loop.ogg",
		"Main menu uses the licensed Echo Chase temporal loop"
	)
	var background := menu.get_node_or_null("Background") as Control
	_expect(background != null, "Main menu authors a parallax background container")
	if background != null:
		var grid := background.get_node_or_null("Grid") as ColorRect
		var road := background.get_node_or_null("Road") as TileMapLayer
		var shader_material := grid.material as ShaderMaterial if grid != null else null
		_expect(
			shader_material != null and shader_material.shader.resource_path == "res://assets/echo_chase/vfx/menu_cross_grid.gdshader",
			"Main menu draws the monochrome cross grid with an authored shader"
		)
		_expect(road != null and road.tile_set != null, "Main menu authors its road as a TileMapLayer")
		if road != null:
			_expect(road.get_used_cells().size() == 31, "Menu road contains one authored 31-cell overscan row")
			_expect(road.get_used_rect().size.y == 1, "Menu TileMap keeps only one horizontal road row")
		_expect(
			background.offset_left <= -32.0 and background.offset_top <= -32.0
			and background.offset_right >= 32.0 and background.offset_bottom >= 32.0,
			"Main menu background overscan prevents parallax edge gaps"
		)
	_expect(not menu.has_node("PhaseEcho"), "Main menu no longer contains the retired Phase Lag echo overlay")
	var temporal_layer := menu.get_node_or_null("TemporalCharacterLayer") as Control
	_expect(temporal_layer != null, "Main menu authors a dedicated temporal character layer")
	if temporal_layer != null:
		_expect(temporal_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Menu temporal layer ignores mouse input")
		_expect(temporal_layer.position.is_zero_approx(), "Menu temporal characters do not follow mouse parallax")
		_expect(temporal_layer.find_children("*Trajectory*", "Line2D", true, false).is_empty(), "Menu removes all temporal trajectory lines")
		var region_names := ["PastRegion", "PresentRegion", "FutureRegion"]
		for region_index in region_names.size():
			var region := temporal_layer.get_node_or_null(region_names[region_index]) as Control
			_expect(region != null, "Menu authors temporal region %s" % region_names[region_index])
			if region == null:
				continue
			_expect(
				is_equal_approx(region.anchor_left, float(region_index) / 3.0)
				and is_equal_approx(region.anchor_right, float(region_index + 1) / 3.0),
				"Menu temporal region %s occupies one exact third" % region_names[region_index]
			)
			var figure := region.get_node_or_null("Figure") as Control
			_expect(
				figure != null
				and is_equal_approx(figure.anchor_left, 0.5)
				and is_equal_approx(figure.anchor_top, 0.54),
				"Menu temporal figure %s stays centered at y=54%%" % region_names[region_index]
			)
			if figure == null:
				continue
			var core := figure.get_node_or_null("Float/Core") as AnimatedSprite2D
			var outline := figure.get_node_or_null("Float/Outline") as AnimatedSprite2D
			_expect(region.get_node_or_null("LightBand") == null, "Menu temporal region %s removes the middle identity band" % region_names[region_index])
			_expect(core != null and core.material == null, "Menu temporal Core preserves original character pixels")
			_expect(
				outline != null
				and outline.sprite_frames.resource_path == "res://assets/echo_chase/character/echo_character_outline_frames.tres",
				"Menu temporal Outline uses padded 24px frames"
			)
			_expect(core != null and core.animation == &"idle", "Menu temporal Core idles in place")
			_expect(outline != null and outline.animation == &"idle", "Menu temporal Outline idles in place")
			if region_index == 0:
				_expect(figure.get_node_or_null("Float/HistoryGhost") is AnimatedSprite2D, "Past menu figure uses a backward history ghost")
				_expect(figure.get_node_or_null("Float/HistoryGhostFar") is AnimatedSprite2D, "Past menu figure uses a second backward history ghost")
			if region_index == 2:
				_expect(figure.get_node_or_null("Float/PredictionGhost") is AnimatedSprite2D, "Future menu figure uses a forward prediction ghost")
				_expect(figure.get_node_or_null("Float/OuterOutline") is AnimatedSprite2D, "Future menu figure uses a double outline")
	var menu_player := menu.get_node("MenuAnimationPlayer") as AnimationPlayer
	_expect(is_equal_approx(menu_player.get_animation(&"menu_enter").length, 1.8), "Menu entrance lasts 1.8 seconds")
	var reduced_intro := menu_player.get_animation(&"menu_enter_reduced")
	var reduced_button_paths: Array[NodePath] = [
		NodePath("ButtonLayer/RouteNav/MenuButtons/StartButton:position"),
		NodePath("ButtonLayer/RouteNav/MenuButtons/ContinueButton:position"),
		NodePath("ButtonLayer/RouteNav/MenuButtons/SettingButton:position"),
		NodePath("ButtonLayer/RouteNav/MenuButtons/ThanksButton:position"),
		NodePath("ButtonLayer/RouteNav/MenuButtons/ExitButton:position"),
	]
	for button_path in reduced_button_paths:
		_expect(
			reduced_intro.find_track(button_path, Animation.TYPE_VALUE) >= 0,
			"Low-flash menu entrance preserves staggered button motion for %s" % button_path
		)
	var phase_player := menu.get_node("PhaseCycleAnimationPlayer") as AnimationPlayer
	_expect(phase_player.has_animation(&"menu_idle"), "Menu authors a fixed temporal idle loop")
	if phase_player.has_animation(&"menu_idle"):
		_expect(is_equal_approx(phase_player.get_animation(&"menu_idle").length, 2.4), "Menu temporal float loop lasts 2.4 seconds")
	var temporal_frame := menu.get_node_or_null("TemporalFrame") as Control
	_expect(temporal_frame != null, "Menu authors a dedicated three-part temporal edge frame")
	if temporal_frame != null:
		var line_layer := temporal_frame.get_node_or_null("Lines") as Control
		var glow_layer := temporal_frame.get_node_or_null("Glow") as Control
		_expect(line_layer != null and glow_layer != null, "Temporal edge frame separates thin lines from optional glow")
		if line_layer != null:
			for segment_name in ["TopPast", "TopPresent", "TopFuture", "BottomPast", "BottomPresent", "BottomFuture"]:
				_expect(line_layer.get_node_or_null(segment_name) is ColorRect, "Temporal frame authors %s" % segment_name)
			var first_divider := line_layer.get_node_or_null("DividerPastPresent") as Control
			var second_divider := line_layer.get_node_or_null("DividerPresentFuture") as Control
			_expect(first_divider != null and second_divider != null, "Temporal frame authors both one-third dividers")
			if first_divider != null:
				var past_side := first_divider.get_node("PastSide") as ColorRect
				var present_side := first_divider.get_node("PresentSide") as ColorRect
				_expect(not past_side.color.is_equal_approx(present_side.color), "Past/present divider keeps adjacent colors separate")
			if second_divider != null:
				var present_side := second_divider.get_node("PresentSide") as ColorRect
				var future_side := second_divider.get_node("FutureSide") as ColorRect
				_expect(not present_side.color.is_equal_approx(future_side.color), "Present/future divider keeps adjacent colors separate")
	var frame_player := menu.get_node_or_null("FrameAnimationPlayer") as AnimationPlayer
	_expect(
		frame_player != null and frame_player.has_animation(&"frame_standard") and frame_player.has_animation(&"frame_reduced"),
		"Menu authors standard and low-flash temporal frame animations"
	)
	_expect(menu.get_node_or_null("ButtonLayer/TitleReveal") != null, "Menu title uses an authored clipping reveal")
	var start_transition := menu.get("start_transition") as SceneTransition
	var start_transition_reduced := menu.get("start_transition_reduced") as SceneTransition
	var continue_transition := menu.get("continue_transition") as SceneTransition
	var continue_transition_reduced := menu.get("continue_transition_reduced") as SceneTransition
	_expect(
		start_transition != null and start_transition.gradient_texture != null
		and start_transition.color.is_equal_approx(Color(0.7, 1.0, 1.0)),
		"Start authors the present-centered cyan radial transition"
	)
	_expect(
		continue_transition != null and continue_transition.gradient_texture != null
		and continue_transition.color.is_equal_approx(Color(1.0, 0.24, 0.82)),
		"Continue authors the past-centered magenta radial transition"
	)
	_expect(
		start_transition != null and is_equal_approx(start_transition.duration, 0.65)
		and continue_transition != null and is_equal_approx(continue_transition.duration, 0.65),
		"Standard temporal radial transitions last 0.65 seconds"
	)
	_expect(
		start_transition_reduced != null and is_equal_approx(start_transition_reduced.duration, 0.9)
		and continue_transition_reduced != null and is_equal_approx(continue_transition_reduced.duration, 0.9),
		"Low-flash temporal radial transitions expand over 0.9 seconds"
	)
	var transition_player := menu.get_node_or_null("TransitionAnimationPlayer") as AnimationPlayer
	_expect(
		transition_player != null
		and transition_player.has_animation(&"pulse_present")
		and transition_player.has_animation(&"pulse_past"),
		"Menu authors separate present and past origin pulses"
	)
	var route_nav := menu.get_node("ButtonLayer/RouteNav") as Control
	var route_line := menu.get_node("ButtonLayer/RouteNav/RouteLine") as ColorRect
	var first_marker := menu.get_node("ButtonLayer/RouteNav/Marker1") as ColorRect
	var last_marker := menu.get_node("ButtonLayer/RouteNav/Marker5") as ColorRect
	_expect(route_nav.anchor_top >= 0.55, "Main menu route sits in the lower-right map area")
	_expect(route_line.offset_top >= first_marker.offset_top and route_line.offset_bottom <= last_marker.offset_bottom, "Menu route line stops between its first and last nodes")
	menu.free()


# 验证菜单入场和边缘框在运行中切换低闪时保留各自进度。
func _test_menu_follows_low_flash_mode() -> void:
	var original_low_flash := bool(SettingsModule.instance.get_value("low_flash_mode", false))
	SettingsModule.instance.set_value("low_flash_mode", false)
	var menu := (load("res://Scenes/UI/Menu/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	var intro_player := menu.get_node("MenuAnimationPlayer") as AnimationPlayer
	var frame_player := menu.get_node_or_null("FrameAnimationPlayer") as AnimationPlayer
	_expect(frame_player != null, "Live menu provides its authored frame animation player")
	if frame_player == null:
		menu.queue_free()
		await process_frame
		SettingsModule.instance.set_value("low_flash_mode", original_low_flash)
		return
	intro_player.advance(0.45)
	frame_player.advance(0.6)
	var intro_ratio := intro_player.current_animation_position / intro_player.current_animation_length
	var frame_ratio := frame_player.current_animation_position / frame_player.current_animation_length
	SettingsModule.instance.set_value("low_flash_mode", true)
	_expect(intro_player.current_animation == &"menu_enter_reduced", "Menu intro immediately enters its reduced authored animation")
	_expect(frame_player.current_animation == &"frame_reduced", "Menu edge frame immediately becomes fixed low-flash lines")
	_expect(
		is_equal_approx(intro_player.current_animation_position / intro_player.current_animation_length, intro_ratio),
		"Menu intro preserves normalized progress when low-flash changes"
	)
	_expect(
		is_equal_approx(frame_player.current_animation_position / frame_player.current_animation_length, frame_ratio),
		"Menu frame preserves normalized progress when low-flash changes"
	)
	SettingsModule.instance.set_value("low_flash_mode", false)
	_expect(intro_player.current_animation == &"menu_enter", "Menu intro returns to standard feedback without restarting")
	_expect(frame_player.current_animation == &"frame_standard", "Menu edge frame returns to breathing feedback without restarting")
	menu.queue_free()
	await process_frame
	SettingsModule.instance.set_value("low_flash_mode", original_low_flash)


# 验证黑白地图 UI 不再依赖旧玻璃卡片、装饰小字或每行面板。
func _test_ui_visual_contract() -> void:
	var menu := (load("res://Scenes/UI/Menu/menu.tscn") as PackedScene).instantiate()
	_expect(not menu.has_node("ButtonLayer/Header"), "Main menu has no title card")
	_expect(not menu.has_node("ButtonLayer/MenuPanel"), "Main menu has no command card")
	_expect(menu.find_child("TechnicalMark", true, false) == null, "Main menu omits decorative technical copy")
	_expect(menu.find_child("Subtitle", true, false) == null, "Main menu omits decorative subtitle copy")
	menu.free()

	var shader_button := (load("res://Scenes/UIorgan/ShaderButton/shader_button.tscn") as PackedScene).instantiate()
	_expect(shader_button.has_node("PressAudio"), "ShaderButton preserves the shared press-audio contract")
	_expect(not shader_button.has_node("Panel"), "ShaderButton no longer authors a card panel")
	_expect(not shader_button.has_node("Label"), "ShaderButton uses the root Button text directly")
	_expect(not shader_button.has_node("ButtonEffectModule"), "ShaderButton removes the retired effect module")
	shader_button.free()

	var settings := (load("res://Scenes/UI/Menu/setting_screen.tscn") as PackedScene).instantiate()
	var hint := settings.find_child("HintLabel", true, false) as Label
	_expect(hint == null, "Settings removes explanatory microcopy")
	_expect(settings.find_child("VerticalRule", true, false) == null, "Settings removes the central vertical rule")
	_expect(settings.find_child("GlassBlur", true, false) == null, "Settings removes the glass blur layer")
	_expect(settings.find_child("AuthoredPanel", true, false) == null, "Settings removes the old NinePatch card")
	var vsync_toggle := settings.find_child("VSyncToggle", true, false) as Button
	_expect(vsync_toggle != null, "Settings uses a text-only VSync toggle")
	if vsync_toggle != null:
		_expect(vsync_toggle.theme_type_variation == &"TextToggle", "Settings toggle uses the underline-only theme variation")
	_expect(not (settings.find_child("VSyncToggle", true, false) is CheckButton), "Settings does not draw a duplicate CheckButton indicator")
	settings.free()

	var thanks := (load("res://Scenes/UI/Menu/thank_screen.tscn") as PackedScene).instantiate()
	_expect(thanks.find_child("Subtitle", true, false) == null, "Credits omits explanatory subtitle copy")
	_expect(thanks.find_child("GlassBlur", true, false) == null, "Credits removes the glass blur layer")
	_expect(thanks.find_child("VerticalRule", true, false) == null, "Credits removes the central vertical rule")
	var credits_text := thanks.find_child("CreditsText", true, false) as RichTextLabel
	_expect(credits_text != null and "https://sayori.org" in credits_text.text, "Credits links Amiya_desi to sayori.org")
	_expect(
		credits_text != null and "mysterious-futuristic-8-bit-music-loop" in credits_text.text,
		"Credits link the authored Frenchyboy music source"
	)
	thanks.free()

	var pause := (load("res://Scenes/UI/PauseScreen/pause_screen.tscn") as PackedScene).instantiate()
	var hint_button := pause.find_child("HintButton", true, false) as Button
	_expect(hint_button != null and not hint_button.visible, "Pause hides unavailable hint commands")
	_expect(pause.find_child("GlassBlur", true, false) == null, "Pause removes the glass blur layer")
	_expect(pause.find_child("RailRule", true, false) == null, "Pause removes the redundant rail divider")
	pause.free()

	var keybindings := (load("res://Scenes/EchoChase/UI/echo_keybinding_ui.tscn") as PackedScene).instantiate()
	var rows := keybindings.get_node_or_null("Rows") as VBoxContainer
	_expect(rows != null, "Keybindings use full-width authored rows")
	_expect(keybindings.find_children("*", "HSeparator", true, false).size() == 8, "Keybindings separate every complete row with a horizontal line")
	_expect(keybindings.find_child("MoveLeftLine", true, false) == null, "Keybindings remove the old middle connector lines")
	_expect(keybindings.find_child("Header", true, false) == null, "Keybindings omit redundant header copy")
	_expect(keybindings.find_child("Hint", true, false) == null, "Keybindings omit redundant hint copy")
	keybindings.free()

	var feedback := (load("res://Scenes/UI/Common/feedback_overlay.tscn") as PackedScene).instantiate()
	var toast_margin := feedback.get_node("ToastMargin") as Control
	for control in toast_margin.find_children("*", "Control", true, false):
		_expect((control as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "Every Toast descendant ignores mouse input")
	_expect(toast_margin.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Toast root ignores mouse input")
	feedback.free()


# 使用真实鼠标按下与松开，验证文本开关不会在按住时提前改变。
func _test_toggle_changes_on_release() -> void:
	var original_low_flash := bool(SettingsModule.instance.get_value("low_flash_mode", false))
	SettingsModule.instance.set_value("low_flash_mode", false)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.handle_input_locally = true
	root.add_child(viewport)
	var settings := (load("res://Scenes/UI/Menu/setting_screen.tscn") as PackedScene).instantiate()
	viewport.add_child(settings)
	await process_frame
	var toggle := settings.find_child("LowFlashToggle", true, false) as Button
	_expect(toggle.text == "[ OFF ]", "Low-flash toggle starts from its released OFF state")
	var toggle_center := toggle.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = toggle_center
	viewport.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = toggle_center
	press.pressed = true
	viewport.push_input(press, true)
	await process_frame
	_expect(toggle.text == "[ OFF ]" and not toggle.button_pressed, "Holding a toggle does not change its committed text state")
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	viewport.push_input(release, true)
	await process_frame
	_expect(toggle.text == "[ ON ]" and toggle.button_pressed, "Releasing a toggle commits its ON state")
	viewport.queue_free()
	await process_frame
	SettingsModule.instance.set_value("low_flash_mode", original_low_flash)


# 使用真实 Viewport 输入确认高层 Toast 不再吞掉下方按钮点击。
func _test_feedback_toast_mouse_passthrough() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.handle_input_locally = true
	root.add_child(viewport)
	var overlay := (load("res://Scenes/UI/Common/feedback_overlay.tscn") as PackedScene).instantiate()
	viewport.add_child(overlay)
	var toast_margin := overlay.get_node("ToastMargin") as Control
	var toast_panel := overlay.get_node("ToastMargin/ToastPanel") as PanelContainer
	toast_panel.visible = true
	await process_frame
	var click_layer := CanvasLayer.new()
	var button := Button.new()
	var toast_rect := toast_margin.get_global_rect()
	button.position = toast_rect.position
	button.size = toast_rect.size
	click_layer.add_child(button)
	viewport.add_child(click_layer)
	var presses: Array[bool] = []
	button.pressed.connect(func() -> void: presses.append(true))
	var motion := InputEventMouseMotion.new()
	motion.position = toast_rect.get_center()
	viewport.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = toast_rect.get_center()
	press.pressed = true
	viewport.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	viewport.push_input(release, true)
	await process_frame
	_expect(not presses.is_empty(), "Viewport click passes through the visible Toast subtree")
	viewport.queue_free()
	await process_frame


# Verifies that a path replay can sample between two ordinary physics frames.
func _test_track_interpolates_continuous_motion() -> void:
	var track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
	track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(100.0, 20.0)))
	var sample: TemporalFrame = track.sample_at(0.5)
	_expect(sample != null, "TemporalTrack returns a midpoint sample")
	if sample != null:
		_expect(sample.position.is_equal_approx(Vector2(50.0, 10.0)), "TemporalTrack interpolates continuous position")


# Verifies that a recall is an instant discontinuity instead of an early teleport.
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


# 验证玩家公开移动状态，并将全部手感参数暴露到 Inspector。
func _test_player_state_and_tuning_contract() -> void:
	var player := (load("res://Scenes/EchoChase/Prefabs/echo_player.tscn") as PackedScene).instantiate() as EchoPlayer
	_expect(player.has_method("get_current_state"), "EchoPlayer exposes its current movement state")
	var expected_defaults := {
		"run_speed": 250.0,
		"run_acceleration": 4096.0,
		"jump_speed": 400.0,
		"jump_release_multiplier": 0.5,
		"coyote_seconds": 0.15,
		"jump_buffer_seconds": 0.15,
		"gravity": 980.0,
		"wall_slide_speed": 250.0,
		"wall_coyote_seconds": 0.12,
		"wall_jump_speed_x": 250.0,
		"wall_push_seconds": 0.10,
		"dash_aim_seconds": 0.10,
		"dash_speed": 600.0,
		"dash_seconds": 0.10,
		"dash_jump_momentum": 0.65,
		"dash_speed_cap_multiplier": 1.6,
		"dash_input_recovery_seconds": 0.06,
	}
	var exported_properties := {}
	for property in player.get_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR:
			exported_properties[property.name] = player.get(property.name)
	for property_name in expected_defaults:
		_expect(exported_properties.has(property_name), "EchoPlayer exports %s for Inspector tuning" % property_name)
		if exported_properties.has(property_name):
			_expect(is_equal_approx(float(exported_properties[property_name]), expected_defaults[property_name]), "EchoPlayer keeps the default value for %s" % property_name)
	player.free()


# 验证公开状态跟随真实地面、墙面、跳跃、冲刺和冻结流程。
func _test_player_movement_state_transitions() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	_add_static_collision(fixture, Vector2(0.0, 16.0), Vector2(320.0, 16.0))
	_add_static_collision(fixture, Vector2(48.0, -36.0), Vector2(16.0, 104.0))
	root.add_child(fixture)
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	var states: Dictionary = player.get_script().get_script_constant_map().get("State", {})
	_expect(states.size() == 8, "EchoPlayer exposes the eight planned movement states")
	player.reset_player(Vector2.ZERO)
	for _frame in 4:
		await physics_frame
	_expect(player.call("get_current_state") == states.get("IDLE"), "Player settles into IDLE on the floor")
	Input.action_press("echo_move_right")
	for _frame in 2:
		await physics_frame
	_expect(player.call("get_current_state") == states.get("RUN"), "Horizontal input changes IDLE to RUN")
	Input.action_release("echo_move_right")
	_send_key_event(KEY_K, true)
	await physics_frame
	_send_key_event(KEY_K, false)
	_expect(player.call("get_current_state") == states.get("JUMP"), "Ground jump changes RUN to JUMP")
	var saw_fall := false
	for _frame in 90:
		await physics_frame
		if player.call("get_current_state") == states.get("FALL"):
			saw_fall = true
			break
	_expect(saw_fall, "Jump apex changes JUMP to FALL")
	player.reset_player(Vector2(35.0, -44.0))
	player.velocity = Vector2(0.0, 80.0)
	Input.action_press("echo_move_right")
	var saw_wall_slide := false
	for _frame in 45:
		await physics_frame
		if player.call("get_current_state") == states.get("WALL_SLIDE"):
			saw_wall_slide = true
			break
	Input.action_release("echo_move_right")
	_expect(saw_wall_slide, "Falling against a wall changes FALL to WALL_SLIDE")
	player.reset_player(Vector2.ZERO)
	for _frame in 4:
		await physics_frame
	_send_key_event(KEY_J, true)
	await physics_frame
	_send_key_event(KEY_J, false)
	_expect(player.call("get_current_state") == states.get("DASH_AIM"), "Dash input enters DASH_AIM")
	var saw_dash := false
	for _frame in 20:
		await physics_frame
		if player.call("get_current_state") == states.get("DASH"):
			saw_dash = true
	_expect(saw_dash, "Dash aim completes into DASH")
	player.prepare_for_reset(&"hit")
	_expect(player.call("get_current_state") == states.get("DISABLED"), "Failure freeze enters DISABLED")
	player.reset_player(Vector2.ZERO)
	_expect(player.call("get_current_state") == states.get("IDLE"), "Checkpoint reset returns to IDLE")
	fixture.queue_free()
	await process_frame


# Verifies that a real player consumes the authored horizontal input bindings.
func _test_player_moves_from_authored_input() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	_expect(player != null and timeline != null, "Echo timeline fixture instantiates its required nodes")
	if player != null and timeline != null:
		_expect(timeline.player == player, "Echo timeline fixture wires the authored player reference")
		Input.action_press("echo_move_right")
		await physics_frame
		await physics_frame
		Input.action_release("echo_move_right")
		_expect(player.velocity.x > 0.0, "EchoPlayer gains horizontal velocity from the move input")
		var dash_vfx := player.get_node("DashVfx") as EchoDashVfx
		_send_key_event(KEY_J, true)
		await physics_frame
		_send_key_event(KEY_J, false)
		_expect(dash_vfx.is_active(), "Dash input starts the authored dash VFX on the response frame")
		for _frame in 20:
			await physics_frame
		_expect(not dash_vfx.is_active(), "Dash VFX ends after the aim and movement envelope")
	fixture.queue_free()
	await process_frame


# 验证冲刺途中开启低闪会立即收掉高频反馈，关闭后不补播本次粒子。
func _test_dash_vfx_follows_low_flash_mode() -> void:
	var original_low_flash := bool(SettingsModule.instance.get_value("low_flash_mode", false))
	SettingsModule.instance.set_value("low_flash_mode", false)
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	var source := player.get_node("Visual") as AnimatedSprite2D
	var dash_vfx := player.get_node("DashVfx") as EchoDashVfx
	dash_vfx.begin(source, Vector2.RIGHT)
	dash_vfx.start_animation_player.advance(0.08)
	dash_vfx.update_dash(source, 0.04, Vector2.RIGHT)
	var start_ratio := dash_vfx.start_animation_player.current_animation_position / dash_vfx.start_animation_player.current_animation_length
	SettingsModule.instance.set_value("low_flash_mode", true)
	_expect(dash_vfx.start_animation_player.current_animation == &"start_reduced", "Active dash immediately enters reduced start feedback")
	_expect(not dash_vfx.start_burst.emitting and not dash_vfx.direction_particles.emitting, "Enabling low-flash immediately stops active dash particles")
	_expect(not dash_vfx.afterimage_c.visible, "Low-flash immediately removes the third dash afterimage")
	_expect(
		is_equal_approx(dash_vfx.start_animation_player.current_animation_position / dash_vfx.start_animation_player.current_animation_length, start_ratio),
		"Dash start feedback preserves normalized progress"
	)
	SettingsModule.instance.set_value("low_flash_mode", false)
	dash_vfx.update_dash(source, 0.04, Vector2.RIGHT)
	_expect(dash_vfx.start_animation_player.current_animation == &"start", "Active dash returns to the standard ring without restarting")
	_expect(not dash_vfx.direction_particles.emitting, "Disabling low-flash does not resume particles during the same dash")
	dash_vfx.reset_vfx()
	fixture.queue_free()
	await process_frame
	SettingsModule.instance.set_value("low_flash_mode", original_low_flash)


# 验证新命名物理层、玩家 Hurtbox 和 authored Trap 使用同一失败入口。
func _test_physics_layer_and_trap_contract() -> void:
	var player_scene := load("res://Scenes/EchoChase/Prefabs/echo_player.tscn") as PackedScene
	var player := player_scene.instantiate() as EchoPlayer
	_expect(player.collision_layer == 2 and player.collision_mask == 1, "Player body uses Player and World physics layers")
	_expect(not player.is_in_group("temporal_player"), "Player identity no longer duplicates its physics layer in a Scene Group")
	var hurtbox := player.get_node_or_null("Hurtbox") as Area2D
	_expect(hurtbox != null, "EchoPlayer authors a dedicated Trap Hurtbox")
	if hurtbox != null:
		_expect(hurtbox.collision_layer == 0 and hurtbox.collision_mask == 32, "Player Hurtbox only monitors the Trap layer")
	player.free()

	var past := (load("res://Scenes/EchoChase/Prefabs/past_echo.tscn") as PackedScene).instantiate() as PastEcho
	var future := (load("res://Scenes/EchoChase/Prefabs/future_echo.tscn") as PackedScene).instantiate() as FutureEcho
	_expect(past.collision_layer == 4 and past.collision_mask == 10, "PastEcho monitors Player and Future Echo layers")
	_expect(future.collision_layer == 8 and future.collision_mask == 2, "FutureEcho only monitors the Player layer")
	_expect(not past.is_in_group("temporal_past"), "PastEcho identity uses its type and physics layer")
	_expect(not future.is_in_group("temporal_future"), "FutureEcho identity uses its type and physics layer")
	past.free()
	future.free()
	var checkpoint := (load("res://Scenes/EchoChase/Prefabs/echo_checkpoint.tscn") as PackedScene).instantiate() as EchoCheckpoint
	_expect(not checkpoint.is_in_group("echo_checkpoint"), "Checkpoint identity uses explicit authored references")
	checkpoint.free()

	var trap_path := "res://Scenes/EchoChase/Prefabs/echo_trap.tscn"
	_expect(ResourceLoader.exists(trap_path), "Echo Chase provides an authored Area2D Trap prefab")
	if ResourceLoader.exists(trap_path):
		var trap := (load(trap_path) as PackedScene).instantiate() as Area2D
		_expect(trap.collision_layer == 32 and trap.collision_mask == 2, "Authored Trap uses the Trap and Player layers")
		_expect(not trap.is_in_group("echo_trap"), "Trap identity uses the Trap physics layer")
		trap.free()

		var fixture := TIMELINE_FIXTURE.instantiate()
		root.add_child(fixture)
		var live_player := fixture.get_node("EchoPlayer") as EchoPlayer
		var live_trap := (load(trap_path) as PackedScene).instantiate() as Area2D
		fixture.add_child(live_trap)
		var failure_animations: Array[StringName] = []
		live_player.failure_requested.connect(func(animation_name: StringName) -> void: failure_animations.append(animation_name))
		live_player.global_position = Vector2.ZERO
		live_trap.global_position = Vector2.ZERO
		await physics_frame
		await physics_frame
		_expect(failure_animations.has(&"death"), "Player Hurtbox detects a real authored Trap Area overlap")
		fixture.queue_free()
	await process_frame


# Verifies that the permanent echo has no visual or collision presence before history exists.
func _test_past_echo_starts_out_of_the_world() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	if timeline != null:
		_expect(not timeline.past_echo.visible, "PastEcho is hidden before the timeline reaches its delay")
		_expect(timeline.past_echo.collision_shape.disabled, "PastEcho has no collision before the timeline reaches its delay")
	fixture.queue_free()
	await process_frame


# 验证每条干净时间线都先预显过去轮廓，再按真实延迟启用碰撞。
func _test_past_echo_previews_each_clean_timeline() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	if timeline != null and player != null:
		timeline.set_physics_process(false)
		player.set_physics_process(false)
		for reset_index in 2:
			timeline.reset_timeline(1.0, &"delay_1s")
			_advance_timeline(timeline, player, 0.8)
			_expect(timeline.past_echo.is_materializing(), "PastEcho previews before activation on clean timeline %d" % reset_index)
			_expect(not timeline.past_echo.is_active(), "PastEcho preview has no gameplay collision on clean timeline %d" % reset_index)
			_advance_timeline(timeline, player, 0.3)
			_expect(timeline.past_echo.is_active(), "PastEcho activates at the delayed history on clean timeline %d" % reset_index)
	fixture.queue_free()
	await process_frame


# Verifies that dissipating a future possibility releases its real authored plate overlap.
func _test_future_echo_releases_a_pressure_plate() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var plate := fixture.get_node("TemporalPressurePlate") as TemporalPressurePlate
	var door := fixture.get_node("TemporalDoor") as TemporalDoor
	if timeline != null and plate != null and door != null:
		var track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, plate.global_position))
		track.append(TEMPORAL_FRAME_SCRIPT.new(10.0, plate.global_position))
		timeline.future_echo_a.start_playback(track, 10.0, 0.0)
		await physics_frame
		_expect(plate.is_pressed(), "FutureEcho presses an authored temporal pressure plate")
		_expect(door.is_open(), "Temporal pressure plate opens its authored door")
		timeline.future_echo_a.dissipate()
		await physics_frame
		await physics_frame
		_expect(not plate.is_pressed(), "FutureEcho dissipation releases its temporal pressure plate")
		_expect(not door.is_open(), "Released temporal pressure plate closes its authored door")
	fixture.queue_free()
	await process_frame


# 验证两个未来体按各自录像长度结束，不共享倒计时。
func _test_future_echoes_use_independent_durations() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var short_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	short_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
	short_track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(32.0, 0.0)))
	var long_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	long_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2(96.0, 0.0)))
	long_track.append(TEMPORAL_FRAME_SCRIPT.new(3.0, Vector2(192.0, 0.0)))
	timeline.future_echo_a.start_playback(short_track, 1.0, 0.0)
	timeline.future_echo_b.start_playback(long_track, 3.0, 0.0)
	timeline.future_echo_a.advance(1.1)
	timeline.future_echo_b.advance(1.1)
	_expect(timeline.future_echo_a.is_available(), "One-second FutureEcho releases at its own duration")
	_expect(not timeline.future_echo_b.is_available(), "Longer FutureEcho remains active when the short one ends")
	timeline.future_echo_b.advance(2.0)
	_expect(timeline.future_echo_b.is_available(), "Longer FutureEcho releases only after its own duration")
	fixture.queue_free()
	await process_frame


# 验证过去体同一时刻覆盖多个未来体时允许全部消散并各自保留尾效。
func _test_past_dissipates_overlapping_futures_together() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	timeline.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = Vector2(500.0, 0.0)
	var shared_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	shared_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO, Vector2(80.0, 0.0)))
	shared_track.append(TEMPORAL_FRAME_SCRIPT.new(4.0, Vector2(320.0, 0.0), Vector2(80.0, 0.0)))
	timeline.future_echo_a.start_playback(shared_track, 4.0, 0.0)
	timeline.future_echo_b.start_playback(shared_track, 4.0, 0.0)
	timeline.past_echo.play_at(shared_track, 0.0)
	timeline.past_echo.area_entered.emit(timeline.future_echo_a)
	timeline.past_echo.area_entered.emit(timeline.future_echo_b)
	_expect(timeline.future_echo_a.is_available() and timeline.future_echo_b.is_available(), "PastEcho dissipates every overlapping FutureEcho")
	_expect(
		(timeline.future_echo_a.get_node("DepartureVfx") as TemporalDepartureVfx).is_playing()
		and (timeline.future_echo_b.get_node("DepartureVfx") as TemporalDepartureVfx).is_playing(),
		"Each dissipated FutureEcho keeps an independent amber departure"
	)
	fixture.queue_free()
	await process_frame


# Verifies the visible recording-to-recall loop through the authored recorder and input binding.
func _test_recorder_commits_a_future_echo_from_recall_input() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	var recorder := fixture.get_node("FutureRecorder") as FutureRecorder
	if timeline != null and player != null and recorder != null:
		var slot_counts: Array[int] = []
		timeline.future_slots_changed.connect(func(used_slots: int, _max_slots: int) -> void: slot_counts.append(used_slots))
		player.global_position = Vector2.ZERO
		recorder.global_position = Vector2.ZERO
		await physics_frame
		await physics_frame
		_expect(timeline.is_future_recording(), "FutureRecorder starts an authored future recording on player entry")
		timeline.set_physics_process(false)
		player.set_physics_process(false)
		_advance_timeline(timeline, player, 1.1)
		_expect(timeline.get_future_recording_seconds() >= 1.0, "Deterministic recording reaches the one-second minimum")
		_send_key_event(KEY_L, true)
		player._physics_process(0.0)
		_send_key_event(KEY_L, false)
		_expect(not timeline.is_future_recording(), "Recall input commits a recording after its minimum duration")
		_expect(not timeline.future_echo_a.is_available(), "Committed recording occupies an authored future echo")
		_expect(player.is_temporally_phased(), "Recall grants the current player its authored separation phase")
		_expect(slot_counts.has(1), "Starting a recording emits one used future slot")
	fixture.queue_free()
	await process_frame


# 验证记录器明确显示录制、等待离开，并在离开后重新可用。
func _test_recorder_state_feedback_and_reuse() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	var recorder := fixture.get_node("FutureRecorder") as FutureRecorder
	if timeline != null and player != null and recorder != null:
		timeline.set_physics_process(false)
		player.set_physics_process(false)
		_expect(recorder.call("get_state_name") == &"ready", "FutureRecorder starts in READY state")
		recorder.body_entered.emit(player)
		_expect(recorder.call("get_state_name") == &"recording", "FutureRecorder shows RECORDING while capturing a possibility")
		_expect(timeline.commit_future_recording(), "FutureRecorder state test commits the first recording")
		_expect(recorder.call("get_state_name") == &"waiting_exit", "FutureRecorder shows WAITING_EXIT after recall")
		recorder.body_entered.emit(player)
		_expect(not timeline.is_future_recording(), "FutureRecorder cannot retrigger before the player leaves")
		recorder.body_exited.emit(player)
		_expect(recorder.call("get_state_name") == &"ready", "FutureRecorder returns to READY after the player leaves")
		recorder.body_entered.emit(player)
		_expect(timeline.is_future_recording(), "The same FutureRecorder starts another recording after re-entry")
		timeline.reset_timeline()
		_expect(recorder.call("get_state_name") == &"waiting_exit", "Timeline reset leaves an occupied recorder waiting for a clean exit")
		recorder.body_exited.emit(player)
		_expect(recorder.call("get_state_name") == &"ready", "Recorder becomes READY after leaving following a timeline reset")
	fixture.queue_free()
	await process_frame


# 验证首帧回传补足一秒，录制中碰到过去体也只提交而不失败。
func _test_first_frame_recording_and_past_contact_commit() -> void:
	var short_fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(short_fixture)
	await physics_frame
	var short_timeline := short_fixture.get_node("EchoTimelineController") as EchoTimelineController
	var short_player := short_fixture.get_node("EchoPlayer") as EchoPlayer
	var short_recorder := short_fixture.get_node("FutureRecorder") as FutureRecorder
	if short_timeline != null and short_player != null and short_recorder != null:
		short_timeline.set_physics_process(false)
		short_player.set_physics_process(false)
		_expect(short_timeline.start_future_recording(short_recorder), "Future recording starts for first-frame recall")
		_expect(short_timeline.commit_future_recording(), "Future recording commits on its first frame")
		short_timeline.future_echo_a.advance(0.99)
		_expect(not short_timeline.future_echo_a.is_available(), "Short recording holds its final frame until one second")
		short_timeline.future_echo_a.advance(0.02)
		_expect(short_timeline.future_echo_a.is_available(), "Padded short recording releases after one second")
	short_fixture.queue_free()
	await process_frame

	var contact_fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(contact_fixture)
	await physics_frame
	var contact_timeline := contact_fixture.get_node("EchoTimelineController") as EchoTimelineController
	var contact_player := contact_fixture.get_node("EchoPlayer") as EchoPlayer
	var contact_recorder := contact_fixture.get_node("FutureRecorder") as FutureRecorder
	if contact_timeline != null and contact_player != null and contact_recorder != null:
		contact_timeline.set_physics_process(false)
		contact_player.set_physics_process(false)
		var failures: Array[bool] = []
		contact_timeline.player_caught.connect(func() -> void: failures.append(true))
		_expect(contact_timeline.start_future_recording(contact_recorder), "Future recording starts before past contact")
		var past_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		past_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, contact_player.global_position))
		contact_timeline.past_echo.play_at(past_track, 0.0)
		contact_timeline.past_echo.body_entered.emit(contact_player)
		_expect(not contact_timeline.is_future_recording(), "Past contact commits the current recording")
		_expect(not contact_timeline.future_echo_a.is_available(), "Past contact creates the reserved future echo")
		_expect(contact_player.is_temporally_phased(), "Past-contact recall grants separation phase")
		_expect(failures.is_empty(), "Past contact during recording does not trigger checkpoint failure")
	contact_fixture.queue_free()
	await process_frame


# 验证切档采用最新目标，同时不重置已开始的0.6秒预警。
func _test_delay_pickup_values_apply_after_a_phase_warning() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	if timeline != null and player != null:
		var observed_delays: Array[float] = []
		var observed_switches: Array[StringName] = []
		timeline.past_delay_changed.connect(func(seconds: float, switch_id: StringName) -> void:
			observed_delays.append(seconds)
			observed_switches.append(switch_id)
		)
		timeline.set_physics_process(false)
		player.set_physics_process(false)
		timeline.reset_timeline(3.0, &"delay_3s")
		_expect(timeline.get_selected_past_delay_seconds() == 3.0, "Timeline exposes the default selected delay")
		_expect(timeline.get_selected_delay_switch_id() == &"delay_3s", "Timeline exposes the default delay station id")
		_expect(timeline.request_past_delay(1.0, &"delay_1s"), "Timeline accepts the first delay station")
		_advance_timeline(timeline, player, EchoTimelineController.PAST_PHASE_WARNING_SECONDS * 0.5)
		_expect(timeline.request_past_delay(5.0, &"delay_5s"), "Timeline accepts a newer station during phase warning")
		_expect(timeline.get_selected_past_delay_seconds() == 5.0, "Latest pending delay is immediately available to checkpoint save")
		_expect(timeline.get_selected_delay_switch_id() == &"delay_5s", "Latest pending station id is immediately available to checkpoint save")
		_advance_timeline(timeline, player, EchoTimelineController.PAST_PHASE_WARNING_SECONDS * 0.5)
		_expect(observed_delays.back() == 5.0, "Latest delay applies at the original phase deadline")
		_expect(observed_switches.back() == &"delay_5s", "Latest station id applies at the original phase deadline")
	fixture.queue_free()
	await process_frame


# 验证延迟台切换可见状态后仍保留 authored 实例供再次触碰。
func _test_delay_station_reuses_authored_node() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	var delay_station := fixture.get_node("DelayPickup") as DelayPickup
	if timeline != null and player != null and delay_station != null:
		timeline.set_physics_process(false)
		player.set_physics_process(false)
		delay_station.delay_seconds = 1
		delay_station.delay_switch_id = &"fixture_delay_1s"
		timeline.reset_timeline(3.0, &"delay_3s")
		delay_station.body_entered.emit(player)
		_expect(is_instance_valid(delay_station), "Delay station remains authored after player contact")
		_expect(delay_station.is_pending(), "Touched delay station shows pending state during phase warning")
		_advance_timeline(timeline, player, EchoTimelineController.PAST_PHASE_WARNING_SECONDS)
		_expect(delay_station.is_active(), "Touched delay station becomes active when the delay applies")
		delay_station.body_exited.emit(player)
		delay_station.body_entered.emit(player)
		_expect(is_instance_valid(delay_station), "Active delay station can be touched again without being freed")
	fixture.queue_free()
	await process_frame


# Verifies a full pair of future possibilities blocks a third recording attempt.
func _test_two_future_slots_reject_a_third_recording() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var player := fixture.get_node("EchoPlayer") as EchoPlayer
	var recorder := fixture.get_node("FutureRecorder") as FutureRecorder
	if timeline != null and player != null and recorder != null:
		var slot_counts: Array[int] = []
		var rejection_events: Array[bool] = []
		timeline.future_slots_changed.connect(func(used_slots: int, _max_slots: int) -> void: slot_counts.append(used_slots))
		timeline.future_recording_rejected.connect(func() -> void: rejection_events.append(true))
		player.global_position = Vector2.ZERO
		player.velocity = Vector2.ZERO
		recorder.global_position = Vector2.ZERO
		await physics_frame
		await physics_frame
		timeline.set_physics_process(false)
		player.set_physics_process(false)
		_advance_timeline(timeline, player, EchoTimelineController.FUTURE_MAXIMUM_SECONDS)
		_expect(not timeline.is_future_recording(), "Future recording auto-commits at its five-second maximum")
		recorder.body_exited.emit(player)
		recorder.body_entered.emit(player)
		_expect(timeline.is_future_recording(), "Recorder can begin a second recording after recall and exit")
		_advance_timeline(timeline, player, 1.1)
		_expect(timeline.commit_future_recording(), "Second recording commits after its minimum duration")
		_expect(slot_counts.has(2), "Second recording reserves the second future slot")
		recorder.body_exited.emit(player)
		recorder.body_entered.emit(player)
		_expect(not timeline.is_future_recording(), "Two future possibilities reject a third recording")
		_expect(not rejection_events.is_empty(), "Rejected third recording emits its public feedback signal")
		_expect(recorder.call("get_state_name") == &"no_slot", "Rejected third recording shows the NO_SLOT state")
	fixture.queue_free()
	await process_frame


# Verifies the four authored present, past, and future contact outcomes.
func _test_temporal_collision_matrix() -> void:
	var past_catch_fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(past_catch_fixture)
	await physics_frame
	var catch_timeline := past_catch_fixture.get_node("EchoTimelineController") as EchoTimelineController
	var catch_player := past_catch_fixture.get_node("EchoPlayer") as EchoPlayer
	if catch_timeline != null and catch_player != null:
		catch_timeline.set_physics_process(false)
		var catches: Array[bool] = []
		catch_player.set_physics_process(false)
		catch_player.global_position = Vector2.ZERO
		catch_timeline.past_echo.caught_player.connect(func() -> void: catches.append(true))
		var catch_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		catch_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
		catch_timeline.past_echo.play_at(catch_track, 0.0)
		await physics_frame
		await physics_frame
		_expect(not catches.is_empty(), "PastEcho catches the current player")
	past_catch_fixture.queue_free()
	await process_frame

	var past_future_fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(past_future_fixture)
	await physics_frame
	var past_future_timeline := past_future_fixture.get_node("EchoTimelineController") as EchoTimelineController
	var past_future_player := past_future_fixture.get_node("EchoPlayer") as EchoPlayer
	if past_future_timeline != null and past_future_player != null:
		past_future_timeline.set_physics_process(false)
		past_future_player.set_physics_process(false)
		past_future_player.global_position = Vector2(500.0, 0.0)
		await physics_frame
		var future_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		future_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
		future_track.append(TEMPORAL_FRAME_SCRIPT.new(10.0, Vector2.ZERO))
		past_future_timeline.future_echo_a.start_playback(future_track, 10.0, EchoTimelineController.TEMPORAL_PHASE_SECONDS)
		var past_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		past_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
		past_future_timeline.past_echo.play_at(past_track, 0.0)
		past_future_timeline.past_echo.area_entered.emit(past_future_timeline.future_echo_a)
		_expect(not past_future_timeline.future_echo_a.is_available(), "New FutureEcho ignores PastEcho during separation phase")
		past_future_timeline.future_echo_a.advance(EchoTimelineController.TEMPORAL_PHASE_SECONDS + 0.01)
		past_future_timeline.past_echo.area_entered.emit(past_future_timeline.future_echo_a)
		_expect(past_future_timeline.future_echo_a.is_available(), "PastEcho dissipates a future possibility")
	past_future_fixture.queue_free()
	await process_frame

	var player_future_fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(player_future_fixture)
	await physics_frame
	var player_future_timeline := player_future_fixture.get_node("EchoTimelineController") as EchoTimelineController
	var player_future_player := player_future_fixture.get_node("EchoPlayer") as EchoPlayer
	if player_future_timeline != null and player_future_player != null:
		player_future_timeline.set_physics_process(false)
		player_future_player.set_physics_process(false)
		player_future_player.global_position = Vector2.ZERO
		var future_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		future_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
		future_track.append(TEMPORAL_FRAME_SCRIPT.new(10.0, Vector2.ZERO))
		player_future_timeline.future_echo_a.start_playback(future_track, 10.0, 0.0)
		await physics_frame
		await physics_frame
		_expect(player_future_timeline.future_echo_a.is_available(), "Current player dissipates a future possibility")
	player_future_fixture.queue_free()
	await process_frame

	var futures_fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(futures_fixture)
	await physics_frame
	var futures_timeline := futures_fixture.get_node("EchoTimelineController") as EchoTimelineController
	var futures_player := futures_fixture.get_node("EchoPlayer") as EchoPlayer
	if futures_timeline != null and futures_player != null:
		futures_timeline.set_physics_process(false)
		futures_player.set_physics_process(false)
		futures_player.global_position = Vector2(500.0, 0.0)
		await physics_frame
		var shared_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		shared_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
		shared_track.append(TEMPORAL_FRAME_SCRIPT.new(10.0, Vector2.ZERO))
		futures_timeline.future_echo_a.start_playback(shared_track, 10.0, 0.0)
		futures_timeline.future_echo_b.start_playback(shared_track, 10.0, 0.0)
		await physics_frame
		await physics_frame
		_expect(not futures_timeline.future_echo_a.is_available(), "First future possibility ignores another future possibility")
		_expect(not futures_timeline.future_echo_b.is_available(), "Second future possibility ignores another future possibility")
	futures_fixture.queue_free()
	await process_frame


# Verifies a clean reset discards active recording and every transient temporal body.
func _test_timeline_reset_clears_transient_time_state() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	var recorder := fixture.get_node("FutureRecorder") as FutureRecorder
	if timeline != null and recorder != null:
		var slot_counts: Array[int] = []
		timeline.future_slots_changed.connect(func(used_slots: int, _max_slots: int) -> void: slot_counts.append(used_slots))
		_expect(timeline.start_future_recording(recorder), "Timeline accepts a recording before an explicit reset")
		timeline.reset_timeline()
		_expect(not timeline.is_future_recording(), "Timeline reset clears an in-progress recording")
		_expect(timeline.future_echo_a.is_available() and timeline.future_echo_b.is_available(), "Timeline reset clears both future echo slots")
		_expect(not timeline.past_echo.visible, "Timeline reset removes the past echo from the world")
		_expect(not slot_counts.is_empty() and slot_counts.back() == 0, "Timeline reset publishes zero occupied future slots")
	fixture.queue_free()
	await process_frame


# 为移动状态测试添加真实 World 碰撞，不引入关卡场景依赖。
func _add_static_collision(parent: Node, position: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision_shape.shape = rectangle
	body.add_child(collision_shape)
	parent.add_child(body)


# Records one failed assertion without preventing later focused checks.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# Sends a physical key through the same viewport input route used at runtime.
func _send_key_event(physical_keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	root.push_input(event, true)


# 以固定小步推进时间线，并同步追加与运行时顺序一致的玩家样本。
func _advance_timeline(timeline: EchoTimelineController, player: EchoPlayer, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var delta := minf(remaining, 0.1)
		timeline._physics_process(delta)
		timeline.record_player_frame(player.build_temporal_frame(timeline.get_timeline_seconds()))
		remaining -= delta


# Prints a stable summary and returns a nonzero process result on failure.
func _finish() -> void:
	if _failures.is_empty():
		print("Echo Chase tests passed")
		quit(0)
		return
	for failure in _failures:
		push_error("TEST FAILED: %s" % failure)
	quit(1)
