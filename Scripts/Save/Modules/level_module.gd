class_name LevelModule
extends ISaveModule
## 保存《延迟追迹》的稳定复活点与槽位级世界进度。

signal progression_device_activated(device_id: String)
signal collectible_collected(item_id: String)

static var instance: LevelModule

const VALID_PAST_DELAYS := [1.0, 3.0, 5.0]
const DEFAULT_RUN_COUNTDOWN_REMAINING := 1800.0

var checkpoint_scene_path := ""
var checkpoint_id := ""
var checkpoint_position := Vector2.ZERO
var past_delay_seconds := 3.0
var delay_switch_id := "delay_3s"
# Branch devices persist immediately when activated; checkpoint-gated state is stored separately below.
var activated_progression_device_ids: Array[String] = []
var collected_item_ids: Array[String] = []
var opened_latched_door_ids: Array[String] = []
var closed_latched_door_ids: Array[String] = []
var pending_latched_door_ids: Array[String] = []
var present_hub_unlocked := false
var run_countdown_expired := false
var run_countdown_remaining := DEFAULT_RUN_COUNTDOWN_REMAINING
var _has_checkpoint_position := false


# 注册当前槽位模块，供菜单与玩法场景直接访问。
func _init() -> void:
	instance = self


# 返回固定的槽位存档键。
func get_module_key() -> String:
	return "level"


# 将关卡进度限制在当前存档槽。
func is_global() -> bool:
	return false


# 将复活坐标转成 JSON 可写的基础类型。
func collect_data() -> Dictionary:
	return {
		"checkpoint_scene_path": checkpoint_scene_path,
		"checkpoint_id": checkpoint_id,
		"checkpoint_position": {
			"x": checkpoint_position.x,
			"y": checkpoint_position.y,
		},
		"past_delay_seconds": past_delay_seconds,
		"delay_switch_id": delay_switch_id,
		"activated_progression_device_ids": activated_progression_device_ids.duplicate(),
		"collected_item_ids": collected_item_ids.duplicate(),
		"opened_latched_door_ids": opened_latched_door_ids.duplicate(),
		"closed_latched_door_ids": closed_latched_door_ids.duplicate(),
		"present_hub_unlocked": present_hub_unlocked,
		"run_countdown_expired": run_countdown_expired,
		"run_countdown_remaining": run_countdown_remaining,
	}


# 只接收当前坐标 schema；旧开发存档直接视为无进度。
func apply_data(data: Dictionary) -> void:
	_apply_world_progress(data)
	var stored_delay: Variant = data.get("past_delay_seconds", 3.0)
	var restored_delay := 3.0
	if stored_delay is float or stored_delay is int:
		var candidate_delay := float(stored_delay)
		if VALID_PAST_DELAYS.has(candidate_delay):
			restored_delay = candidate_delay
	var restored_switch_id := str(data.get("delay_switch_id", ""))
	if restored_switch_id.is_empty():
		restored_switch_id = "delay_%ds" % int(restored_delay)
	past_delay_seconds = restored_delay
	delay_switch_id = restored_switch_id
	var stored_countdown: Variant = data.get(
		"run_countdown_remaining",
		0.0 if run_countdown_expired else DEFAULT_RUN_COUNTDOWN_REMAINING
	)
	if stored_countdown is float or stored_countdown is int:
		run_countdown_remaining = clampf(float(stored_countdown), 0.0, DEFAULT_RUN_COUNTDOWN_REMAINING)
	else:
		run_countdown_remaining = DEFAULT_RUN_COUNTDOWN_REMAINING
	var stored_position: Variant = data.get("checkpoint_position")
	if not stored_position is Dictionary:
		clear_checkpoint()
		return
	var position_data := stored_position as Dictionary
	if not position_data.has("x") or not position_data.has("y"):
		clear_checkpoint()
		return
	var stored_switch_id := str(data.get("delay_switch_id", ""))
	if stored_switch_id.is_empty():
		clear_checkpoint()
		return
	checkpoint_scene_path = str(data.get("checkpoint_scene_path", ""))
	checkpoint_id = str(data.get("checkpoint_id", ""))
	checkpoint_position = Vector2(float(position_data["x"]), float(position_data["y"]))
	_has_checkpoint_position = (
		not checkpoint_scene_path.is_empty()
		and not checkpoint_id.is_empty()
		and not delay_switch_id.is_empty()
	)


# 为新游戏提供空复活点数据。
func get_default_data() -> Dictionary:
	return {
		"checkpoint_scene_path": "",
		"checkpoint_id": "",
		"checkpoint_position": {"x": 0.0, "y": 0.0},
		"past_delay_seconds": 3.0,
		"delay_switch_id": "delay_3s",
		"activated_progression_device_ids": [],
		"collected_item_ids": [],
		"opened_latched_door_ids": [],
		"closed_latched_door_ids": [],
		"present_hub_unlocked": false,
		"run_countdown_expired": false,
		"run_countdown_remaining": DEFAULT_RUN_COUNTDOWN_REMAINING,
	}


# 新游戏清除旧复活点。
func on_new_game() -> void:
	clear_checkpoint()
	clear_world_progress()
	past_delay_seconds = 3.0
	delay_switch_id = "delay_3s"
	run_countdown_remaining = DEFAULT_RUN_COUNTDOWN_REMAINING


# 保存 authored 复活点场景、ID 与世界坐标。
func set_checkpoint(
	scene_path: String,
	new_checkpoint_id: String,
	respawn_position: Vector2,
	new_past_delay_seconds := 3.0,
	new_delay_switch_id := "delay_3s"
) -> void:
	if scene_path.is_empty() or new_checkpoint_id.is_empty() or new_delay_switch_id.is_empty():
		push_error("LevelModule.set_checkpoint requires scene, checkpoint, and delay switch ids")
		return
	if not VALID_PAST_DELAYS.has(new_past_delay_seconds):
		push_error("LevelModule.set_checkpoint only accepts 1, 3, or 5 second past delays")
		return
	checkpoint_scene_path = scene_path
	checkpoint_id = new_checkpoint_id
	checkpoint_position = respawn_position
	past_delay_seconds = new_past_delay_seconds
	delay_switch_id = new_delay_switch_id
	_has_checkpoint_position = true


# 保存当前槽位选中的过去延迟，即使玩家尚未激活新的 checkpoint。
func set_past_delay(new_delay_seconds: float, new_delay_switch_id: StringName) -> bool:
	if not VALID_PAST_DELAYS.has(new_delay_seconds) or new_delay_switch_id.is_empty():
		push_error("LevelModule.set_past_delay requires a valid delay and switch id")
		return false
	past_delay_seconds = new_delay_seconds
	delay_switch_id = String(new_delay_switch_id)
	return true


# 返回当前槽位选中的过去延迟。
func get_past_delay_seconds() -> float:
	return past_delay_seconds


# 返回当前槽位选中的延迟台 ID。
func get_delay_switch_id() -> StringName:
	return StringName(delay_switch_id)


# 保存整局倒计时的最新内存值，真正落盘仍由 SaveSystem.save_slot 触发。
func set_run_countdown_remaining(value: float) -> void:
	run_countdown_remaining = clampf(value, 0.0, DEFAULT_RUN_COUNTDOWN_REMAINING)


# 返回整局倒计时剩余秒数。
func get_run_countdown_remaining() -> float:
	return run_countdown_remaining


# 判断当前槽位是否有完整、可继续的复活点。
func has_continue_point() -> bool:
	return (
		_has_checkpoint_position
		and not checkpoint_scene_path.is_empty()
		and not checkpoint_id.is_empty()
		and not delay_switch_id.is_empty()
	)


# 返回最新复活点所属场景。
func get_continue_scene_path() -> String:
	return checkpoint_scene_path


# 返回供 authored 场景恢复的运行时快照。
func get_checkpoint() -> Dictionary:
	if not has_continue_point():
		return {}
	return {
		"scene_path": checkpoint_scene_path,
		"checkpoint_id": checkpoint_id,
		"position": checkpoint_position,
		"past_delay_seconds": past_delay_seconds,
		"delay_switch_id": delay_switch_id,
	}


# 清空复活点，不迁移任何旧原型格式。
func clear_checkpoint() -> void:
	checkpoint_scene_path = ""
	checkpoint_id = ""
	checkpoint_position = Vector2.ZERO
	_has_checkpoint_position = false


# Activates one authored world device and immediately records it in the current slot.
func activate_progression_device(device_id: String) -> bool:
	var normalized_id := device_id.strip_edges()
	if normalized_id.is_empty():
		push_error("LevelModule.activate_progression_device requires a non-empty id")
		return false
	if activated_progression_device_ids.has(normalized_id):
		return false
	activated_progression_device_ids.append(normalized_id)
	progression_device_activated.emit(normalized_id)
	return true


# Reports whether one authored world device is active in the current slot state.
func is_progression_device_active(device_id: String) -> bool:
	return activated_progression_device_ids.has(device_id.strip_edges())


# Marks one Latched ALL door in runtime memory; checkpoint commits it.
func open_latched_door(door_id: String) -> bool:
	var normalized_id := door_id.strip_edges()
	if normalized_id.is_empty():
		push_error("LevelModule.open_latched_door requires a non-empty id")
		return false
	if closed_latched_door_ids.has(normalized_id):
		return false
	if opened_latched_door_ids.has(normalized_id) or pending_latched_door_ids.has(normalized_id):
		return false
	pending_latched_door_ids.append(normalized_id)
	return true


# Reports whether one authored Latched ALL door is open in the current run.
func is_latched_door_open(door_id: String) -> bool:
	var normalized_id := door_id.strip_edges()
	if closed_latched_door_ids.has(normalized_id):
		return false
	return opened_latched_door_ids.has(normalized_id) or pending_latched_door_ids.has(normalized_id)


# Persists a checkpoint-forced closed state and removes any open state.
func close_latched_door(door_id: String) -> bool:
	var normalized_id := door_id.strip_edges()
	if normalized_id.is_empty():
		push_error("LevelModule.close_latched_door requires a non-empty id")
		return false
	var changed := false
	if opened_latched_door_ids.has(normalized_id):
		opened_latched_door_ids.erase(normalized_id)
		changed = true
	if pending_latched_door_ids.has(normalized_id):
		pending_latched_door_ids.erase(normalized_id)
		changed = true
	if not closed_latched_door_ids.has(normalized_id):
		closed_latched_door_ids.append(normalized_id)
		changed = true
	return changed


# Reports whether a checkpoint permanently closed one Latched ALL door.
func is_latched_door_closed(door_id: String) -> bool:
	return closed_latched_door_ids.has(door_id.strip_edges())


# Commits all runtime-open Latched ALL doors when a checkpoint is touched.
func commit_latched_doors() -> bool:
	var changed := false
	for door_id in pending_latched_door_ids:
		if not closed_latched_door_ids.has(door_id) and not opened_latched_door_ids.has(door_id):
			opened_latched_door_ids.append(door_id)
			changed = true
	pending_latched_door_ids.clear()
	return changed


# Drops uncommitted Latched ALL doors before checkpoint-based reset.
func discard_pending_latched_doors() -> void:
	pending_latched_door_ids.clear()


# Stores one authored collectible in memory; the current checkpoint commits it.
func collect_item(item_id: String) -> bool:
	var normalized_id := item_id.strip_edges()
	if normalized_id.is_empty():
		push_error("LevelModule.collect_item requires a non-empty id")
		return false
	if collected_item_ids.has(normalized_id):
		return false
	collected_item_ids.append(normalized_id)
	collectible_collected.emit(normalized_id)
	return true


# Reports whether one authored collectible already belongs to this slot.
func is_item_collected(item_id: String) -> bool:
	return collected_item_ids.has(item_id.strip_edges())


# Returns the number of slot-persistent authored collectibles.
func get_collected_item_count() -> int:
	return collected_item_ids.size()


# Permanently marks the central room as converted into the present state.
func unlock_present_hub() -> bool:
	if present_hub_unlocked:
		return false
	present_hub_unlocked = true
	return true


# Reports whether the central present-room event has already completed.
func is_present_hub_unlocked() -> bool:
	return present_hub_unlocked


# Marks the false run deadline as expired once for this save slot.
func mark_run_countdown_expired() -> bool:
	if run_countdown_expired:
		return false
	run_countdown_expired = true
	return true


# Reports whether this slot has already reached the false deadline.
func has_run_countdown_expired() -> bool:
	return run_countdown_expired


# Clears world progress only when starting a new run.
func clear_world_progress() -> void:
	activated_progression_device_ids.clear()
	collected_item_ids.clear()
	opened_latched_door_ids.clear()
	closed_latched_door_ids.clear()
	pending_latched_door_ids.clear()
	present_hub_unlocked = false
	run_countdown_expired = false
	run_countdown_remaining = DEFAULT_RUN_COUNTDOWN_REMAINING


# Restores optional world-progress fields without invalidating legacy checkpoints.
func _apply_world_progress(data: Dictionary) -> void:
	activated_progression_device_ids.clear()
	var stored_device_ids: Variant = data.get("activated_progression_device_ids", [])
	if stored_device_ids is Array or stored_device_ids is PackedStringArray:
		for stored_id: Variant in stored_device_ids:
			var normalized_id := str(stored_id).strip_edges()
			if not normalized_id.is_empty() and not activated_progression_device_ids.has(normalized_id):
				activated_progression_device_ids.append(normalized_id)
	collected_item_ids.clear()
	var stored_item_ids: Variant = data.get("collected_item_ids", [])
	if stored_item_ids is Array or stored_item_ids is PackedStringArray:
		for stored_id: Variant in stored_item_ids:
			var normalized_id := str(stored_id).strip_edges()
			if not normalized_id.is_empty() and not collected_item_ids.has(normalized_id):
				collected_item_ids.append(normalized_id)
	opened_latched_door_ids.clear()
	closed_latched_door_ids.clear()
	pending_latched_door_ids.clear()
	var stored_closed_door_ids: Variant = data.get("closed_latched_door_ids", [])
	if stored_closed_door_ids is Array or stored_closed_door_ids is PackedStringArray:
		for stored_id: Variant in stored_closed_door_ids:
			var normalized_id := str(stored_id).strip_edges()
			if not normalized_id.is_empty() and not closed_latched_door_ids.has(normalized_id):
				closed_latched_door_ids.append(normalized_id)
	var stored_door_ids: Variant = data.get("opened_latched_door_ids", [])
	if stored_door_ids is Array or stored_door_ids is PackedStringArray:
		for stored_id: Variant in stored_door_ids:
			var normalized_id := str(stored_id).strip_edges()
			if (
				not normalized_id.is_empty()
				and not closed_latched_door_ids.has(normalized_id)
				and not opened_latched_door_ids.has(normalized_id)
			):
				opened_latched_door_ids.append(normalized_id)
	present_hub_unlocked = bool(data.get("present_hub_unlocked", false))
	run_countdown_expired = bool(data.get("run_countdown_expired", false))
