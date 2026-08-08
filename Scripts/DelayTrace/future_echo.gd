class_name FutureEcho
extends Area2D
## 短暂 authored 可能性实体：回放一段已提交录像。

signal slot_released(future_echo: FutureEcho)
signal dissipated(future_echo: FutureEcho)
signal active_changed(active: bool)

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: AnimatedSprite2D = %Visual
@onready var outline_visual: AnimatedSprite2D = %OutlineVisual
@onready var outer_outline_visual: AnimatedSprite2D = %OuterOutlineVisual
@onready var prediction_visual: AnimatedSprite2D = %PredictionVisual
@onready var playback_timer: ProgressBar = %PlaybackTimer
@onready var motion_trail: GPUParticles2D = %MotionTrail
@onready var pixel_burst: GPUParticles2D = %PixelBurst
@onready var vfx_animation_player: AnimationPlayer = %VfxAnimationPlayer
@onready var departure_vfx: TemporalDepartureVfx = %DepartureVfx
@onready var appear_audio: AudioStreamPlayer2D = %AppearAudio
@onready var dissipate_audio: AudioStreamPlayer2D = %DissipateAudio

var _track: TemporalTrack
var _duration := 0.0
var _playback_seconds := 0.0
var _active := false
var _phase_remaining := 0.0
var _last_velocity := Vector2.ZERO
var _dies_at_end := false


# 连接玩家接触，并让 authored 实体以未激活状态开始。
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	departure_vfx.finished.connect(_on_departure_finished)
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	reset_echo()


# 在当前固定槽中开始一次路径回放，并保留 authored 结尾类型。
func start_playback(track: TemporalTrack, duration: float, phase_seconds: float, dies_at_end := false) -> void:
	_track = track
	_duration = duration
	_playback_seconds = 0.0
	_phase_remaining = phase_seconds
	_dies_at_end = dies_at_end
	visible = true
	visual.visible = true
	outline_visual.visible = true
	outer_outline_visual.visible = true
	prediction_visual.visible = true
	collision_shape.set_deferred("disabled", false)
	_set_active(true)
	vfx_animation_player.play(&"materialize_reduced" if _uses_low_flash_mode() else &"materialize")
	appear_audio.play()
	var first_frame: TemporalFrame = _track.sample_at(0.0)
	if first_frame != null:
		global_position = first_frame.position
		_apply_frame_visual(first_frame)


# 录制锚点回退时从首帧重播现存可能性，不改变槽位占用。
func restart_playback(phase_seconds: float) -> void:
	if _track == null:
		return
	start_playback(_track, _duration, phase_seconds, _dies_at_end)


# 只推进当前 authored 路径；退场快照拥有独立视觉生命周期。
func advance(delta: float) -> void:
	if not _active:
		return
	_playback_seconds = minf(_playback_seconds + delta, _duration)
	_phase_remaining = maxf(_phase_remaining - delta, 0.0)
	var frame: TemporalFrame = _track.sample_at(_playback_seconds)
	if frame != null:
		global_position = frame.position
		_last_velocity = frame.velocity
		_apply_frame_visual(frame)
	_refresh_playback_timer()
	if _playback_seconds >= _duration or frame == null:
		if _dies_at_end:
			dissipate(_last_velocity)
		else:
			_release_slot()


# 立即停止未来体世界影响，只保留短暂视觉尾段。
func dissipate(impact_velocity := Vector2.ZERO) -> void:
	if not _active:
		return
	if not impact_velocity.is_zero_approx():
		_last_velocity = impact_velocity
	pixel_burst.restart()
	pixel_burst.emitting = not _uses_low_flash_mode()
	dissipate_audio.play()
	_release_slot()


# 判断该 authored 实体能否接收下一段录像。
func is_available() -> bool:
	return not _active


# 报告未来体是否正在正式回放，而不是只被录制流程预留。
func is_active() -> bool:
	return _active


# 返回未来体是否仍处于生成后的时间碰撞相位。
func is_temporally_phased() -> bool:
	return _phase_remaining > 0.0


# 捕获录制起点时的精确回放状态，供世界回退恢复。
func capture_playback_state() -> Dictionary:
	return {
		"active": _active,
		"track": _track,
		"duration": _duration,
		"playback_seconds": _playback_seconds,
		"phase_remaining": _phase_remaining,
		"last_velocity": _last_velocity,
		"dies_at_end": _dies_at_end,
	}


# 恢复锚点中的未来体进度，不重播出现音效或首帧动画。
func restore_playback_state(state: Dictionary) -> void:
	if not bool(state.get("active", false)):
		reset_echo()
		return
	_track = state["track"] as TemporalTrack
	_duration = float(state["duration"])
	_playback_seconds = float(state["playback_seconds"])
	_phase_remaining = float(state["phase_remaining"])
	_last_velocity = state["last_velocity"] as Vector2
	_dies_at_end = bool(state["dies_at_end"])
	visible = true
	visual.visible = true
	outline_visual.visible = true
	outer_outline_visual.visible = true
	prediction_visual.visible = true
	motion_trail.emitting = false
	pixel_burst.emitting = false
	departure_vfx.reset_vfx()
	vfx_animation_player.play(&"solid")
	collision_shape.set_deferred("disabled", false)
	_set_active(true)
	var frame: TemporalFrame = _track.sample_at(_playback_seconds)
	if frame != null:
		global_position = frame.position
		_apply_frame_visual(frame)


# 干净时间线重置时清除全部实时回放状态。
func reset_echo() -> void:
	_track = null
	_duration = 0.0
	_playback_seconds = 0.0
	_phase_remaining = 0.0
	_dies_at_end = false
	_set_active(false)
	visible = false
	visual.flip_h = false
	outline_visual.flip_h = false
	outer_outline_visual.flip_h = false
	prediction_visual.flip_h = false
	visual.play(&"idle")
	outline_visual.play(&"idle")
	outer_outline_visual.play(&"idle")
	prediction_visual.play(&"idle")
	motion_trail.emitting = false
	pixel_burst.emitting = false
	departure_vfx.reset_vfx()
	vfx_animation_player.play(&"RESET")
	collision_shape.set_deferred("disabled", true)


# 当前玩家接触非相位未来体时恢复唯一冲刺并将其消散。
func _on_body_entered(body: Node2D) -> void:
	var echo_player := body as EchoPlayer
	if not _active or echo_player == null or echo_player.is_temporally_phased() or _phase_remaining > 0.0:
		return
	echo_player.reset_dash()
	dissipate(echo_player.velocity)


# 回放录制帧携带的动画与朝向，不重新模拟输入。
func _apply_frame_visual(frame: TemporalFrame) -> void:
	if visual.animation != frame.animation_name:
		visual.play(frame.animation_name)
	if outline_visual.animation != frame.animation_name:
		outline_visual.play(frame.animation_name)
	if outer_outline_visual.animation != frame.animation_name:
		outer_outline_visual.play(frame.animation_name)
	if prediction_visual.animation != frame.animation_name:
		prediction_visual.play(frame.animation_name)
	visual.flip_h = frame.facing < 0.0
	outline_visual.flip_h = visual.flip_h
	outer_outline_visual.flip_h = visual.flip_h
	prediction_visual.flip_h = visual.flip_h
	var prediction_direction := frame.velocity.normalized() if not frame.velocity.is_zero_approx() else Vector2(frame.facing, 0.0)
	prediction_visual.position = prediction_direction * 6.0
	motion_trail.amount_ratio = 0.35 if _uses_low_flash_mode() else 1.0
	motion_trail.emitting = _active and frame.velocity.length_squared() > 36.0


# 先移除碰撞，让压力板在视觉尾帧结束前释放。
func _release_slot() -> void:
	if not _active:
		return
	motion_trail.emitting = false
	departure_vfx.play_from_sprites(visual, outline_visual, _last_velocity)
	_set_active(false)
	collision_shape.set_deferred("disabled", true)
	visual.visible = false
	outline_visual.visible = false
	outer_outline_visual.visible = false
	prediction_visual.visible = false
	slot_released.emit(self)


# 只在真实生命周期切换时同步绑定机关。
func _set_active(value: bool) -> void:
	if _active == value:
		_refresh_playback_timer()
		return
	_active = value
	_refresh_playback_timer()
	active_changed.emit(_active)


# 尾效结束只关闭空闲主体显示，不干扰已复用槽的新回放。
func _on_departure_finished() -> void:
	if not _active:
		visible = false
	dissipated.emit(self)


# 生成或主体消散动画途中切换低闪时保留当前进度。
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "show_future_timer":
		_refresh_playback_timer()
		return
	if key != "low_flash_mode":
		return
	motion_trail.amount_ratio = 0.35 if _uses_low_flash_mode() else 1.0
	if _uses_low_flash_mode():
		pixel_burst.emitting = false
	match vfx_animation_player.current_animation:
		&"materialize", &"materialize_reduced":
			_switch_vfx_animation(&"materialize_reduced" if _uses_low_flash_mode() else &"materialize")
		&"dissipate", &"dissipate_reduced":
			_switch_vfx_animation(&"dissipate_reduced" if _uses_low_flash_mode() else &"dissipate")


# 在成对 authored 动画之间保留归一化进度。
func _switch_vfx_animation(animation_name: StringName) -> void:
	var progress_ratio := 0.0
	if vfx_animation_player.current_animation_length > 0.0:
		progress_ratio = vfx_animation_player.current_animation_position / vfx_animation_player.current_animation_length
	vfx_animation_player.play(animation_name)
	vfx_animation_player.seek(progress_ratio * vfx_animation_player.current_animation_length, true)


# 同步未来体头顶的剩余回放比例，仅在辅助开关启用时显示。
func _refresh_playback_timer() -> void:
	playback_timer.visible = _active and _shows_future_timer()
	if not playback_timer.visible:
		return
	playback_timer.value = clampf(1.0 - _playback_seconds / _duration, 0.0, 1.0) if _duration > 0.0 else 0.0


# 读取未来体剩余时间辅助开关。
func _shows_future_timer() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("show_future_timer", false))
	)


# 读取低闪烁模式，缺少设置模块时使用标准特效。
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
