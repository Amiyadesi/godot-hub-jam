class_name FutureRecorder
extends Area2D
## 场景内 authored 触发器：玩家进入时开始一次可能性录像。

signal recording_started_here
signal recording_finished_here
signal recording_rejected_here
signal state_changed(state_name: StringName)

enum State {
	READY,
	RECORDING,
	OCCUPIED,
	WAITING_EXIT,
}

@onready var state_animation_player: AnimationPlayer = %StateAnimationPlayer

var _requires_exit_before_restart := false
var _player_inside := false
var _state := State.READY


# 连接 authored 触发器，并向全局时间线注册自己。
func _ready() -> void:
	var future_echo := get_future_echo()
	if future_echo == null:
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	future_echo.slot_released.connect(_on_future_slot_released)
	future_echo.tree_exited.connect(_on_future_echo_tree_exited, CONNECT_ONE_SHOT)
	EchoTimeline.register_recorder(self)
	refresh_future_state()


# 场景或 prefab 被删除时，注销全局时间线中的当前记录器。
func _exit_tree() -> void:
	EchoTimeline.unregister_recorder(self)


# 返回这台记录器独占的 authored 未来体。
func get_future_echo() -> FutureEcho:
	return get_node_or_null("FutureEcho") as FutureEcho


# 未来体被单独删除时让这台记录器退出全局注册，不留下失效槽位。
func _on_future_echo_tree_exited() -> void:
	body_entered.disconnect(_on_body_entered)
	body_exited.disconnect(_on_body_exited)
	EchoTimeline.unregister_recorder(self)


# 控制器占用未来槽后，将记录器标记为录制中。
func recording_started() -> void:
	_requires_exit_before_restart = true
	_set_state(State.RECORDING)
	recording_started_here.emit()


# 玩家回到录制起点后，记录器保持占用直到自身未来体结束。
func recording_finished() -> void:
	_set_state(State.OCCUPIED)
	recording_finished_here.emit()


# 自身被占用或其他机器正在录制时，提供明确拒绝反馈。
func recording_rejected() -> void:
	_requires_exit_before_restart = true
	_set_state(State.OCCUPIED if not get_future_echo().is_available() else State.WAITING_EXIT)
	recording_rejected_here.emit()


# 时间线清空录像时按玩家是否仍在台内恢复可理解状态。
func recording_cancelled() -> void:
	_requires_exit_before_restart = _player_inside
	_set_state(State.WAITING_EXIT if _player_inside else State.READY)


# 世界回退后按自身未来体和玩家位置恢复稳定状态。
func refresh_future_state() -> void:
	if _state == State.RECORDING:
		return
	if not get_future_echo().is_available():
		_set_state(State.OCCUPIED)
		return
	_requires_exit_before_restart = _player_inside
	_set_state(State.WAITING_EXIT if _player_inside else State.READY)


# 返回稳定状态名，供 authored 表现和回归测试读取。
func get_state_name() -> StringName:
	match _state:
		State.RECORDING:
			return &"recording"
		State.OCCUPIED:
			return &"occupied"
		State.WAITING_EXIT:
			return &"waiting_exit"
		_:
			return &"ready"


# 只有绑定玩家重新进入时才开始录像。
func _on_body_entered(body: Node2D) -> void:
	if body != EchoTimeline.player:
		return
	_player_inside = true
	if _requires_exit_before_restart:
		return
	if not EchoTimeline.start_future_recording(self):
		recording_rejected()


# 回传后必须先离开区域，记录器才能再次开始。
func _on_body_exited(body: Node2D) -> void:
	if body != EchoTimeline.player:
		return
	_player_inside = false
	_requires_exit_before_restart = false
	_set_state(State.OCCUPIED if not get_future_echo().is_available() else State.READY)


# 自身未来体释放后，只有仍站在台内时要求先离开。
func _on_future_slot_released(_future_echo: FutureEcho) -> void:
	_requires_exit_before_restart = _player_inside
	_set_state(State.WAITING_EXIT if _player_inside else State.READY)


# 只驱动 authored 状态动画，不在脚本中拼装视觉节点。
func _set_state(value: State) -> void:
	var changed := _state != value
	_state = value
	state_animation_player.play(get_state_name())
	if changed:
		state_changed.emit(get_state_name())
