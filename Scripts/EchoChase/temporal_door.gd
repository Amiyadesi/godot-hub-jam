class_name TemporalDoor
extends StaticBody2D
## 由一个或多个现存时态实体打开的简单 authored 障碍。

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: CanvasItem = %Visual

var _is_open := true


# 门进入场景时应用 authored 关闭状态。
func _ready() -> void:
	set_open(false)


# 开闭物理通路，并向关卡脚本暴露清晰状态。
func set_open(value: bool) -> void:
	if _is_open == value:
		return
	_is_open = value
	collision_shape.set_deferred("disabled", value)
	visual.modulate = Color(0.38, 0.96, 0.82, 0.32) if value else Color(0.92, 0.34, 0.32, 0.88)


# 向外部关卡逻辑报告当前障碍状态。
func is_open() -> bool:
	return _is_open
