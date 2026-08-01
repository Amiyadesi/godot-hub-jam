class_name EchoPlayer
extends CharacterBody2D
## 当前体：负责平台移动、八方向冲刺和时间轨迹采样。

signal dash_started(direction: Vector2)
signal jump_started
signal recalled
signal caught
signal failure_requested(animation_name: StringName)

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	WALL_SLIDE,
	DASH_AIM,
	DASH,
	DISABLED,
}

@export_group("Run")
@export var run_speed := 144.0
@export var run_acceleration := 2304.0

@export_group("Jump")
@export var jump_speed := 320.0
@export_range(0.0, 1.0, 0.05) var jump_release_multiplier := 0.65
@export var coyote_seconds := 0.15
@export var jump_buffer_seconds := 0.15

@export_group("Fall")
@export var gravity := 1200.0

@export_group("Wall Slide")
@export var wall_slide_speed := 48.0
@export var wall_coyote_seconds := 0.12
@export var wall_jump_speed_x := 176.0
@export var wall_push_seconds := 0.10

@export_group("Dash Aim")
@export var dash_aim_seconds := 0.04

@export_group("Dash")
@export var dash_speed := 336.0
@export var dash_seconds := 0.10
@export_range(0.0, 1.0, 0.05) var dash_jump_momentum := 0.65
@export var dash_speed_cap_multiplier := 1.6

@export_group("Recovery")
@export var dash_input_recovery_seconds := 0.06

@onready var visual: AnimatedSprite2D = %Visual
@onready var temporal_outline: AnimatedSprite2D = %TemporalOutline
@onready var recording_outline: AnimatedSprite2D = %RecordingOutline
@onready var recording_animation_player: AnimationPlayer = %RecordingAnimationPlayer
@onready var hurtbox: Area2D = %Hurtbox
@onready var dash_vfx: EchoDashVfx = %DashVfx
@onready var dash_audio: AudioStreamPlayer2D = $DashAudio
@onready var land_audio: AudioStreamPlayer2D = $LandAudio
@onready var wall_head_ray: RayCast2D = $RayCast2D
@onready var wall_foot_ray: RayCast2D = $RayCast2D2

var facing := 1.0
var _state := State.IDLE
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
var _wall_jump_locked := false
var _wall_jump_lock_normal := Vector2.ZERO
var _temporal_phase_remaining := 0.0
var _dash_requested := false
var _jump_requested := false
var _recall_requested := false
var _was_on_floor := false


# 初始化 authored 角色节点，并向全局时间线注册当前玩家。
func _ready() -> void:
	EchoTimeline.register_player(self)
	_change_state(State.IDLE)
	visual.play(&"idle")
	temporal_outline.play(&"idle")
	recording_outline.play(&"idle")
	recording_animation_player.play(&"inactive")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	_was_on_floor = is_on_floor()


# 场景卸载时注销当前玩家，避免全局时间线保留失效引用。
func _exit_tree() -> void:
	EchoTimeline.unregister_player(self)


# 更新移动，并在位移结算后记录一帧权威路径。
func _physics_process(delta: float) -> void:
	if _state == State.DISABLED:
		return
	_update_temporal_phase(delta)
	_collect_jump_input()
	_update_floor_memory(delta)
	_update_wall_memory(delta)
	if _can_start_dash():
		_start_dash()
	match _state:
		State.DASH_AIM, State.DASH:
			_update_dash(delta)
		_:
			_update_standard_movement(delta)
	_update_animation()
	_update_landing_audio()
	EchoTimeline.record_player_frame(build_temporal_frame(EchoTimeline.get_timeline_seconds()))
	if _recall_requested or Input.is_action_just_pressed("echo_recall"):
		_recall_requested = false
		EchoTimeline.commit_future_recording()


# 锁存冲刺、跳跃与回传输入，避免 authored 输入事件在下个物理帧前丢失。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"echo_dash"):
		_dash_requested = true
	if event.is_action_pressed(&"echo_jump"):
		_jump_requested = true
	if event.is_action_pressed(&"echo_recall"):
		_recall_requested = true


# 从玩家当前可观察状态构造可回放快照。
func build_temporal_frame(time_seconds: float) -> TemporalFrame:
	var flags: int = TemporalFrame.Flag.NONE
	if _state in [State.DASH_AIM, State.DASH]:
		flags |= TemporalFrame.Flag.DASH
	if _state == State.JUMP:
		flags |= TemporalFrame.Flag.JUMP
	return TemporalFrame.new(time_seconds, global_position, velocity, facing, _get_animation_name(), flags)


# 返回当前公开移动状态，供调试和关卡测试读取。
func get_current_state() -> State:
	return _state


# 捕获录制起点的当前体运动状态，不包含之后的输入请求。
func capture_temporal_anchor(time_seconds: float) -> Dictionary:
	return {
		"frame": build_temporal_frame(time_seconds),
		"state": _state,
		"dash_available": _dash_available,
		"dash_aim_remaining": _dash_aim_remaining,
		"dash_remaining": _dash_remaining,
		"dash_recovery_remaining": _dash_recovery_remaining,
		"dash_direction": _dash_direction,
		"dash_started_on_floor": _dash_started_on_floor,
		"jump_buffer_remaining": _jump_buffer_remaining,
		"coyote_remaining": _coyote_remaining,
		"wall_coyote_remaining": _wall_coyote_remaining,
		"wall_push_remaining": _wall_push_remaining,
		"wall_normal": _wall_normal,
		"wall_jump_locked": _wall_jump_locked,
		"wall_jump_lock_normal": _wall_jump_lock_normal,
		"was_on_floor": _was_on_floor,
	}


# 将玩家恢复到录制锚点，并在分离阶段提供接触免疫。
func apply_temporal_recall(anchor: Dictionary, phase_seconds: float) -> void:
	var frame := anchor["frame"] as TemporalFrame
	global_position = frame.position
	velocity = frame.velocity
	facing = frame.facing
	_dash_available = bool(anchor["dash_available"])
	_dash_aim_remaining = float(anchor["dash_aim_remaining"])
	_dash_remaining = float(anchor["dash_remaining"])
	_dash_recovery_remaining = float(anchor["dash_recovery_remaining"])
	_dash_direction = anchor["dash_direction"] as Vector2
	_dash_started_on_floor = bool(anchor["dash_started_on_floor"])
	_jump_buffer_remaining = float(anchor["jump_buffer_remaining"])
	_coyote_remaining = float(anchor["coyote_remaining"])
	_wall_coyote_remaining = float(anchor["wall_coyote_remaining"])
	_wall_push_remaining = float(anchor["wall_push_remaining"])
	_wall_normal = anchor["wall_normal"] as Vector2
	_wall_jump_locked = bool(anchor.get("wall_jump_locked", false))
	_wall_jump_lock_normal = anchor.get("wall_jump_lock_normal", Vector2.ZERO) as Vector2
	_was_on_floor = bool(anchor["was_on_floor"])
	_dash_requested = false
	_jump_requested = false
	_recall_requested = false
	_temporal_phase_remaining = phase_seconds
	_change_state(anchor["state"] as State)
	_update_animation()
	recalled.emit()


# 判断过去体和未来体是否应忽略当前玩家接触。
func is_temporally_phased() -> bool:
	return _temporal_phase_remaining > 0.0


# 切换未来录像期间的 authored 金色角色轮廓，并按需保留循环进度。
func set_recording_feedback(value: bool, low_flash_mode: bool, preserve_progress := false) -> void:
	temporal_outline.visible = not value
	recording_outline.visible = value
	var progress_ratio := 0.0
	if preserve_progress and recording_animation_player.current_animation_length > 0.0:
		progress_ratio = recording_animation_player.current_animation_position / recording_animation_player.current_animation_length
	recording_animation_player.play(
		&"recording_reduced" if value and low_flash_mode
		else &"recording" if value
		else &"inactive"
	)
	if preserve_progress:
		recording_animation_player.seek(progress_ratio * recording_animation_player.current_animation_length, true)


# 返回金色录像轮廓是否可见，供场景验证使用。
func is_recording_outline_visible() -> bool:
	return recording_outline.visible


# 过去体抓到玩家后停止输入。
func receive_past_catch() -> void:
	if _state == State.DISABLED:
		return
	prepare_for_reset(&"hit")
	caught.emit()
	failure_requested.emit(&"hit")


# 冻结当前体并播放 authored 失败动画，等待场景控制器复位。
func prepare_for_reset(animation_name: StringName) -> void:
	_change_state(State.DISABLED)
	velocity = Vector2.ZERO
	dash_vfx.reset_vfx()
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
	_wall_jump_locked = false
	_wall_jump_lock_normal = Vector2.ZERO
	_temporal_phase_remaining = 0.0
	_jump_requested = false
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
	dash_vfx.reset_vfx()
	_change_state(State.IDLE)


# 捕获跳跃输入；按住下时直接穿过单向平台。
func _collect_jump_input() -> void:
	if _jump_requested or Input.is_action_just_pressed("echo_jump"):
		_jump_requested = false
		if Input.is_action_pressed("echo_move_down") and is_on_floor():
			global_position.y += 1.0
			velocity.y = maxf(velocity.y, 1.0)
			_jump_buffer_remaining = 0.0
			_coyote_remaining = 0.0
			return
		_jump_buffer_remaining = jump_buffer_seconds
	if Input.is_action_just_released("echo_jump") and velocity.y < 0.0:
		velocity.y *= jump_release_multiplier


# 维护地面土狼时间和地空共用的一次冲刺次数。
func _update_floor_memory(delta: float) -> void:
	if is_on_floor():
		_coyote_remaining = coyote_seconds
		_dash_available = true
		_wall_jump_locked = false
		_wall_jump_lock_normal = Vector2.ZERO
	else:
		_coyote_remaining = maxf(_coyote_remaining - delta, 0.0)


# 短暂记住墙面法线，让延迟墙跳仍可用。
func _update_wall_memory(delta: float) -> void:
	if is_on_wall_only():
		var current_wall_normal := get_wall_normal()
		if not _wall_rays_detect_wall(current_wall_normal):
			_wall_coyote_remaining = 0.0
			_wall_normal = current_wall_normal
			return
		if _wall_jump_locked and _wall_jump_lock_normal.dot(current_wall_normal) < -0.8:
			_wall_jump_locked = false
			_wall_jump_lock_normal = Vector2.ZERO
		if _wall_jump_locked:
			_wall_coyote_remaining = 0.0
		else:
			_wall_coyote_remaining = wall_coyote_seconds
		_wall_normal = current_wall_normal
	else:
		_wall_coyote_remaining = maxf(_wall_coyote_remaining - delta, 0.0)
		_wall_push_remaining = maxf(_wall_push_remaining - delta, 0.0)


# 只有共享冲刺次数可用时才开始八方向冲刺。
func _can_start_dash() -> bool:
	var requested := _dash_requested or Input.is_action_just_pressed("echo_dash")
	_dash_requested = false
	return requested and _dash_available


# 在定速冲刺移动前进入短暂调向窗口。
func _start_dash() -> void:
	_dash_available = false
	_dash_started_on_floor = is_on_floor()
	_dash_direction = _read_dash_direction()
	_dash_aim_remaining = dash_aim_seconds
	_dash_remaining = 0.0
	_dash_recovery_remaining = 0.0
	velocity = Vector2.ZERO
	if dash_aim_seconds > 0.0:
		_change_state(State.DASH_AIM)
	else:
		_dash_remaining = dash_seconds
		_change_state(State.DASH)
	dash_started.emit(_dash_direction)
	dash_vfx.begin(visual, _dash_direction)
	dash_audio.play()


# 依次处理调向、冲刺移动和输入恢复时序。
func _update_dash(delta: float) -> void:
	match _state:
		State.DASH_AIM:
			var aim_input := _read_move_input()
			if not aim_input.is_zero_approx():
				_dash_direction = _snap_to_eight(aim_input)
				dash_vfx.set_direction(_dash_direction)
			_dash_aim_remaining = maxf(_dash_aim_remaining - delta, 0.0)
			velocity = Vector2.ZERO
			move_and_slide()
			if is_zero_approx(_dash_aim_remaining):
				_dash_remaining = dash_seconds
				_change_state(State.DASH)
		State.DASH:
			if _jump_buffer_remaining > 0.0 and _dash_started_on_floor and _dash_direction.y >= 0.0:
				_perform_dash_jump()
				return
			velocity = _dash_direction * dash_speed
			_dash_remaining = maxf(_dash_remaining - delta, 0.0)
			move_and_slide()
			dash_vfx.update_dash(visual, delta, _dash_direction)
			if is_zero_approx(_dash_remaining):
				dash_vfx.finish(global_position, _dash_direction)
				_dash_recovery_remaining = dash_input_recovery_seconds
				_resolve_standard_state()


# 处理重力、跳跃缓冲、墙面移动和普通加速。
func _update_standard_movement(delta: float) -> void:
	_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)
	var started_jump := false
	if _jump_buffer_remaining > 0.0:
		if _wall_coyote_remaining > 0.0 and not is_on_floor() and not _wall_jump_locked:
			_perform_wall_jump()
			started_jump = true
		elif _coyote_remaining > 0.0:
			_perform_standard_jump()
			started_jump = true
	var dash_recovering := _dash_recovery_remaining > 0.0
	if dash_recovering and not started_jump:
		# 冲刺后短暂沿整条速度向量减速，保证八方向位移一致。
		_dash_recovery_remaining = maxf(_dash_recovery_remaining - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, run_acceleration * delta)
		move_and_slide()
		_resolve_standard_state()
		return
	velocity.y += gravity * delta
	if is_on_wall_only() and velocity.y > 0.0 and _wall_rays_detect_wall(get_wall_normal()):
		velocity.y = minf(velocity.y, wall_slide_speed)
	_apply_horizontal_motion(delta)
	move_and_slide()
	_resolve_standard_state()


# 根据水平输入加速，并保留冲刺恢复期的统一减速在上层处理。
func _apply_horizontal_motion(delta: float) -> void:
	var input_x := _read_move_input().x
	if not is_zero_approx(input_x):
		facing = signf(input_x)
	var target_speed := input_x * run_speed
	if _wall_push_remaining > 0.0:
		target_speed = _wall_normal.x * wall_jump_speed_x
	velocity.x = move_toward(velocity.x, target_speed, run_acceleration * delta)


# 执行普通土狼时间跳跃。
func _perform_standard_jump() -> void:
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	velocity.y = -jump_speed
	_change_state(State.JUMP)
	jump_started.emit()


# 沿已记录墙面法线的反方向执行墙跳。
func _perform_wall_jump() -> void:
	_jump_buffer_remaining = 0.0
	_wall_coyote_remaining = 0.0
	_wall_push_remaining = wall_push_seconds
	_wall_jump_locked = true
	_wall_jump_lock_normal = _wall_normal
	velocity.x = _wall_normal.x * wall_jump_speed_x
	velocity.y = -jump_speed
	facing = signf(_wall_normal.x)
	_change_state(State.JUMP)
	jump_started.emit()


# Require both authored wall probes to see the same wall before allowing wall movement.
func _wall_rays_detect_wall(wall_normal: Vector2) -> bool:
	if is_zero_approx(wall_normal.x):
		return false
	var ray_direction := -signf(wall_normal.x)
	wall_head_ray.target_position.x = absf(wall_head_ray.target_position.x) * ray_direction
	wall_foot_ray.target_position.x = absf(wall_foot_ray.target_position.x) * ray_direction
	wall_head_ray.force_raycast_update()
	wall_foot_ray.force_raycast_update()
	return wall_head_ray.is_colliding() and wall_foot_ray.is_colliding()


# 将符合条件的地面冲刺转成继承动量的跳跃。
func _perform_dash_jump() -> void:
	_jump_buffer_remaining = 0.0
	_dash_aim_remaining = 0.0
	_dash_remaining = 0.0
	_dash_recovery_remaining = dash_input_recovery_seconds
	dash_vfx.finish(global_position, _dash_direction)
	var speed_cap := run_speed * dash_speed_cap_multiplier
	velocity.x = clampf(_dash_direction.x * dash_speed * dash_jump_momentum, -speed_cap, speed_cap)
	velocity.y = -jump_speed
	_change_state(State.JUMP)
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


# authored Trap Area 接触玩家 Hurtbox 时请求统一失败流程。
func _on_hurtbox_area_entered(_area: Area2D) -> void:
	_request_trap_failure()


# TileSet Trap physics body 接触玩家 Hurtbox 时复用同一失败流程。
func _on_hurtbox_body_entered(_body: Node2D) -> void:
	_request_trap_failure()


# 陷阱只提出失败请求，checkpoint 控制器负责冻结与复位顺序。
func _request_trap_failure() -> void:
	if _state == State.DISABLED:
		return
	failure_requested.emit(&"death")


# 根据真实碰撞和速度收敛普通移动状态。
func _resolve_standard_state() -> void:
	if is_on_floor():
		_change_state(State.RUN if absf(velocity.x) > 1.0 else State.IDLE)
	elif is_on_wall_only() and velocity.y > 0.0 and _wall_rays_detect_wall(get_wall_normal()):
		_change_state(State.WALL_SLIDE)
	elif velocity.y < 0.0:
		_change_state(State.JUMP)
	else:
		_change_state(State.FALL)


# 只记录状态变化，状态进入动作保留在对应玩法函数内。
func _change_state(next_state: State) -> void:
	if _state == next_state:
		return
	_state = next_state


# 生成供路径回放和后续美术接线使用的动画名。
func _get_animation_name() -> StringName:
	match _state:
		State.RUN:
			return &"run"
		State.JUMP:
			return &"jump"
		State.FALL:
			return &"fall"
		State.WALL_SLIDE:
			return &"wallslide"
		State.DASH_AIM, State.DASH:
			return &"dash"
		State.DISABLED:
			return visual.animation
		_:
			return &"idle"
