extends Node
## 持有一条实时路径、一个过去体和 authored 记录器各自的未来体。

signal future_slots_changed(used_slots: int, max_slots: int)
signal past_delay_switch_started(seconds: float, switch_id: StringName)
signal past_delay_changed(seconds: float, switch_id: StringName)
signal player_caught
signal future_recording_started
signal future_recording_progress(elapsed_seconds: float, maximum_seconds: float)
signal future_recording_finished
signal future_recording_rejected

const DEFAULT_PAST_DELAY := 3.0
const DEFAULT_DELAY_SWITCH_ID := &"delay_3s"
const DELAY_OPTIONS := [1.0, 3.0, 5.0]
const PAST_PHASE_WARNING_SECONDS := 0.6
const FUTURE_MINIMUM_SECONDS := 1.0
const FUTURE_MAXIMUM_SECONDS := 5.0
const TEMPORAL_PHASE_SECONDS := 0.35

@onready var past_echo: PastEcho = %PastEcho

var player: EchoPlayer
var recorders: Array[FutureRecorder] = []
var _timeline_seconds := 0.0
var _past_delay_seconds := DEFAULT_PAST_DELAY
var _pending_past_delay_seconds := DEFAULT_PAST_DELAY
var _past_delay_switch_id := DEFAULT_DELAY_SWITCH_ID
var _pending_past_delay_switch_id := DEFAULT_DELAY_SWITCH_ID
var _phase_warning_remaining := 0.0
var _run_track := TemporalTrack.new()
var _recording_track: TemporalTrack
var _recording_recorder: FutureRecorder
var _recording_future_echo: FutureEcho
var _recording_future_states: Dictionary = {}
var _recording_started_at := 0.0
var _recording_anchor: Dictionary = {}
var _future_slots_used := 0
var _gameplay_active := false

# 初始化全局过去体；玩家与记录器由各自 prefab 进入场景时注册。
func _ready() -> void:
	past_echo.caught_player.connect(_on_past_echo_caught_player)
	reset_timeline()


# 注册当前场景的唯一玩家，并为新场景建立干净时间线。
func register_player(value: EchoPlayer) -> void:
	if player == value:
		return
	player = value
	_gameplay_active = true
	set_physics_process(true)
	reset_timeline()


# 场景卸载时清除已释放玩家留下的时态状态。
func unregister_player(value: EchoPlayer) -> void:
	if player != value:
		return
	player = null
	_gameplay_active = false
	reset_timeline()


# 注册一台带有自身 FutureEcho 的记录器，不要求固定数量或固定路径。
func register_recorder(recorder: FutureRecorder) -> void:
	if recorder == null or recorders.has(recorder):
		return
	var future_echo := recorder.get_future_echo()
	if future_echo == null:
		return
	recorders.append(recorder)
	if not future_echo.slot_released.is_connected(_on_future_slot_released):
		future_echo.slot_released.connect(_on_future_slot_released)
	future_echo.reset_echo()
	recorder.refresh_future_state()
	_sync_future_slot_count()


# 注销被用户删除的记录器，避免全局时间线留下失效引用。
func unregister_recorder(recorder: FutureRecorder) -> void:
	if not recorders.has(recorder):
		return
	recorders.erase(recorder)
	if recorder == _recording_recorder:
		_recording_track = null
		_recording_recorder = null
		_recording_future_echo = null
		_recording_future_states.clear()
		_recording_anchor = {}
		future_recording_finished.emit()
	_sync_future_slot_count()


# 由玩法场景控制全局时间线是否随世界推进。
func set_gameplay_active(value: bool) -> void:
	_gameplay_active = value


# 只在玩法未暂停时推进确定性回放时间。
func _physics_process(delta: float) -> void:
	if not _gameplay_active or player == null or get_tree().paused:
		return
	_timeline_seconds += delta
	_advance_past_delay_shift(delta)
	_advance_future_recording()
	past_echo.play_at(_run_track, _timeline_seconds - _past_delay_seconds)
	for recorder in recorders:
		recorder.get_future_echo().advance(delta)


# 将玩家物理样本追加到实时历史和当前录像。
func record_player_frame(frame: TemporalFrame) -> void:
	_run_track.append(frame)
	if _recording_track == null:
		return
	var recording_frame := frame.copy()
	recording_frame.time_seconds -= _recording_started_at
	_recording_track.append(recording_frame)


# 返回 authored 玩家样本必须使用的单调时间。
func get_timeline_seconds() -> float:
	return _timeline_seconds


# 开始一次未来录像并立即占用可能性槽。
func start_future_recording(recorder: FutureRecorder) -> bool:
	if player == null or not recorders.has(recorder):
		future_recording_rejected.emit()
		return false
	if _recording_track != null:
		future_recording_rejected.emit()
		return false
	var reserved_future := recorder.get_future_echo()
	if not reserved_future.is_available():
		future_recording_rejected.emit()
		return false
	_recording_track = TemporalTrack.new()
	_recording_recorder = recorder
	_recording_future_echo = reserved_future
	_recording_future_states.clear()
	for authored_recorder in recorders:
		_recording_future_states[authored_recorder.get_instance_id()] = authored_recorder.get_future_echo().capture_playback_state()
	_recording_started_at = _timeline_seconds
	_recording_anchor = player.capture_temporal_anchor(_timeline_seconds)
	_recording_anchor["past_delay_seconds"] = _past_delay_seconds
	_recording_anchor["pending_past_delay_seconds"] = _pending_past_delay_seconds
	_recording_anchor["past_delay_switch_id"] = _past_delay_switch_id
	_recording_anchor["pending_past_delay_switch_id"] = _pending_past_delay_switch_id
	_recording_anchor["phase_warning_remaining"] = _phase_warning_remaining
	var anchor_frame := _recording_anchor["frame"] as TemporalFrame
	_run_track.append(anchor_frame)
	var start_frame := anchor_frame.copy()
	start_frame.time_seconds = 0.0
	_recording_track.append(start_frame)
	recorder.recording_started()
	_sync_future_slot_count()
	future_recording_started.emit()
	future_recording_progress.emit(0.0, FUTURE_MAXIMUM_SECONDS)
	return true


# 提交录像、补足最短时长、回传玩家并启动 authored 未来体。
func commit_future_recording() -> bool:
	if _recording_track == null:
		return false
	var duration := _timeline_seconds - _recording_started_at
	var future_echo := _recording_future_echo
	if future_echo == null:
		push_error("EchoTimeline lost its reserved FutureEcho slot")
		return false
	var finished_track := _recording_track
	var finished_recorder := _recording_recorder
	var finished_anchor := _recording_anchor
	var finished_future_states := _recording_future_states.duplicate()
	var playback_duration := clampf(duration, FUTURE_MINIMUM_SECONDS, FUTURE_MAXIMUM_SECONDS)
	finished_track.hold_last_frame_until(playback_duration)
	_recording_track = null
	_recording_recorder = null
	_recording_future_echo = null
	_recording_future_states.clear()
	_recording_anchor = {}
	_timeline_seconds = _recording_started_at
	_run_track.trim_after(_timeline_seconds)
	player.apply_temporal_recall(finished_anchor, TEMPORAL_PHASE_SECONDS)
	_restore_past_anchor(finished_anchor)
	for recorder in recorders:
		var playback_state: Dictionary = finished_future_states.get(recorder.get_instance_id(), {})
		if not playback_state.is_empty():
			recorder.get_future_echo().restore_playback_state(playback_state)
		recorder.refresh_future_state()
	future_echo.start_playback(finished_track, playback_duration, TEMPORAL_PHASE_SECONDS)
	finished_recorder.recording_finished()
	_sync_future_slot_count()
	future_recording_finished.emit()
	return true


# 请求切换过去延迟；连续请求只覆盖目标，不重置既有预警。
func request_past_delay(seconds: float, switch_id: StringName) -> bool:
	if not DELAY_OPTIONS.has(seconds):
		push_error("EchoTimeline.request_past_delay only accepts 1, 3, or 5 seconds")
		return false
	if switch_id.is_empty():
		push_error("EchoTimeline.request_past_delay requires a delay switch id")
		return false
	if (
		is_equal_approx(seconds, _pending_past_delay_seconds)
		and switch_id == _pending_past_delay_switch_id
	):
		return false
	_pending_past_delay_seconds = seconds
	_pending_past_delay_switch_id = switch_id
	if is_zero_approx(_phase_warning_remaining):
		_phase_warning_remaining = PAST_PHASE_WARNING_SECONDS
		past_echo.begin_phase_shift()
	var elapsed_warning := PAST_PHASE_WARNING_SECONDS - _phase_warning_remaining
	past_echo.preview_phase_target(_run_track, _timeline_seconds - seconds, elapsed_warning)
	past_delay_switch_started.emit(seconds, switch_id)
	return true


# 保留简单数值入口供现有 authored 调用迁移到具名延迟台。
func set_past_delay(seconds: float) -> void:
	request_past_delay(seconds, StringName("delay_%ds" % int(seconds)))


# 清空临时时间状态，并用指定延迟台建立新的干净时间线。
func reset_timeline(
	initial_delay_seconds := DEFAULT_PAST_DELAY,
	initial_switch_id := DEFAULT_DELAY_SWITCH_ID
) -> void:
	if not DELAY_OPTIONS.has(initial_delay_seconds):
		push_error("EchoTimeline.reset_timeline only accepts 1, 3, or 5 second past delays")
		return
	if initial_switch_id.is_empty():
		push_error("EchoTimeline.reset_timeline requires a delay switch id")
		return
	var cancelled_recorder := _recording_recorder
	_timeline_seconds = 0.0
	_past_delay_seconds = initial_delay_seconds
	_pending_past_delay_seconds = initial_delay_seconds
	_past_delay_switch_id = initial_switch_id
	_pending_past_delay_switch_id = initial_switch_id
	_phase_warning_remaining = 0.0
	_run_track.clear()
	_recording_track = null
	_recording_recorder = null
	_recording_future_echo = null
	_recording_future_states.clear()
	_recording_anchor = {}
	past_echo.reset_echo()
	for recorder in recorders:
		var future_echo: FutureEcho = recorder.get_future_echo()
		if future_echo != null:
			future_echo.reset_echo()
	if cancelled_recorder != null:
		cancelled_recorder.recording_cancelled()
	for recorder in recorders:
		recorder.refresh_future_state()
	_future_slots_used = 0
	future_slots_changed.emit(_future_slots_used, recorders.size())
	past_delay_changed.emit(_past_delay_seconds, _past_delay_switch_id)
	future_recording_finished.emit()


# 判断玩家当前是否处于录像状态。
func is_future_recording() -> bool:
	return _recording_track != null


# 返回当前录像时长，供 authored 记录器表现使用。
func get_future_recording_seconds() -> float:
	return maxf(_timeline_seconds - _recording_started_at, 0.0) if _recording_track != null else 0.0


# 返回玩家最近选择的延迟，切档预警中也返回新目标。
func get_selected_past_delay_seconds() -> float:
	return _pending_past_delay_seconds


# 返回玩家最近选择的 authored 延迟台 ID。
func get_selected_delay_switch_id() -> StringName:
	return _pending_past_delay_switch_id


# 恢复录像起点的过去延迟与切档剩余时间，并同步 authored 延迟台表现。
func _restore_past_anchor(anchor: Dictionary) -> void:
	_past_delay_seconds = float(anchor["past_delay_seconds"])
	_pending_past_delay_seconds = float(anchor["pending_past_delay_seconds"])
	_past_delay_switch_id = anchor["past_delay_switch_id"] as StringName
	_pending_past_delay_switch_id = anchor["pending_past_delay_switch_id"] as StringName
	_phase_warning_remaining = float(anchor["phase_warning_remaining"])
	if _phase_warning_remaining > 0.0:
		past_echo.begin_phase_shift()
		var elapsed_warning := PAST_PHASE_WARNING_SECONDS - _phase_warning_remaining
		past_echo.preview_phase_target(
			_run_track,
			_timeline_seconds - _pending_past_delay_seconds,
			elapsed_warning
		)
		past_delay_switch_started.emit(_pending_past_delay_seconds, _pending_past_delay_switch_id)
		return
	past_echo.end_phase_shift()
	past_echo.play_at(_run_track, _timeline_seconds - _past_delay_seconds)
	past_delay_changed.emit(_past_delay_seconds, _past_delay_switch_id)


# 先推进相位预警，再应用选定的历史偏移。
func _advance_past_delay_shift(delta: float) -> void:
	if is_zero_approx(_phase_warning_remaining):
		return
	_phase_warning_remaining = maxf(_phase_warning_remaining - delta, 0.0)
	if not is_zero_approx(_phase_warning_remaining):
		return
	_past_delay_seconds = _pending_past_delay_seconds
	_past_delay_switch_id = _pending_past_delay_switch_id
	past_echo.end_phase_shift()
	past_delay_changed.emit(_past_delay_seconds, _past_delay_switch_id)


# 录像达到约定上限时自动提交。
func _advance_future_recording() -> void:
	if _recording_track == null:
		return
	future_recording_progress.emit(get_future_recording_seconds(), FUTURE_MAXIMUM_SECONDS)
	if get_future_recording_seconds() >= FUTURE_MAXIMUM_SECONDS:
		commit_future_recording()


# 回退恢复可能性后，用真实活动槽修正录制期间的释放计数。
func _sync_future_slot_count() -> void:
	var active_slots := 0
	for recorder in recorders:
		var future_echo: FutureEcho = recorder.get_future_echo()
		if future_echo != null:
			active_slots += int(not future_echo.is_available())
	if _recording_track != null and _recording_future_echo != null and _recording_future_echo.is_available():
		active_slots += 1
	if active_slots == _future_slots_used:
		return
	_future_slots_used = active_slots
	future_slots_changed.emit(_future_slots_used, recorders.size())
# 未来体停止影响玩法时只释放一个可能性槽。
func _on_future_slot_released(_future_echo: FutureEcho) -> void:
	_sync_future_slot_count()


# 录制中把抓捕转为回传；普通状态才进入 checkpoint 失败流程。
func _on_past_echo_caught_player() -> void:
	if is_future_recording():
		commit_future_recording()
		return
	player.receive_past_catch()
	player_caught.emit()
