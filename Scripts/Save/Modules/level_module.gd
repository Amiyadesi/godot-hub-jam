class_name LevelModule
extends ISaveModule
## 仅保存一个稳定的《延迟追迹》复活点。

static var instance: LevelModule

const VALID_PAST_DELAYS := [1.0, 3.0, 5.0]

var checkpoint_scene_path := ""
var checkpoint_id := ""
var checkpoint_position := Vector2.ZERO
var past_delay_seconds := 3.0
var delay_switch_id := ""
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
	}


# 只接收当前坐标 schema；旧开发存档直接视为无进度。
func apply_data(data: Dictionary) -> void:
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
	}


# 新游戏清除旧复活点。
func on_new_game() -> void:
	clear_checkpoint()


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
