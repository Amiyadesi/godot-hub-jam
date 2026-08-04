class_name FutureCondensationBarrier
extends StaticBody2D
## 只跟随一台 authored 记录器的三阶段金色障碍。

@export var source_recorder: FutureRecorder

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var _condensed := false
var _visual_phase := &"outline"


# 连接必填记录器，并同步它当前的真实回放状态。
func _ready() -> void:
	assert(source_recorder != null, "FutureCondensationBarrier requires source_recorder")
	var future_echo := source_recorder.get_future_echo()
	assert(future_echo != null, "FutureCondensationBarrier source_recorder requires a FutureEcho")
	future_echo.active_changed.connect(_on_future_active_changed)
	source_recorder.state_changed.connect(_on_recorder_state_changed)
	_set_visual_phase(_phase_for(future_echo), false)


# 向谜题测试和本地关卡逻辑报告当前物理状态。
func is_condensed() -> bool:
	return _condensed


# 返回玩家可读的屏障阶段：轮廓、录制中、实体回放。
func get_visual_phase() -> StringName:
	return _visual_phase


# Future 或记录器状态变化时，同帧切换屏障阶段。
func _on_future_active_changed(_active: bool) -> void:
	var future_echo := source_recorder.get_future_echo()
	_set_visual_phase(_phase_for(future_echo), true)


func _on_recorder_state_changed(_state_name: StringName) -> void:
	var future_echo := source_recorder.get_future_echo()
	_set_visual_phase(_phase_for(future_echo), true)


func _phase_for(future_echo: FutureEcho) -> StringName:
	if future_echo.is_active():
		return &"solid"
	if source_recorder.get_state_name() == &"recording":
		return &"recording"
	return &"outline"


func _set_visual_phase(value: StringName, transition: bool) -> void:
	var previous_phase := _visual_phase
	_visual_phase = value
	_condensed = value == &"solid"
	collision_shape.set_deferred("disabled", not _condensed)
	if not transition and value == &"outline":
		animation_player.play(&"outline")
		return
	match value:
		&"outline":
			animation_player.play(&"dissolve" if previous_phase == &"solid" else &"outline")
		&"recording":
			animation_player.play(&"recording")
		&"solid":
			animation_player.play(&"solidify" if previous_phase != &"solid" else &"solid")
