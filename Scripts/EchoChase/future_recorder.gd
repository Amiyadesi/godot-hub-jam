class_name FutureRecorder
extends Area2D
## 场景内 authored 触发器：玩家进入时开始一次可能性录像。

signal recording_started_here
signal recording_finished_here
signal recording_rejected_here

@export var timeline: EchoTimelineController

var _requires_exit_before_restart := false


# 要求直接绑定时间线，并连接 authored 进入触发。
func _ready() -> void:
	assert(timeline != null, "FutureRecorder requires an authored EchoTimelineController reference")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# 控制器占用未来槽后，将记录器标记为录制中。
func recording_started() -> void:
	_requires_exit_before_restart = true
	recording_started_here.emit()


# 玩家回到录制起点后，将记录器标记为未录制。
func recording_finished() -> void:
	recording_finished_here.emit()


# 两个未来槽已占满时，为 authored 表现提供拒绝反馈入口。
func recording_rejected() -> void:
	recording_rejected_here.emit()


# 只有绑定玩家重新进入时才开始录像。
func _on_body_entered(body: Node2D) -> void:
	if body != timeline.player or _requires_exit_before_restart:
		return
	if not timeline.start_future_recording(self):
		recording_rejected()


# 回传后必须先离开区域，记录器才能再次开始。
func _on_body_exited(body: Node2D) -> void:
	if body == timeline.player and not timeline.is_future_recording():
		_requires_exit_before_restart = false
