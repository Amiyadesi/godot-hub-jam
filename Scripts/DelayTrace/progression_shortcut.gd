class_name ProgressionShortcut
extends StaticBody2D
## BranchProgressionDevice 激活后消失的 authored 回 Hub 捷径障碍。

@export var required_device_id: StringName

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: Node2D = %Visual
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var scatter_particles: GPUParticles2D = %ScatterParticles
@onready var condense_particles: GPUParticles2D = %CondenseParticles
@onready var release_particles: GPUParticles2D = %ReleaseParticles

var _open := false
var _release_tween: Tween


# 从槽位恢复状态，并监听唯一绑定的支路装置。
func _ready() -> void:
	if required_device_id.is_empty():
		push_error("ProgressionShortcut requires a non-empty required_device_id")
		return
	if LevelModule.instance == null:
		push_error("ProgressionShortcut requires LevelModule")
		return
	LevelModule.instance.progression_device_activated.connect(_on_progression_device_activated)
	_set_open(LevelModule.instance.is_progression_device_active(String(required_device_id)), false)


# 返回捷径是否已清空。
func is_open() -> bool:
	return _open


# 只响应绑定装置，不接收其他支路的激活。
func _on_progression_device_activated(device_id: String) -> void:
	if device_id == String(required_device_id):
		_set_open(true, true)


# 同步碰撞与 authored 淡出表现。
func _set_open(value: bool, play_feedback: bool) -> void:
	if _open == value and animation_player.current_animation != "":
		return
	_open = value
	collision_shape.set_deferred("disabled", value)
	_update_particles(value, play_feedback)
	animation_player.play(&"open" if value else &"closed")
	if value and not play_feedback:
		animation_player.seek(animation_player.current_animation_length, true)


# Converts the closed field into a brief inward pull, then an outward release.
func _update_particles(value: bool, play_feedback: bool) -> void:
	if _release_tween != null and _release_tween.is_valid():
		_release_tween.kill()
	scatter_particles.emitting = not value
	condense_particles.emitting = false
	release_particles.emitting = false
	if not value or not play_feedback or _uses_low_flash_mode():
		return
	condense_particles.restart()
	condense_particles.emitting = true
	_release_tween = create_tween()
	_release_tween.tween_interval(0.16)
	_release_tween.tween_callback(_emit_release_particles)


# Emits the final outward burst only while the shortcut remains open.
func _emit_release_particles() -> void:
	if not _open or _uses_low_flash_mode():
		return
	release_particles.restart()
	release_particles.emitting = true


# Reads the existing accessibility setting before one-shot transition bursts.
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
