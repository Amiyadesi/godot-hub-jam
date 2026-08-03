class_name FutureCondensationBarrier
extends StaticBody2D
## 只跟随一台 authored 记录器实际 Future 回放的金色障碍。

@export var source_recorder: FutureRecorder

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: Node2D = %Visual
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var _condensed := false


# 连接必填记录器，并同步它当前的真实回放状态。
func _ready() -> void:
	assert(source_recorder != null, "FutureCondensationBarrier requires source_recorder")
	var future_echo := source_recorder.get_future_echo()
	assert(future_echo != null, "FutureCondensationBarrier source_recorder requires a FutureEcho")
	future_echo.active_changed.connect(_on_future_active_changed)
	_set_condensed(future_echo.is_active())


# 向谜题测试和本地关卡逻辑报告当前物理状态。
func is_condensed() -> bool:
	return _condensed


# Future 正式开始或结束回放时，同帧切换屏障。
func _on_future_active_changed(active: bool) -> void:
	_set_condensed(active)


# 立即切换碰撞，并播放 authored 凝固或解体表现。
func _set_condensed(value: bool) -> void:
	if _condensed == value:
		return
	_condensed = value
	collision_shape.set_deferred("disabled", not value)
	visual.visible = true
	animation_player.play(&"solidify" if value else &"dissolve")
