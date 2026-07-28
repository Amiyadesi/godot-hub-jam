class_name PastEcho
extends Area2D
## Permanent delayed body that plays player history and catches the current player.

signal caught_player

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: CanvasItem = %Visual

var _active := false
var _phase_shifting := false


# Wires only the authored player and future-contact detection areas.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	reset_echo()


# Positions the past body at an available historical time or removes it before history exists.
func play_at(track: TemporalTrack, playback_time: float) -> void:
	if _phase_shifting:
		_set_active(false)
		return
	var frame: TemporalFrame = track.sample_at(playback_time)
	if frame == null:
		_set_active(false)
		return
	global_position = frame.position
	_set_active(true)


# Disables world influence during the visible delay-change warning.
func begin_phase_shift() -> void:
	_phase_shifting = true
	_set_active(false)


# Restores normal historical replay after phase warning completes.
func end_phase_shift() -> void:
	_phase_shifting = false


# Clears visibility, collision, and warning state for a clean timeline reset.
func reset_echo() -> void:
	_phase_shifting = false
	_active = false
	visible = false
	collision_shape.set_deferred("disabled", true)


# Enables or disables this area's gameplay presence without changing its saved path.
func _set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	visible = value
	collision_shape.set_deferred("disabled", not value)


# Catches only an unphased current player.
func _on_body_entered(body: Node2D) -> void:
	var echo_player := body as EchoPlayer
	if not _active or echo_player == null or echo_player.is_temporally_phased():
		return
	echo_player.receive_past_catch()
	caught_player.emit()


# Dissipates a future possibility when the permanent past crosses it.
func _on_area_entered(area: Area2D) -> void:
	var future_echo := area as FutureEcho
	if not _active or future_echo == null:
		return
	future_echo.dissipate()
