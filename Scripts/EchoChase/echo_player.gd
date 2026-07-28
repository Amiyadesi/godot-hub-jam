class_name EchoPlayer
extends CharacterBody2D
## Current player body: platform movement, eight-way dash, and temporal recording source.

signal dash_started(direction: Vector2)
signal jump_started
signal recalled
signal caught

const RUN_SPEED := 250.0
const RUN_ACCELERATION := 4096.0
const GRAVITY := 980.0
const JUMP_SPEED := 400.0
const COYOTE_SECONDS := 0.15
const JUMP_BUFFER_SECONDS := 0.15
const WALL_COYOTE_SECONDS := 0.12
const WALL_PUSH_SECONDS := 0.10
const WALL_JUMP_SPEED_X := 250.0
const DASH_AIM_SECONDS := 0.10
const DASH_SECONDS := 0.10
const DASH_INPUT_RECOVERY_SECONDS := 0.06
const DASH_SPEED := 600.0
const DASH_JUMP_MOMENTUM := 0.65
const DASH_JUMP_SPEED_CAP := RUN_SPEED * 1.6

@export var timeline: EchoTimelineController

var facing := 1.0
var _dash_available := true
var _dash_aim_remaining := 0.0
var _dash_remaining := 0.0
var _dash_recovery_remaining := 0.0
var _dash_direction := Vector2.RIGHT
var _dash_started_on_floor := false
var _jump_buffer_remaining := 0.0
var _coyote_remaining := 0.0
var _wall_coyote_remaining := 0.0
var _wall_push_remaining := 0.0
var _wall_normal := Vector2.ZERO
var _temporal_phase_remaining := 0.0
var _control_enabled := true
var _recall_requested := false


# Requires an authored timeline reference before this player can run.
func _ready() -> void:
	assert(timeline != null, "EchoPlayer requires an authored EchoTimelineController reference")


# Updates movement and records one authoritative path frame after movement resolves.
func _physics_process(delta: float) -> void:
	if not _control_enabled:
		return
	_update_temporal_phase(delta)
	_collect_jump_input()
	_update_floor_memory(delta)
	_update_wall_memory(delta)
	if _can_start_dash():
		_start_dash()
	if _dash_aim_remaining > 0.0 or _dash_remaining > 0.0:
		_update_dash(delta)
	else:
		_update_standard_movement(delta)
	timeline.record_player_frame(build_temporal_frame(timeline.get_timeline_seconds()))
	if _recall_requested or Input.is_action_just_pressed("echo_recall"):
		_recall_requested = false
		timeline.commit_future_recording()


# Latches a recall press so authored input events survive until the next physics step.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"echo_recall"):
		_recall_requested = true


# Creates one replayable snapshot from the player's current observable state.
func build_temporal_frame(time_seconds: float) -> TemporalFrame:
	var flags := TemporalFrame.Flag.NONE
	if _dash_aim_remaining > 0.0 or _dash_remaining > 0.0:
		flags |= TemporalFrame.Flag.DASH
	if velocity.y < 0.0:
		flags |= TemporalFrame.Flag.JUMP
	return TemporalFrame.new(time_seconds, global_position, velocity, facing, _get_animation_name(), flags)


# Returns the player to a recorder origin and grants contact immunity during separation.
func apply_temporal_recall(target_position: Vector2, phase_seconds: float) -> void:
	global_position = target_position
	velocity = Vector2.ZERO
	_temporal_phase_remaining = phase_seconds
	recalled.emit()


# Reports whether past and future contact must ignore this current player.
func is_temporally_phased() -> bool:
	return _temporal_phase_remaining > 0.0


# Stops player input after the permanent past body catches the current player.
func receive_past_catch() -> void:
	if not _control_enabled:
		return
	_control_enabled = false
	velocity = Vector2.ZERO
	caught.emit()


# Restores player control for an authored level reset.
func reset_player(reset_position: Vector2) -> void:
	global_position = reset_position
	velocity = Vector2.ZERO
	_dash_available = true
	_dash_aim_remaining = 0.0
	_dash_remaining = 0.0
	_dash_recovery_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	_wall_coyote_remaining = 0.0
	_wall_push_remaining = 0.0
	_temporal_phase_remaining = 0.0
	_control_enabled = true
	_recall_requested = false


# Captures one buffered jump press and applies variable-height release.
func _collect_jump_input() -> void:
	if Input.is_action_just_pressed("echo_jump"):
		_jump_buffer_remaining = JUMP_BUFFER_SECONDS
	if Input.is_action_just_released("echo_jump") and velocity.y < 0.0:
		velocity.y *= 0.5


# Maintains land-based coyote and one shared ground-or-air dash charge.
func _update_floor_memory(delta: float) -> void:
	if is_on_floor():
		_coyote_remaining = COYOTE_SECONDS
		_dash_available = true
	else:
		_coyote_remaining = maxf(_coyote_remaining - delta, 0.0)


# Remembers a wall normal briefly so a late jump remains readable.
func _update_wall_memory(delta: float) -> void:
	if is_on_wall_only():
		_wall_coyote_remaining = WALL_COYOTE_SECONDS
		_wall_normal = get_wall_normal()
	else:
		_wall_coyote_remaining = maxf(_wall_coyote_remaining - delta, 0.0)
		_wall_push_remaining = maxf(_wall_push_remaining - delta, 0.0)


# Starts an eight-direction dash only while the shared dash charge exists.
func _can_start_dash() -> bool:
	return Input.is_action_just_pressed("echo_dash") and _dash_available


# Enters the short aim window before the fixed-speed dash movement window.
func _start_dash() -> void:
	_dash_available = false
	_dash_started_on_floor = is_on_floor()
	_dash_direction = _read_dash_direction()
	_dash_aim_remaining = DASH_AIM_SECONDS
	_dash_remaining = 0.0
	_dash_recovery_remaining = 0.0
	velocity = Vector2.ZERO
	dash_started.emit(_dash_direction)


# Runs aim correction, dash movement, and the documented input recovery timing.
func _update_dash(delta: float) -> void:
	if _dash_aim_remaining > 0.0:
		var aim_input := _read_move_input()
		if not aim_input.is_zero_approx():
			_dash_direction = _snap_to_eight(aim_input)
		_dash_aim_remaining = maxf(_dash_aim_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		move_and_slide()
		if is_zero_approx(_dash_aim_remaining):
			_dash_remaining = DASH_SECONDS
		return
	if _jump_buffer_remaining > 0.0 and _dash_started_on_floor and _dash_direction.y >= 0.0:
		_perform_dash_jump()
		return
	velocity = _dash_direction * DASH_SPEED
	_dash_remaining = maxf(_dash_remaining - delta, 0.0)
	move_and_slide()
	if is_zero_approx(_dash_remaining):
		_dash_recovery_remaining = DASH_INPUT_RECOVERY_SECONDS


# Applies gravity, jump buffering, wall movement, and normal acceleration.
func _update_standard_movement(delta: float) -> void:
	_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)
	if _jump_buffer_remaining > 0.0:
		if _wall_coyote_remaining > 0.0 and not is_on_floor():
			_perform_wall_jump()
		elif _coyote_remaining > 0.0:
			_perform_standard_jump()
	velocity.y += GRAVITY * delta
	if is_on_wall_only() and velocity.y > 0.0:
		velocity.y = minf(velocity.y, RUN_SPEED)
	_apply_horizontal_motion(delta)
	move_and_slide()


# Accelerates horizontal input except during the brief dash recovery lockout.
func _apply_horizontal_motion(delta: float) -> void:
	if _dash_recovery_remaining > 0.0:
		_dash_recovery_remaining = maxf(_dash_recovery_remaining - delta, 0.0)
		return
	var input_x := _read_move_input().x
	if not is_zero_approx(input_x):
		facing = signf(input_x)
	var target_speed := input_x * RUN_SPEED
	if _wall_push_remaining > 0.0:
		target_speed = _wall_normal.x * WALL_JUMP_SPEED_X
	velocity.x = move_toward(velocity.x, target_speed, RUN_ACCELERATION * delta)


# Executes a normal coyote-time jump.
func _perform_standard_jump() -> void:
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	velocity.y = -JUMP_SPEED
	jump_started.emit()


# Executes a wall jump away from the remembered wall normal.
func _perform_wall_jump() -> void:
	_jump_buffer_remaining = 0.0
	_wall_coyote_remaining = 0.0
	_wall_push_remaining = WALL_PUSH_SECONDS
	velocity.x = _wall_normal.x * WALL_JUMP_SPEED_X
	velocity.y = -JUMP_SPEED
	facing = signf(_wall_normal.x)
	jump_started.emit()


# Converts a qualifying ground dash into a momentum-carrying jump.
func _perform_dash_jump() -> void:
	_jump_buffer_remaining = 0.0
	_dash_aim_remaining = 0.0
	_dash_remaining = 0.0
	_dash_recovery_remaining = DASH_INPUT_RECOVERY_SECONDS
	velocity.x = clampf(_dash_direction.x * DASH_SPEED * DASH_JUMP_MOMENTUM, -DASH_JUMP_SPEED_CAP, DASH_JUMP_SPEED_CAP)
	velocity.y = -JUMP_SPEED
	jump_started.emit()


# Reads the current four-direction keyboard vector.
func _read_move_input() -> Vector2:
	return Input.get_vector("echo_move_left", "echo_move_right", "echo_move_up", "echo_move_down")


# Selects eight readable dash directions, falling back to facing direction.
func _read_dash_direction() -> Vector2:
	var input_direction := _read_move_input()
	if input_direction.is_zero_approx():
		return Vector2(facing, 0.0)
	return _snap_to_eight(input_direction)


# Quantizes a vector to the nearest of eight dash directions.
func _snap_to_eight(direction: Vector2) -> Vector2:
	var step := PI / 4.0
	var snapped_angle := roundf(direction.angle() / step) * step
	return Vector2(cos(snapped_angle), sin(snapped_angle)).normalized()


# Advances the temporary player/future contact immunity window.
func _update_temporal_phase(delta: float) -> void:
	_temporal_phase_remaining = maxf(_temporal_phase_remaining - delta, 0.0)


# Produces a simple animation label for path playback and future art hookup.
func _get_animation_name() -> StringName:
	if _dash_aim_remaining > 0.0 or _dash_remaining > 0.0:
		return &"dash"
	if velocity.y < 0.0:
		return &"jump"
	if velocity.y > 0.0:
		return &"fall"
	if absf(velocity.x) > 1.0:
		return &"run"
	return &"idle"
