class_name EchoCheckpoint
extends Area2D
## 场景内 authored 存档点：提供稳定复活坐标并请求场景控制器保存。

signal activation_requested(checkpoint: EchoCheckpoint)

@export var checkpoint_id: StringName = &"checkpoint"

@onready var respawn_point: Marker2D = %RespawnPoint
@onready var visual: Sprite2D = %Sprite2D
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var activation_audio: AudioStreamPlayer2D = %ActivationAudio

var _active := false


# 校验 authored ID，并监听玩家触碰。
func _ready() -> void:
	assert(not checkpoint_id.is_empty(), "EchoCheckpoint requires a non-empty authored checkpoint_id")
	body_entered.connect(_on_body_entered)
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	set_active(false)


# 返回供存档使用的稳定 ID。
func get_checkpoint_id() -> StringName:
	return checkpoint_id


# 返回 authored 复活标记的世界坐标。
func get_respawn_position() -> Vector2:
	return respawn_point.global_position


# 切换最新存档点表现；反馈音只在新激活时播放。
func set_active(value: bool, play_feedback := false) -> void:
	if _active == value:
		return
	_active = value
	if not value:
		animation_player.play(&"RESET")
		return
	_play_active_animation(false)
	if play_feedback:
		activation_audio.play()


# 激活期间切换低闪时只替换循环表现，不重复触发存档反馈。
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "low_flash_mode" and _active:
		_play_active_animation(true)


# 在标准与稳定循环之间保留归一化进度。
func _play_active_animation(preserve_progress: bool) -> void:
	var progress_ratio := 0.0
	if preserve_progress and animation_player.current_animation_length > 0.0:
		progress_ratio = animation_player.current_animation_position / animation_player.current_animation_length
	animation_player.play(&"active_reduced" if _uses_low_flash_mode() else &"active")
	if preserve_progress:
		animation_player.seek(progress_ratio * animation_player.current_animation_length, true)


# 读取全局低闪烁设置，缺少模块时使用正常慢脉冲。
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)


# 只有未激活的存档点会向场景控制器发送一次玩家触碰请求。
func _on_body_entered(body: Node2D) -> void:
	if _active or not body is EchoPlayer:
		return
	activation_requested.emit(self)
