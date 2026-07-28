class_name FutureEcho
extends Area2D
## Short-lived authored possibility body that replays one committed recording.

signal slot_released(future_echo: FutureEcho)
signal dissipated(future_echo: FutureEcho)

const DISSIPATION_SECONDS := 0.25

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: CanvasItem = %Visual

var _track: TemporalTrack
var _duration := 0.0
var _playback_seconds := 0.0
var _active := false
var _dissipation_remaining := 0.0
var _phase_remaining := 0.0


# Wires player contact and starts the authored body inactive.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	reset_echo()


# Starts one path replay in this existing slot.
func start_playback(track: TemporalTrack, duration: float, phase_seconds: float) -> void:
	_track = track
	_duration = duration
	_playback_seconds = 0.0
	_phase_remaining = phase_seconds
	_dissipation_remaining = 0.0
	_active = true
	visible = true
	visual.modulate.a = 1.0
	collision_shape.set_deferred("disabled", false)
	var first_frame: TemporalFrame = _track.sample_at(0.0)
	if first_frame != null:
		global_position = first_frame.position


# Advances authored path playback and its non-gameplay dissipation tail.
func advance(delta: float) -> void:
	if _active:
		_playback_seconds += delta
		_phase_remaining = maxf(_phase_remaining - delta, 0.0)
		var frame: TemporalFrame = _track.sample_at(_playback_seconds)
		if frame != null:
			global_position = frame.position
		if _playback_seconds >= _duration or frame == null:
			_release_slot()
		return
	if _dissipation_remaining <= 0.0:
		return
	_dissipation_remaining = maxf(_dissipation_remaining - delta, 0.0)
	visual.modulate.a = _dissipation_remaining / DISSIPATION_SECONDS
	if is_zero_approx(_dissipation_remaining):
		visible = false
		dissipated.emit(self)


# Stops future world influence immediately and leaves only a short visual tail.
func dissipate() -> void:
	if not _active:
		return
	_release_slot()


# Reports whether this authored body can take the next committed recording.
func is_available() -> bool:
	return not _active


# Clears all live replay state during a clean timeline reset.
func reset_echo() -> void:
	_track = null
	_duration = 0.0
	_playback_seconds = 0.0
	_phase_remaining = 0.0
	_dissipation_remaining = 0.0
	_active = false
	visible = false
	collision_shape.set_deferred("disabled", true)


# Lets the current player erase an unphased future on contact.
func _on_body_entered(body: Node2D) -> void:
	var echo_player := body as EchoPlayer
	if not _active or echo_player == null or echo_player.is_temporally_phased() or _phase_remaining > 0.0:
		return
	dissipate()


# Removes collision first so pressure plates release before the visual finishes.
func _release_slot() -> void:
	if not _active:
		return
	_active = false
	_dissipation_remaining = DISSIPATION_SECONDS
	collision_shape.set_deferred("disabled", true)
	slot_released.emit(self)
