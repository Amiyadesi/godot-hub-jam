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
signal present_room_changed(active: bool)
signal run_countdown_changed(remaining_seconds: float, maximum_seconds: float)
signal run_countdown_expired
signal future_recording_committed_by_past(recorder: FutureRecorder)

const DEFAULT_PAST_DELAY := 3.0
const DEFAULT_DELAY_SWITCH_ID := &"delay_3s"
const DELAY_OPTIONS := [1.0, 3.0, 5.0]
const PAST_PHASE_WARNING_SECONDS := 0.6
const FUTURE_MINIMUM_SECONDS := 1.0
const FUTURE_MAXIMUM_SECONDS := 5.0
const TEMPORAL_PHASE_SECONDS := 0.35
const RUN_TIME_LIMIT_SECONDS := LevelModule.DEFAULT_RUN_COUNTDOWN_REMAINING

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
var _recording_run_countdown_remaining := -1.0
var _future_slots_used := 0
var _gameplay_active := false
var _present_room_active := false
var _run_countdown_remaining := RUN_TIME_LIMIT_SECONDS
var _run_countdown_session_active := false
var _run_countdown_paused := true
var _run_countdown_expired_emitted := false

# 初始化全局过去体；玩家与记录器由各自 prefab 进入场景时注册。
func _ready() -> void:
	past_echo.caught_player.connect(_on_past_echo_caught_player)
	reset_timeline()


# 注册当前场景的唯一玩家，并为新场景建立干净时间线。
func register_player(value: EchoPlayer) -> void:
	if player == value:
		return
	var entering_scene := player == null
	player = value
	_present_room_active = false
	_gameplay_active = true
	if entering_scene:
		_run_countdown_session_active = false
	_ensure_run_countdown()
	set_physics_process(true)
	var initial_delay := DEFAULT_PAST_DELAY
	var initial_switch_id := DEFAULT_DELAY_SWITCH_ID
	if LevelModule.instance != null:
		var saved_delay := LevelModule.instance.get_past_delay_seconds()
		var saved_switch_id := LevelModule.instance.get_delay_switch_id()
		if DELAY_OPTIONS.has(saved_delay) and not saved_switch_id.is_empty():
			initial_delay = saved_delay
			initial_switch_id = saved_switch_id
	reset_timeline(initial_delay, initial_switch_id)


# 场景卸载时清除已释放玩家留下的时态状态。
func unregister_player(value: EchoPlayer) -> void:
	if player != value:
		return
	player = null
	_present_room_active = false
	_gameplay_active = false
	_run_countdown_paused = true
	_run_countdown_session_active = false
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
		_recording_run_countdown_remaining = -1.0
		future_recording_finished.emit()
	_sync_future_slot_count()


# 由玩法场景控制全局时间线是否随世界推进。
func set_gameplay_active(value: bool) -> void:
	_gameplay_active = value


# Starts a fresh whole-run time limit without touching checkpoint data.
func start_run_countdown() -> void:
	_run_countdown_remaining = RUN_TIME_LIMIT_SECONDS
	_run_countdown_session_active = true
	_run_countdown_paused = true
	_run_countdown_expired_emitted = false
	if LevelModule.instance != null:
		LevelModule.instance.set_run_countdown_remaining(_run_countdown_remaining)
	_emit_run_countdown_changed()


# Starts a timer for direct scene entry while preserving an active Continue run.
func _ensure_run_countdown() -> void:
	if _run_countdown_session_active:
		return
	_run_countdown_remaining = RUN_TIME_LIMIT_SECONDS
	_run_countdown_expired_emitted = false
	if LevelModule.instance != null:
		_run_countdown_remaining = LevelModule.instance.get_run_countdown_remaining()
		_run_countdown_expired_emitted = LevelModule.instance.has_run_countdown_expired()
	_run_countdown_session_active = true
	_run_countdown_paused = true
	_emit_run_countdown_changed()
	if is_zero_approx(_run_countdown_remaining) and not _run_countdown_expired_emitted:
		_run_countdown_expired_emitted = true
		run_countdown_expired.emit()


# Pauses only the whole-run countdown, used by PresentHub dialogue and presence.
func pause_run_countdown() -> void:
	_run_countdown_paused = true


# Resumes the whole-run countdown after entry transitions or leaving PresentHub.
func resume_run_countdown() -> void:
	if _run_countdown_session_active:
		_run_countdown_paused = false


# Returns the current slot-backed whole-run time limit.
func get_run_countdown_remaining() -> float:
	return _run_countdown_remaining


# 只在玩法未暂停时推进确定性回放时间。
func _physics_process(delta: float) -> void:
	_advance_run_countdown(delta)
	if not _gameplay_active or _present_room_active or player == null or get_tree().paused:
		return
	_timeline_seconds += delta
	_advance_past_delay_shift(delta)
	_advance_future_recording()
	past_echo.play_at(_run_track, _timeline_seconds - _past_delay_seconds)
	for recorder in recorders:
		recorder.get_future_echo().advance(delta)


# 将玩家物理样本追加到实时历史和当前录像。
func record_player_frame(frame: TemporalFrame) -> void:
	if _present_room_active:
		return
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
	if _present_room_active or player == null or not recorders.has(recorder):
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
	_recording_run_countdown_remaining = _run_countdown_remaining
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


# 正常提交录像并保留最短可用回放时长。
func commit_future_recording() -> bool:
	return _finish_future_recording(false)


# 将陷阱接触补成录像末帧，让未来体在该位置结束生命。
func commit_future_recording_due_to_failure() -> bool:
	if _recording_track == null:
		return false
	record_player_frame(player.build_temporal_frame(_timeline_seconds))
	return _finish_future_recording(true)


# 回传当前体、恢复录制起点世界，并启动对应未来回放。
func _finish_future_recording(dies_at_end: bool) -> bool:
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
	var finished_run_countdown_remaining := _recording_run_countdown_remaining
	var minimum_duration := 0.0 if dies_at_end else FUTURE_MINIMUM_SECONDS
	var playback_duration := clampf(duration, minimum_duration, FUTURE_MAXIMUM_SECONDS)
	finished_track.hold_last_frame_until(playback_duration)
	_recording_track = null
	_recording_recorder = null
	_recording_future_echo = null
	_recording_future_states.clear()
	_recording_anchor = {}
	_recording_run_countdown_remaining = -1.0
	_timeline_seconds = _recording_started_at
	_run_track.trim_after(_timeline_seconds)
	player.apply_temporal_recall(finished_anchor, TEMPORAL_PHASE_SECONDS)
	_restore_past_anchor(finished_anchor)
	for recorder in recorders:
		if recorder == null or not is_instance_valid(recorder):
			continue
		var playback_state: Dictionary = finished_future_states.get(recorder.get_instance_id(), {})
		if not playback_state.is_empty():
			var recorder_future := recorder.get_future_echo()
			if recorder_future != null and is_instance_valid(recorder_future):
				recorder_future.restore_playback_state(playback_state)
		recorder.refresh_future_state()
	future_echo.start_playback(finished_track, playback_duration, TEMPORAL_PHASE_SECONDS, dies_at_end)
	finished_recorder.recording_finished()
	_set_run_countdown_remaining(finished_run_countdown_remaining)
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
	if LevelModule.instance != null:
		LevelModule.instance.set_past_delay(seconds, switch_id)
	if _present_room_active:
		_past_delay_seconds = seconds
		_pending_past_delay_seconds = seconds
		_past_delay_switch_id = switch_id
		_pending_past_delay_switch_id = switch_id
		_phase_warning_remaining = 0.0
		past_echo.end_phase_shift()
		past_delay_changed.emit(seconds, switch_id)
		return true
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
	_recording_run_countdown_remaining = -1.0
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


# Clears every non-present timeline state while preserving the selected delay.
func enter_present_room() -> bool:
	if _present_room_active:
		return false
	pause_run_countdown()
	_present_room_active = true
	_cancel_recording_for_present_room()
	_timeline_seconds = 0.0
	_phase_warning_remaining = 0.0
	_run_track.clear()
	past_echo.dissipate()
	for recorder in recorders:
		var future_echo := recorder.get_future_echo()
		if not future_echo.is_available():
			future_echo.dissipate()
		recorder.refresh_future_state()
	_sync_future_slot_count()
	present_room_changed.emit(true)
	return true


# Starts a clean run from the player's current position on leaving the hub.
func leave_present_room() -> bool:
	if not _present_room_active:
		return false
	_present_room_active = false
	reset_timeline(_pending_past_delay_seconds, _pending_past_delay_switch_id)
	resume_run_countdown()
	present_room_changed.emit(false)
	return true


# Reports whether history recording and echoes are suppressed by the hub.
func is_present_room_active() -> bool:
	return _present_room_active


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


# Cancels an in-flight recording without committing its future path.
func _cancel_recording_for_present_room() -> void:
	var cancelled_recorder := _recording_recorder
	_recording_track = null
	_recording_recorder = null
	_recording_future_echo = null
	_recording_future_states.clear()
	_recording_anchor = {}
	_recording_run_countdown_remaining = -1.0
	if cancelled_recorder != null:
		cancelled_recorder.recording_cancelled()
	future_recording_finished.emit()


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


# Advances the slot-backed whole-run limit everywhere except PresentHub.
func _advance_run_countdown(delta: float) -> void:
	if (
		not _run_countdown_session_active
		or _run_countdown_paused
		or player == null
		or _present_room_active
		or is_zero_approx(_run_countdown_remaining)
	):
		return
	_set_run_countdown_remaining(_run_countdown_remaining - delta)


# Clamps and publishes the whole-run limit for the global HUD.
func _set_run_countdown_remaining(value: float) -> void:
	var was_above_zero := _run_countdown_remaining > 0.0
	_run_countdown_remaining = clampf(value, 0.0, RUN_TIME_LIMIT_SECONDS)
	if LevelModule.instance != null:
		LevelModule.instance.set_run_countdown_remaining(_run_countdown_remaining)
	_emit_run_countdown_changed()
	if was_above_zero and is_zero_approx(_run_countdown_remaining) and not _run_countdown_expired_emitted:
		_run_countdown_expired_emitted = true
		run_countdown_expired.emit()


# Publishes both the live value and its authored maximum.
func _emit_run_countdown_changed() -> void:
	run_countdown_changed.emit(_run_countdown_remaining, RUN_TIME_LIMIT_SECONDS)


# 未来体停止影响玩法时只释放一个可能性槽。
func _on_future_slot_released(_future_echo: FutureEcho) -> void:
	_sync_future_slot_count()


# 录制中把抓捕转为回传；普通状态才进入 checkpoint 失败流程。
func _on_past_echo_caught_player() -> void:
	if is_future_recording():
		future_recording_committed_by_past.emit(_recording_recorder)
		commit_future_recording()
		return
	player.receive_past_catch()
	player_caught.emit()
