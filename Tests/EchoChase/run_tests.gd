extends SceneTree

const TEMPORAL_FRAME_SCRIPT := preload("res://Scripts/EchoChase/temporal_frame.gd")
const TEMPORAL_TRACK_SCRIPT := preload("res://Scripts/EchoChase/temporal_track.gd")
const TIMELINE_FIXTURE := preload("res://Tests/EchoChase/fixtures/echo_timeline_fixture.tscn")

var _failures: Array[String] = []


# Runs the current focused Echo Chase behavior checks in headless Godot.
func _init() -> void:
	call_deferred("_run")


# Runs synchronous path checks, then fixture checks that need physics frames.
func _run() -> void:
	_test_track_interpolates_continuous_motion()
	_test_track_keeps_recall_until_its_exact_time()
	await _test_player_moves_from_authored_input()
	await _test_past_echo_starts_out_of_the_world()
	await _test_future_echo_releases_a_pressure_plate()
	await _test_recorder_commits_a_future_echo_from_recall_input()
	await _test_delay_pickup_values_apply_after_a_phase_warning()
	await _test_two_future_slots_reject_a_third_recording()
	await _test_temporal_collision_matrix()
	await _test_timeline_reset_clears_transient_time_state()
	_finish()


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
		var original_time_scale := Engine.time_scale
		Engine.time_scale = 12.0
		for _frame in 8:
			await physics_frame
		_expect(timeline.get_future_recording_seconds() >= 1.0, "Accelerated test recording reaches the one-second minimum")
		_send_key_event(KEY_L, true)
		await physics_frame
		_send_key_event(KEY_L, false)
		Engine.time_scale = original_time_scale
		_expect(not timeline.is_future_recording(), "Recall input commits a recording after its minimum duration")
		_expect(not timeline.future_echo_a.is_available(), "Committed recording occupies an authored future echo")
		_expect(player.is_temporally_phased(), "Recall grants the current player its authored separation phase")
		_expect(slot_counts.has(1), "Starting a recording emits one used future slot")
	fixture.queue_free()
	await process_frame


# Verifies every supported past delay applies only after its non-interactive phase warning.
func _test_delay_pickup_values_apply_after_a_phase_warning() -> void:
	var fixture := TIMELINE_FIXTURE.instantiate()
	root.add_child(fixture)
	await physics_frame
	var timeline := fixture.get_node("EchoTimelineController") as EchoTimelineController
	if timeline != null:
		var observed_delays: Array[float] = []
		timeline.past_delay_changed.connect(func(seconds: float) -> void: observed_delays.append(seconds))
		var original_time_scale := Engine.time_scale
		Engine.time_scale = 12.0
		for expected_delay in [1.0, 3.0, 5.0]:
			timeline.set_past_delay(expected_delay)
			_expect(not timeline.past_echo.visible, "PastEcho phases out while changing to %ss" % expected_delay)
			for _frame in 4:
				await physics_frame
			_expect(observed_delays.back() == expected_delay, "Past delay applies %ss after its phase warning" % expected_delay)
		Engine.time_scale = original_time_scale
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
		var original_time_scale := Engine.time_scale
		Engine.time_scale = 12.0
		for _frame in 26:
			await physics_frame
		_expect(not timeline.is_future_recording(), "Future recording auto-commits at its five-second maximum")
		player.global_position = Vector2(200.0, 0.0)
		player.velocity = Vector2.ZERO
		await physics_frame
		player.global_position = Vector2.ZERO
		player.velocity = Vector2.ZERO
		await physics_frame
		await physics_frame
		_expect(timeline.is_future_recording(), "Recorder can begin a second recording after recall and exit")
		for _frame in 6:
			await physics_frame
		_send_key_event(KEY_L, true)
		await physics_frame
		_send_key_event(KEY_L, false)
		Engine.time_scale = original_time_scale
		_expect(slot_counts.has(2), "Second recording reserves the second future slot")
		_expect(not timeline.start_future_recording(recorder), "Two future possibilities reject a third recording")
		_expect(not rejection_events.is_empty(), "Rejected third recording emits its public feedback signal")
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
		past_future_timeline.future_echo_a.start_playback(future_track, 10.0, 0.0)
		var past_track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
		past_track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
		past_future_timeline.past_echo.play_at(past_track, 0.0)
		await physics_frame
		await physics_frame
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


# Prints a stable summary and returns a nonzero process result on failure.
func _finish() -> void:
	if _failures.is_empty():
		print("Echo Chase tests passed")
		quit(0)
		return
	for failure in _failures:
		push_error("TEST FAILED: %s" % failure)
	quit(1)
