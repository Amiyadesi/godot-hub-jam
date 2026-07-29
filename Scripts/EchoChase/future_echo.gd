class_name FutureEcho
extends Area2D
## 短暂 authored 可能性实体：回放一段已提交录像。

signal slot_released(future_echo: FutureEcho)
signal dissipated(future_echo: FutureEcho)

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: AnimatedSprite2D = %Visual
@onready var outline_visual: AnimatedSprite2D = %OutlineVisual
@onready var pixel_burst: GPUParticles2D = %PixelBurst
@onready var vfx_animation_player: AnimationPlayer = %VfxAnimationPlayer
@onready var departure_vfx: TemporalDepartureVfx = %DepartureVfx
@onready var appear_audio: AudioStreamPlayer2D = %AppearAudio

var _track: TemporalTrack
var _duration := 0.0
var _playback_seconds := 0.0
var _active := false
var _phase_remaining := 0.0
var _last_velocity := Vector2.ZERO


# 连接玩家接触，并让 authored 实体以未激活状态开始。
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	departure_vfx.finished.connect(_on_departure_finished)
	reset_echo()


# 在当前固定槽中开始一次路径回放。
func start_playback(track: TemporalTrack, duration: float, phase_seconds: float) -> void:
	_track = track
	_duration = duration
	_playback_seconds = 0.0
	_phase_remaining = phase_seconds
	_active = true
	visible = true
	visual.visible = true
	collision_shape.set_deferred("disabled", false)
	vfx_animation_player.play(&"materialize_reduced" if _uses_low_flash_mode() else &"materialize")
	appear_audio.play()
	var first_frame: TemporalFrame = _track.sample_at(0.0)
	if first_frame != null:
		global_position = first_frame.position
		_apply_frame_visual(first_frame)


# 只推进当前 authored 路径；退场快照拥有独立视觉生命周期。
func advance(delta: float) -> void:
	if not _active:
		return
	_playback_seconds += delta
	_phase_remaining = maxf(_phase_remaining - delta, 0.0)
	var frame: TemporalFrame = _track.sample_at(_playback_seconds)
	if frame != null:
		global_position = frame.position
		_last_velocity = frame.velocity
		_apply_frame_visual(frame)
	if _playback_seconds >= _duration or frame == null:
		_release_slot()


# 立即停止未来体世界影响，只保留短暂视觉尾段。
func dissipate() -> void:
	if not _active:
		return
	_release_slot()


# 判断该 authored 实体能否接收下一段录像。
func is_available() -> bool:
	return not _active


# 返回未来体是否仍处于生成后的时间碰撞相位。
func is_temporally_phased() -> bool:
	return _phase_remaining > 0.0


# 干净时间线重置时清除全部实时回放状态。
func reset_echo() -> void:
	_track = null
	_duration = 0.0
	_playback_seconds = 0.0
	_phase_remaining = 0.0
	_active = false
	visible = false
	visual.flip_h = false
	outline_visual.flip_h = false
	visual.play(&"idle")
	outline_visual.play(&"idle")
	pixel_burst.emitting = false
	departure_vfx.reset_vfx()
	vfx_animation_player.play(&"RESET")
	collision_shape.set_deferred("disabled", true)


# 当前玩家接触非相位未来体时将其消散。
func _on_body_entered(body: Node2D) -> void:
	var echo_player := body as EchoPlayer
	if not _active or echo_player == null or echo_player.is_temporally_phased() or _phase_remaining > 0.0:
		return
	dissipate()


# 回放录制帧携带的动画与朝向，不重新模拟输入。
func _apply_frame_visual(frame: TemporalFrame) -> void:
	if visual.animation != frame.animation_name:
		visual.play(frame.animation_name)
	if outline_visual.animation != frame.animation_name:
		outline_visual.play(frame.animation_name)
	visual.flip_h = frame.facing < 0.0
	outline_visual.flip_h = visual.flip_h


# 先移除碰撞，让压力板在视觉尾帧结束前释放。
func _release_slot() -> void:
	if not _active:
		return
	departure_vfx.play_from_sprite(outline_visual, _last_velocity)
	_active = false
	collision_shape.set_deferred("disabled", true)
	visual.visible = false
	outline_visual.visible = false
	slot_released.emit(self)


# 尾效结束只关闭空闲主体显示，不干扰已复用槽的新回放。
func _on_departure_finished() -> void:
	if not _active:
		visible = false
	dissipated.emit(self)


# 读取低闪烁模式，缺少设置模块时使用标准特效。
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
