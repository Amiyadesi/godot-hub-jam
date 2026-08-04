class_name ProgressionShortcut
extends StaticBody2D
## BranchProgressionDevice 激活后消失的 authored 回 Hub 捷径障碍。

@export var required_device_id: StringName

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: Node2D = %Visual
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var _open := false


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
	animation_player.play(&"open" if value else &"closed")
	if value and not play_feedback:
		animation_player.seek(animation_player.current_animation_length, true)
