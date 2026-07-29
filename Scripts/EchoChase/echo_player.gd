class_name EchoPlayer
extends CharacterBody2D
## 当前体：负责平台移动、八方向冲刺和时间轨迹采样。

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

@onready var visual: AnimatedSprite2D = %Visual
@onready var temporal_outline: AnimatedSprite2D = %TemporalOutline
@onready var recording_outline: AnimatedSprite2D = %RecordingOutline
@onready var recording_animation_player: AnimationPlayer = %RecordingAnimationPlayer
@onready var dash_audio: AudioStreamPlayer2D = $DashAudio
@onready var land_audio: AudioStreamPlayer2D = $LandAudio

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
var _was_on_floor := false


# 玩家运行前必须绑定 authored 时间线。
func _ready() -> void:
	assert(timeline != null, "EchoPlayer requires an authored EchoTimelineController reference")
	visual.play(&"idle")
	temporal_outline.play(&"idle")
	recording_outline.play(&"idle")
	recording_animation_player.play(&"inactive")
	_was_on_floor = is_on_floor()


# 更新移动，并在位移结算后记录一帧权威路径。
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
	_update_animation()
	_update_landing_audio()
	timeline.record_player_frame(build_temporal_frame(timeline.get_timeline_seconds()))
	if _recall_requested or Input.is_action_just_pressed("echo_recall"):
		_recall_requested = false
		timeline.commit_future_recording()


# 锁存回传输入，避免 authored 输入事件在下个物理帧前丢失。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"echo_recall"):
		_recall_requested = true


# 从玩家当前可观察状态构造可回放快照。
func build_temporal_frame(time_seconds: float) -> TemporalFrame:
	var flags := TemporalFrame.Flag.NONE
	if _dash_aim_remaining > 0.0 or _dash_remaining > 0.0:
		flags |= TemporalFrame.Flag.DASH
	if velocity.y < 0.0:
		flags |= TemporalFrame.Flag.JUMP
	return TemporalFrame.new(time_seconds, global_position, velocity, facing, _get_animation_name(), flags)


# 将玩家送回记录器起点，并在分离阶段提供接触免疫。
func apply_temporal_recall(target_position: Vector2, phase_seconds: float) -> void:
	global_position = target_position
	velocity = Vector2.ZERO
	_temporal_phase_remaining = phase_seconds
	recalled.emit()


# 判断过去体和未来体是否应忽略当前玩家接触。
func is_temporally_phased() -> bool:
	return _temporal_phase_remaining > 0.0


# 切换未来录像期间的 authored 金色角色轮廓。
func set_recording_feedback(value: bool, low_flash_mode: bool) -> void:
	temporal_outline.visible = not value
	recording_outline.visible = value
	recording_animation_player.play(
		&"recording_reduced" if value and low_flash_mode
		else &"recording" if value
		else &"inactive"
	)


# 返回金色录像轮廓是否可见，供场景验证使用。
func is_recording_outline_visible() -> bool:
	return recording_outline.visible


# 过去体抓到玩家后停止输入。
func receive_past_catch() -> void:
	if not _control_enabled:
		return
	prepare_for_reset(&"hit")
	caught.emit()


# 冻结当前体并播放 authored 失败动画，等待场景控制器复位。
func prepare_for_reset(animation_name: StringName) -> void:
	_control_enabled = false
	velocity = Vector2.ZERO
	visual.play(animation_name)
	temporal_outline.play(animation_name)


# 为 authored 关卡复位恢复玩家控制。
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
	_was_on_floor = false
	visual.flip_h = false
	visual.play(&"idle")
	temporal_outline.visible = true
	temporal_outline.flip_h = false
	temporal_outline.play(&"idle")
	recording_outline.flip_h = false
	recording_outline.play(&"idle")
	recording_animation_player.play(&"inactive")


# 捕获一次跳跃缓冲并处理可变跳高。
func _collect_jump_input() -> void:
	if Input.is_action_just_pressed("echo_jump"):
		_jump_buffer_remaining = JUMP_BUFFER_SECONDS
	if Input.is_action_just_released("echo_jump") and velocity.y < 0.0:
		velocity.y *= 0.5


# 维护地面土狼时间和地空共用的一次冲刺次数。
func _update_floor_memory(delta: float) -> void:
	if is_on_floor():
		_coyote_remaining = COYOTE_SECONDS
		_dash_available = true
	else:
		_coyote_remaining = maxf(_coyote_remaining - delta, 0.0)


# 短暂记住墙面法线，让延迟墙跳仍可用。
func _update_wall_memory(delta: float) -> void:
	if is_on_wall_only():
		_wall_coyote_remaining = WALL_COYOTE_SECONDS
		_wall_normal = get_wall_normal()
	else:
		_wall_coyote_remaining = maxf(_wall_coyote_remaining - delta, 0.0)
		_wall_push_remaining = maxf(_wall_push_remaining - delta, 0.0)


# 只有共享冲刺次数可用时才开始八方向冲刺。
func _can_start_dash() -> bool:
	return Input.is_action_just_pressed("echo_dash") and _dash_available


# 在定速冲刺移动前进入短暂调向窗口。
func _start_dash() -> void:
	_dash_available = false
	_dash_started_on_floor = is_on_floor()
	_dash_direction = _read_dash_direction()
	_dash_aim_remaining = DASH_AIM_SECONDS
	_dash_remaining = 0.0
	_dash_recovery_remaining = 0.0
	velocity = Vector2.ZERO
	dash_started.emit(_dash_direction)
	dash_audio.play()


# 依次处理调向、冲刺移动和输入恢复时序。
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


# 处理重力、跳跃缓冲、墙面移动和普通加速。
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


# 除冲刺恢复锁定外，根据水平输入加速。
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


# 执行普通土狼时间跳跃。
func _perform_standard_jump() -> void:
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	velocity.y = -JUMP_SPEED
	jump_started.emit()


# 沿已记录墙面法线的反方向执行墙跳。
func _perform_wall_jump() -> void:
	_jump_buffer_remaining = 0.0
	_wall_coyote_remaining = 0.0
	_wall_push_remaining = WALL_PUSH_SECONDS
	velocity.x = _wall_normal.x * WALL_JUMP_SPEED_X
	velocity.y = -JUMP_SPEED
	facing = signf(_wall_normal.x)
	jump_started.emit()


# 将符合条件的地面冲刺转成继承动量的跳跃。
func _perform_dash_jump() -> void:
	_jump_buffer_remaining = 0.0
	_dash_aim_remaining = 0.0
	_dash_remaining = 0.0
	_dash_recovery_remaining = DASH_INPUT_RECOVERY_SECONDS
	velocity.x = clampf(_dash_direction.x * DASH_SPEED * DASH_JUMP_MOMENTUM, -DASH_JUMP_SPEED_CAP, DASH_JUMP_SPEED_CAP)
	velocity.y = -JUMP_SPEED
	jump_started.emit()


# 读取当前四方向移动向量。
func _read_move_input() -> Vector2:
	return Input.get_vector("echo_move_left", "echo_move_right", "echo_move_up", "echo_move_down")


# 选择八个清晰冲刺方向；无输入时使用朝向。
func _read_dash_direction() -> Vector2:
	var input_direction := _read_move_input()
	if input_direction.is_zero_approx():
		return Vector2(facing, 0.0)
	return _snap_to_eight(input_direction)


# 将向量量化为最近的八方向之一。
func _snap_to_eight(direction: Vector2) -> Vector2:
	var step := PI / 4.0
	var snapped_angle := roundf(direction.angle() / step) * step
	return Vector2(cos(snapped_angle), sin(snapped_angle)).normalized()


# 推进玩家与未来体的临时接触免疫窗口。
func _update_temporal_phase(delta: float) -> void:
	_temporal_phase_remaining = maxf(_temporal_phase_remaining - delta, 0.0)


# 将当前运动状态同步到 authored 角色动画和朝向。
func _update_animation() -> void:
	var animation_name := _get_animation_name()
	if visual.animation != animation_name:
		visual.play(animation_name)
	if temporal_outline.animation != animation_name:
		temporal_outline.play(animation_name)
	if recording_outline.animation != animation_name:
		recording_outline.play(animation_name)
	visual.flip_h = facing < 0.0
	temporal_outline.flip_h = visual.flip_h
	recording_outline.flip_h = visual.flip_h


# 只在从空中落到地面的边沿播放一次落地音效。
func _update_landing_audio() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		land_audio.play()
	_was_on_floor = on_floor


# 生成供路径回放和后续美术接线使用的动画名。
func _get_animation_name() -> StringName:
	if _dash_aim_remaining > 0.0 or _dash_remaining > 0.0:
		return &"dash"
	if is_on_wall_only() and velocity.y > 0.0:
		return &"wallslide"
	if velocity.y < 0.0:
		return &"jump"
	if velocity.y > 0.0:
		return &"fall"
	if absf(velocity.x) > 1.0:
		return &"run"
	return &"idle"
