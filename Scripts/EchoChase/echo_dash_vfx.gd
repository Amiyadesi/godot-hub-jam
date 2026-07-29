class_name EchoDashVfx
extends Node2D
## authored 冲刺反馈：启动爆点、短残影、方向粒子与结束收束。

const AFTERIMAGE_INTERVAL := 0.035

@onready var start_ring: Sprite2D = %StartRing
@onready var start_burst: GPUParticles2D = %StartBurst
@onready var direction_particles: GPUParticles2D = %DirectionParticles
@onready var afterimage_a: Sprite2D = %AfterimageA
@onready var afterimage_b: Sprite2D = %AfterimageB
@onready var afterimage_c: Sprite2D = %AfterimageC
@onready var end_ring: Sprite2D = %EndRing
@onready var end_burst: GPUParticles2D = %EndBurst
@onready var start_animation_player: AnimationPlayer = %StartAnimationPlayer
@onready var end_animation_player: AnimationPlayer = %EndAnimationPlayer
@onready var afterimage_animation_player: AnimationPlayer = %AfterimageAnimationPlayer

var _active := false
var _sample_elapsed := 0.0
var _suppress_particles_for_current_dash := false


# 让 authored VFX 从完全隐藏状态开始。
func _ready() -> void:
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	reset_vfx()


# 在输入响应帧播放启动爆点，并准备方向拖尾。
func begin(source: AnimatedSprite2D, direction: Vector2) -> void:
	assert(source != null, "EchoDashVfx requires an authored AnimatedSprite2D source")
	_active = true
	_sample_elapsed = AFTERIMAGE_INTERVAL
	_suppress_particles_for_current_dash = _uses_low_flash_mode()
	start_ring.position = source.global_position
	start_burst.position = source.global_position
	_set_direction(direction)
	start_burst.restart()
	start_burst.emitting = not _suppress_particles_for_current_dash
	start_animation_player.play(&"start_reduced" if _uses_low_flash_mode() else &"start")
	_sample_afterimage(source)


# 调向窗口中同步粒子方向，不重复播放启动爆点。
func set_direction(direction: Vector2) -> void:
	_set_direction(direction)


# 冲刺移动期间按固定间隔采样短残影并持续发射方向粒子。
func update_dash(source: AnimatedSprite2D, delta: float, direction: Vector2) -> void:
	if not _active:
		return
	_set_direction(direction)
	direction_particles.position = source.global_position
	if not _suppress_particles_for_current_dash and not direction_particles.emitting:
		direction_particles.restart()
		direction_particles.emitting = true
	_sample_elapsed += delta
	while _sample_elapsed >= AFTERIMAGE_INTERVAL:
		_sample_elapsed -= AFTERIMAGE_INTERVAL
		_sample_afterimage(source)


# 冲刺移动结束时停止拖尾，并在当前位置播放收束反馈。
func finish(end_position: Vector2, direction: Vector2) -> void:
	if not _active:
		return
	_active = false
	direction_particles.emitting = false
	end_ring.position = end_position
	end_burst.position = end_position
	end_burst.rotation = direction.angle()
	end_burst.restart()
	end_burst.emitting = not _suppress_particles_for_current_dash
	end_animation_player.play(&"finish_reduced" if _uses_low_flash_mode() else &"finish")
	afterimage_animation_player.play(&"fade")


# 失败、读档或时间线重置时立即清空所有冲刺尾效。
func reset_vfx() -> void:
	_active = false
	_sample_elapsed = 0.0
	_suppress_particles_for_current_dash = false
	start_burst.emitting = false
	direction_particles.emitting = false
	end_burst.emitting = false
	start_animation_player.play(&"RESET")
	end_animation_player.play(&"RESET")
	afterimage_animation_player.play(&"RESET")


# 返回冲刺尾效是否正在接收路径采样。
func is_active() -> bool:
	return _active


# 将最新玩家帧压入三个 authored 残影槽。
func _sample_afterimage(source: AnimatedSprite2D) -> void:
	_copy_afterimage(afterimage_c, afterimage_b, 0.12)
	_copy_afterimage(afterimage_b, afterimage_a, 0.22)
	_copy_source_frame(afterimage_a, source, 0.34)
	if _suppress_particles_for_current_dash:
		afterimage_c.visible = false


# 在残影槽之间复制静态帧和世界位置。
func _copy_afterimage(target: Sprite2D, source: Sprite2D, alpha: float) -> void:
	if source.texture == null:
		return
	target.texture = source.texture
	target.position = source.position
	target.scale = source.scale
	target.flip_h = source.flip_h
	target.flip_v = source.flip_v
	target.self_modulate = Color(0.68, 1.0, 1.0, alpha)
	target.visible = true


# 从玩家当前动画复制一个不影响主体的残影帧。
func _copy_source_frame(target: Sprite2D, source: AnimatedSprite2D, alpha: float) -> void:
	var frames := source.sprite_frames
	assert(frames != null, "EchoDashVfx source requires SpriteFrames")
	var frame_texture := frames.get_frame_texture(source.animation, source.frame)
	assert(frame_texture != null, "EchoDashVfx source frame requires a texture")
	target.texture = frame_texture
	target.position = source.global_position
	target.scale = source.global_scale
	target.flip_h = source.flip_h
	target.flip_v = source.flip_v
	target.self_modulate = Color(0.68, 1.0, 1.0, alpha)
	target.visible = true


# 将 authored 方向粒子朝向冲刺反方向，形成速度拖尾。
func _set_direction(direction: Vector2) -> void:
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	direction_particles.rotation = safe_direction.angle()
	start_burst.rotation = safe_direction.angle()


# 冲刺途中进入低闪会终止本次高频反馈，并保留环动画进度。
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key != "low_flash_mode":
		return
	if _uses_low_flash_mode():
		_suppress_particles_for_current_dash = true
		start_burst.emitting = false
		direction_particles.emitting = false
		end_burst.emitting = false
		afterimage_c.visible = false
	match start_animation_player.current_animation:
		&"start", &"start_reduced":
			_switch_animation_preserving_progress(
				start_animation_player,
				&"start_reduced" if _uses_low_flash_mode() else &"start"
			)
	match end_animation_player.current_animation:
		&"finish", &"finish_reduced":
			_switch_animation_preserving_progress(
				end_animation_player,
				&"finish_reduced" if _uses_low_flash_mode() else &"finish"
			)


# 在同一阶段的标准与稳定动画之间保留归一化进度。
func _switch_animation_preserving_progress(animation_player: AnimationPlayer, animation_name: StringName) -> void:
	var progress_ratio := 0.0
	if animation_player.current_animation_length > 0.0:
		progress_ratio = animation_player.current_animation_position / animation_player.current_animation_length
	animation_player.play(animation_name)
	animation_player.seek(progress_ratio * animation_player.current_animation_length, true)


# 低闪烁模式保留轮廓和残影，关闭快速粒子爆点。
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
