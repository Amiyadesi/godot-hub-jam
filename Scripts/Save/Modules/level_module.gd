class_name LevelModule
extends ISaveModule
## 保存《延迟追迹》的稳定复活点与槽位级世界进度。

signal progression_device_activated(device_id: String)
signal collectible_collected(item_id: String)

static var instance: LevelModule

const VALID_PAST_DELAYS := [1.0, 3.0, 5.0]

var checkpoint_scene_path := ""
var checkpoint_id := ""
var checkpoint_position := Vector2.ZERO
var past_delay_seconds := 3.0
var delay_switch_id := ""
var activated_progression_device_ids: Array[String] = []
var collected_item_ids: Array[String] = []
var present_hub_unlocked := false
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
		"present_hub_unlocked": present_hub_unlocked,
	}


# 只接收当前坐标 schema；旧开发存档直接视为无进度。
func apply_data(data: Dictionary) -> void:
	_apply_world_progress(data)
	var stored_position: Variant = data.get("checkpoint_position")
	if not stored_position is Dictionary:
		clear_checkpoint()
		return
	var position_data := stored_position as Dictionary
	if not position_data.has("x") or not position_data.has("y"):
		clear_checkpoint()
		return
	var stored_delay: Variant = data.get("past_delay_seconds")
	var stored_switch_id := str(data.get("delay_switch_id", ""))
	if not stored_delay is float and not stored_delay is int:
		clear_checkpoint()
		return
	var restored_delay := float(stored_delay)
	if not VALID_PAST_DELAYS.has(restored_delay) or stored_switch_id.is_empty():
		clear_checkpoint()
		return
	checkpoint_scene_path = str(data.get("checkpoint_scene_path", ""))
	checkpoint_id = str(data.get("checkpoint_id", ""))
	checkpoint_position = Vector2(float(position_data["x"]), float(position_data["y"]))
	past_delay_seconds = restored_delay
	delay_switch_id = stored_switch_id
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
		"delay_switch_id": "",
		"activated_progression_device_ids": [],
		"collected_item_ids": [],
		"present_hub_unlocked": false,
	}


# 新游戏清除旧复活点。
func on_new_game() -> void:
	clear_checkpoint()
	clear_world_progress()


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
	past_delay_seconds = 3.0
	delay_switch_id = ""
	_has_checkpoint_position = false


# Permanently activates one authored world device for the current save slot.
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


# Reports whether one authored world device is permanently active.
func is_progression_device_active(device_id: String) -> bool:
	return activated_progression_device_ids.has(device_id.strip_edges())


# Permanently stores one authored collectible for the current save slot.
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


# Permanently marks the central room as converted into the present state.
func unlock_present_hub() -> bool:
	if present_hub_unlocked:
		return false
	present_hub_unlocked = true
	return true


# Reports whether the central present-room event has already completed.
func is_present_hub_unlocked() -> bool:
	return present_hub_unlocked


# Clears permanent world progress only when starting a new run.
func clear_world_progress() -> void:
	activated_progression_device_ids.clear()
	collected_item_ids.clear()
	present_hub_unlocked = false


# Restores optional world-progress fields without invalidating legacy checkpoints.
func _apply_world_progress(data: Dictionary) -> void:
	activated_progression_device_ids.clear()
	var stored_ids: Variant = data.get("activated_progression_device_ids", [])
	if stored_ids is Array or stored_ids is PackedStringArray:
		for stored_id: Variant in stored_ids:
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
	present_hub_unlocked = bool(data.get("present_hub_unlocked", false))
