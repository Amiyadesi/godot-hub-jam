class_name TemporalDepartureVfx
extends Node2D
## 独立保存旧位置画面，主体移动或复用后仍能完整播放退场。

signal finished

const STANDARD_ANIMATION := &"depart"
const REDUCED_ANIMATION := &"depart_reduced"
const ROOM_STANDARD_ANIMATION := &"room_depart"
const ROOM_REDUCED_ANIMATION := &"room_depart_reduced"
const DRIFT_SPEED := 48.0

@export var temporal_color := Color.WHITE

@onready var core_snapshot: Sprite2D = %CoreSnapshot
@onready var snapshot: Sprite2D = %Snapshot
@onready var room_overlay: Polygon2D = %RoomOverlay
@onready var impact_ring: Sprite2D = %ImpactRing
@onready var particles: GPUParticles2D = %Particles
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var departure_audio: AudioStreamPlayer2D = %DepartureAudio

var _active := false
var _room_mode := false
var _drift_velocity := Vector2.ZERO


# 连接 authored 尾效节点，并保持未播放快照不可见。
func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	reset_vfx()


# 从当前动画帧复制视觉合同，不再依赖来源节点后续位置或生命周期。
func play_from_sprite(source: AnimatedSprite2D, velocity: Vector2) -> void:
	play_from_sprites(source, null, velocity)


# 同时复制 Core 与 Outline，让退场仍保留完整角色轮廓和内部像素。
func play_from_sprites(core: AnimatedSprite2D, outline: AnimatedSprite2D, velocity: Vector2) -> void:
	_room_mode = false
	room_overlay.visible = false
	global_position = core.global_position
	global_rotation = core.global_rotation
	_copy_sprite_frame(core_snapshot, core)
	if outline != null:
		_copy_sprite_frame(snapshot, outline)
	else:
		_copy_sprite_frame(snapshot, core)
	impact_ring.modulate = temporal_color
	particles.modulate = temporal_color
	particles.rotation = velocity.angle() if not velocity.is_zero_approx() else 0.0
	particles.restart()
	particles.emitting = not _uses_low_flash_mode()
	_drift_velocity = velocity.normalized() * DRIFT_SPEED if not velocity.is_zero_approx() else Vector2.ZERO
	_active = true
	visible = true
	animation_player.play(REDUCED_ANIMATION if _uses_low_flash_mode() else STANDARD_ANIMATION)
	departure_audio.play()


# Plays the authored 480x270 conversion field from the PresentHub origin.
func play_room_departure() -> void:
	_room_mode = true
	_drift_velocity = Vector2.ZERO
	core_snapshot.visible = false
	snapshot.visible = false
	particles.emitting = false
	impact_ring.modulate = temporal_color
	_active = true
	visible = true
	animation_player.play(ROOM_REDUCED_ANIMATION if _uses_low_flash_mode() else ROOM_STANDARD_ANIMATION)
	departure_audio.play()


# 时间线重置时立即清掉旧位置、粒子、声音和完成回调状态。
func reset_vfx() -> void:
	_active = false
	_room_mode = false
	_drift_velocity = Vector2.ZERO
	animation_player.stop()
	particles.emitting = false
	departure_audio.stop()
	core_snapshot.texture = null
	snapshot.texture = null
	room_overlay.visible = false
	impact_ring.visible = false
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
	if not _active or animation_name not in [
		STANDARD_ANIMATION,
		REDUCED_ANIMATION,
		ROOM_STANDARD_ANIMATION,
		ROOM_REDUCED_ANIMATION,
	]:
		return
	_active = false
	_room_mode = false
	_drift_velocity = Vector2.ZERO
	particles.emitting = false
	visible = false
	finished.emit()


# 尾效播放中切换低闪时保留进度，并立即清掉高频粒子。
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key != "low_flash_mode" or not _active:
		return
	if _uses_low_flash_mode():
		particles.emitting = false
	var progress_ratio := 0.0
	if animation_player.current_animation_length > 0.0:
		progress_ratio = animation_player.current_animation_position / animation_player.current_animation_length
	var next_animation := (
		ROOM_REDUCED_ANIMATION if _room_mode and _uses_low_flash_mode()
		else ROOM_STANDARD_ANIMATION if _room_mode
		else REDUCED_ANIMATION if _uses_low_flash_mode()
		else STANDARD_ANIMATION
	)
	animation_player.play(next_animation)
	animation_player.seek(progress_ratio * animation_player.current_animation_length, true)


# 将 AnimatedSprite2D 当前帧复制到独立快照节点。
func _copy_sprite_frame(target: Sprite2D, source: AnimatedSprite2D) -> void:
	var frames := source.sprite_frames
	var frame_texture := frames.get_frame_texture(source.animation, source.frame)
	target.texture = frame_texture
	target.material = source.material
	target.flip_h = source.flip_h
	target.flip_v = source.flip_v
	target.scale = source.global_scale
	target.modulate = Color(source.self_modulate.r, source.self_modulate.g, source.self_modulate.b, 1.0)
	target.self_modulate = Color(1.0, 1.0, 1.0, source.self_modulate.a)


# 低闪烁模式保留稳定淡出，禁用密集裂解粒子。
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
