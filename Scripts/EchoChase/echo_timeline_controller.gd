class_name EchoTimelineController
extends Node
## Owns one live path, one past echo, and two authored future-echo slots.

signal future_slots_changed(used_slots: int, max_slots: int)
signal past_delay_changed(seconds: float)
signal player_caught
signal future_recording_started
signal future_recording_rejected

const DEFAULT_PAST_DELAY := 3.0
const DELAY_OPTIONS := [1.0, 3.0, 5.0]
const PAST_PHASE_WARNING_SECONDS := 0.6
const FUTURE_MINIMUM_SECONDS := 1.0
const FUTURE_MAXIMUM_SECONDS := 5.0
const FUTURE_SLOT_COUNT := 2
const TEMPORAL_PHASE_SECONDS := 0.35

@export var player: EchoPlayer

@onready var past_echo: PastEcho = %PastEcho
@onready var future_echo_a: FutureEcho = %FutureEchoA
@onready var future_echo_b: FutureEcho = %FutureEchoB

var _timeline_seconds := 0.0
var _past_delay_seconds := DEFAULT_PAST_DELAY
var _pending_past_delay_seconds := DEFAULT_PAST_DELAY
var _phase_warning_remaining := 0.0
var _run_track := TemporalTrack.new()
var _recording_track: TemporalTrack
var _recording_recorder: FutureRecorder
var _recording_started_at := 0.0
var _recording_start_position := Vector2.ZERO
var _future_slots_used := 0


# Validates authored links and wires the permanent temporal body contracts.
func _ready() -> void:
	assert(player != null, "EchoTimelineController requires an authored EchoPlayer reference")
	past_echo.caught_player.connect(_on_past_echo_caught_player)
	future_echo_a.slot_released.connect(_on_future_slot_released)
	future_echo_b.slot_released.connect(_on_future_slot_released)
	reset_timeline()


# Advances deterministic replay timing only while gameplay remains unpaused.
func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_timeline_seconds += delta
	_advance_past_delay_shift(delta)
	_advance_future_recording()
	past_echo.play_at(_run_track, _timeline_seconds - _past_delay_seconds)
	future_echo_a.advance(delta)
	future_echo_b.advance(delta)


# Appends one player-owned physics sample to live history and active recording.
func record_player_frame(frame: TemporalFrame) -> void:
	_run_track.append(frame)
	if _recording_track == null:
		return
	var recording_frame := frame.copy()
	recording_frame.time_seconds -= _recording_started_at
	_recording_track.append(recording_frame)


# Returns the monotonic time that authored player samples must use.
func get_timeline_seconds() -> float:
	return _timeline_seconds


# Starts one future recording and reserves a possibility slot immediately.
func start_future_recording(recorder: FutureRecorder) -> bool:
	if _recording_track != null or _future_slots_used >= FUTURE_SLOT_COUNT:
		future_recording_rejected.emit()
		return false
	_recording_track = TemporalTrack.new()
	_recording_recorder = recorder
	_recording_started_at = _timeline_seconds
	_recording_start_position = player.global_position
	var start_frame := player.build_temporal_frame(_timeline_seconds)
	start_frame.time_seconds = 0.0
	_recording_track.append(start_frame)
	_future_slots_used += 1
	recorder.recording_started()
	future_slots_changed.emit(_future_slots_used, FUTURE_SLOT_COUNT)
	future_recording_started.emit()
	return true


# Commits a valid recording, returns the player, and starts an authored future body.
func commit_future_recording() -> bool:
	if _recording_track == null:
		return false
	var duration := _timeline_seconds - _recording_started_at
	if duration < FUTURE_MINIMUM_SECONDS:
		return false
	var future_echo := _get_available_future_echo()
	if future_echo == null:
		push_error("EchoTimelineController has no authored FutureEcho available for a reserved slot")
		return false
	var finished_track := _recording_track
	var finished_recorder := _recording_recorder
	_recording_track = null
	_recording_recorder = null
	future_echo.start_playback(finished_track, minf(duration, FUTURE_MAXIMUM_SECONDS), TEMPORAL_PHASE_SECONDS)
	finished_recorder.recording_finished()
	player.apply_temporal_recall(_recording_start_position, TEMPORAL_PHASE_SECONDS)
	var recall_frame := player.build_temporal_frame(_timeline_seconds)
	recall_frame.flags |= TemporalFrame.Flag.RECALL
	record_player_frame(recall_frame)
	return true


# Starts a phased past-delay transition that cannot damage or press during warning.
func set_past_delay(seconds: float) -> void:
	if not DELAY_OPTIONS.has(seconds):
		push_error("EchoTimelineController.set_past_delay only accepts 1, 3, or 5 seconds")
		return
	if is_equal_approx(seconds, _past_delay_seconds) and is_zero_approx(_phase_warning_remaining):
		return
	_pending_past_delay_seconds = seconds
	_phase_warning_remaining = PAST_PHASE_WARNING_SECONDS
	past_echo.begin_phase_shift()


# Clears all transient timeline state without preserving a partial recording or echo.
func reset_timeline() -> void:
	_timeline_seconds = 0.0
	_past_delay_seconds = DEFAULT_PAST_DELAY
	_pending_past_delay_seconds = DEFAULT_PAST_DELAY
	_phase_warning_remaining = 0.0
	_run_track.clear()
	_recording_track = null
	_recording_recorder = null
	_future_slots_used = 0
	past_echo.reset_echo()
	future_echo_a.reset_echo()
	future_echo_b.reset_echo()
	future_slots_changed.emit(_future_slots_used, FUTURE_SLOT_COUNT)
	past_delay_changed.emit(_past_delay_seconds)


# Reports whether the player may display an active recorder state.
func is_future_recording() -> bool:
	return _recording_track != null


# Returns the active recording duration for authored recorder feedback.
func get_future_recording_seconds() -> float:
	return maxf(_timeline_seconds - _recording_started_at, 0.0) if _recording_track != null else 0.0


# Decrements the phase warning before applying the selected historical offset.
func _advance_past_delay_shift(delta: float) -> void:
	if is_zero_approx(_phase_warning_remaining):
		return
	_phase_warning_remaining = maxf(_phase_warning_remaining - delta, 0.0)
	if not is_zero_approx(_phase_warning_remaining):
		return
	_past_delay_seconds = _pending_past_delay_seconds
	past_echo.end_phase_shift()
	past_delay_changed.emit(_past_delay_seconds)


# Auto-commits a recording at the documented maximum duration.
func _advance_future_recording() -> void:
	if _recording_track == null:
		return
	if get_future_recording_seconds() >= FUTURE_MAXIMUM_SECONDS:
		commit_future_recording()


# Selects one inactive authored future body without instantiating any node.
func _get_available_future_echo() -> FutureEcho:
	if future_echo_a.is_available():
		return future_echo_a
	if future_echo_b.is_available():
		return future_echo_b
	return null


# Releases exactly one possibility slot when a future body ceases to affect gameplay.
func _on_future_slot_released(_future_echo: FutureEcho) -> void:
	_future_slots_used = maxi(_future_slots_used - 1, 0)
	future_slots_changed.emit(_future_slots_used, FUTURE_SLOT_COUNT)


# Reports a past-echo catch through the public game-over contract.
func _on_past_echo_caught_player() -> void:
	player_caught.emit()
