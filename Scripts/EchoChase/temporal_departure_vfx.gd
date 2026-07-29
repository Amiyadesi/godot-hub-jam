class_name TemporalDepartureVfx
extends Node2D
## 独立保存旧位置画面，主体移动或复用后仍能完整播放退场。

signal finished

const STANDARD_ANIMATION := &"depart"
const REDUCED_ANIMATION := &"depart_reduced"
const DRIFT_SPEED := 48.0

@export var temporal_color := Color.WHITE

@onready var snapshot: Sprite2D = %Snapshot
@onready var particles: GPUParticles2D = %Particles
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var departure_audio: AudioStreamPlayer2D = %DepartureAudio

var _active := false
var _drift_velocity := Vector2.ZERO


# 连接 authored 尾效节点，并保持未播放快照不可见。
func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	reset_vfx()


# 从当前动画帧复制视觉合同，不再依赖来源节点后续位置或生命周期。
func play_from_sprite(source: AnimatedSprite2D, velocity: Vector2) -> void:
	assert(source != null, "TemporalDepartureVfx requires an AnimatedSprite2D source")
	var frames := source.sprite_frames
	assert(frames != null, "TemporalDepartureVfx source requires SpriteFrames")
	var frame_texture := frames.get_frame_texture(source.animation, source.frame)
	assert(frame_texture != null, "TemporalDepartureVfx source frame requires a texture")
	global_position = source.global_position
	global_rotation = source.global_rotation
	snapshot.texture = frame_texture
	snapshot.material = source.material
	snapshot.flip_h = source.flip_h
	snapshot.flip_v = source.flip_v
	snapshot.scale = source.global_scale
	snapshot.self_modulate = Color.WHITE
	particles.modulate = temporal_color
	particles.rotation = velocity.angle() if not velocity.is_zero_approx() else 0.0
	particles.restart()
	particles.emitting = not _uses_low_flash_mode()
	_drift_velocity = velocity.normalized() * DRIFT_SPEED if not velocity.is_zero_approx() else Vector2.ZERO
	_active = true
	visible = true
	animation_player.play(REDUCED_ANIMATION if _uses_low_flash_mode() else STANDARD_ANIMATION)
	departure_audio.play()


# 时间线重置时立即清掉旧位置、粒子、声音和完成回调状态。
func reset_vfx() -> void:
	_active = false
	_drift_velocity = Vector2.ZERO
	animation_player.stop()
	particles.emitting = false
	departure_audio.stop()
	snapshot.texture = null
	visible = false


# 暴露尾效存活状态，避免把主体槽占用误当成视觉生命周期。
func is_playing() -> bool:
	return _active


# 沿来源末速度方向轻移快照，暂停时由场景树自动冻结。
func _process(delta: float) -> void:
	if _active:
		global_position += _drift_velocity * delta


# 只有完整 authored 退场动画结束后才报告视觉消散。
func _on_animation_finished(animation_name: StringName) -> void:
	if not _active or animation_name not in [STANDARD_ANIMATION, REDUCED_ANIMATION]:
		return
	_active = false
	_drift_velocity = Vector2.ZERO
	particles.emitting = false
	visible = false
	finished.emit()


# 低闪烁模式保留稳定淡出，禁用密集裂解粒子。
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
