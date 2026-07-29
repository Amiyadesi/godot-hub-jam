class_name FutureRecorder
extends Area2D
## 场景内 authored 触发器：玩家进入时开始一次可能性录像。

signal recording_started_here
signal recording_finished_here
signal recording_rejected_here

enum State {
	READY,
	RECORDING,
	WAITING_EXIT,
	NO_SLOT,
}

@export var timeline: EchoTimelineController

@onready var state_animation_player: AnimationPlayer = %StateAnimationPlayer

var _requires_exit_before_restart := false
var _player_inside := false
var _state := State.READY


# 要求直接绑定时间线，并连接 authored 进入触发。
func _ready() -> void:
	assert(timeline != null, "FutureRecorder requires an authored EchoTimelineController reference")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_state(State.READY)


# 控制器占用未来槽后，将记录器标记为录制中。
func recording_started() -> void:
	_requires_exit_before_restart = true
	_set_state(State.RECORDING)
	recording_started_here.emit()


# 玩家回到录制起点后，将记录器标记为未录制。
func recording_finished() -> void:
	_set_state(State.WAITING_EXIT)
	recording_finished_here.emit()


# 两个未来槽已占满时，为 authored 表现提供拒绝反馈入口。
func recording_rejected() -> void:
	_requires_exit_before_restart = true
	_set_state(State.NO_SLOT)
	recording_rejected_here.emit()


# 时间线清空录像时按玩家是否仍在台内恢复可理解状态。
func recording_cancelled() -> void:
	_requires_exit_before_restart = _player_inside
	_set_state(State.WAITING_EXIT if _player_inside else State.READY)


# 返回稳定状态名，供 authored 表现和回归测试读取。
func get_state_name() -> StringName:
	match _state:
		State.RECORDING:
			return &"recording"
		State.WAITING_EXIT:
			return &"waiting_exit"
		State.NO_SLOT:
			return &"no_slot"
		_:
			return &"ready"


# 只有绑定玩家重新进入时才开始录像。
func _on_body_entered(body: Node2D) -> void:
	if body != timeline.player:
		return
	_player_inside = true
	if _requires_exit_before_restart:
		return
	if not timeline.start_future_recording(self):
		recording_rejected()


# 回传后必须先离开区域，记录器才能再次开始。
func _on_body_exited(body: Node2D) -> void:
	if body != timeline.player:
		return
	_player_inside = false
	if timeline.is_future_recording():
		return
	_requires_exit_before_restart = false
	_set_state(State.READY)


# 只驱动 authored 状态动画，不在脚本中拼装视觉节点。
func _set_state(value: State) -> void:
	_state = value
	state_animation_player.play(get_state_name())
