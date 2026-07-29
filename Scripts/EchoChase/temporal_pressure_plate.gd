class_name TemporalPressurePlate
extends Area2D
## 统计现存时态实体，并驱动可选 authored 时间门。

signal pressed_changed(is_pressed: bool)
signal occupancy_changed(occupancy: int)

@export var target_door: TemporalDoor

var _occupants: Dictionary = {}


# 不搜索场景树，直接连接玩家与时间区域重叠信号。
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	if target_door != null:
		pressed_changed.connect(target_door.set_open)


# 判断是否至少有一个有效时态实体压住压力板。
func is_pressed() -> bool:
	return not _occupants.is_empty()


# 当前玩家进入 authored 压力板区域时加入计数。
func _on_body_entered(body: Node2D) -> void:
	if body is EchoPlayer:
		_add_occupant(body)


# 当前玩家离开 authored 压力板区域时移出计数。
func _on_body_exited(body: Node2D) -> void:
	if body is EchoPlayer:
		_remove_occupant(body)


# 过去体或未来体进入 authored 压力板区域时加入计数。
func _on_area_entered(area: Area2D) -> void:
	if area is PastEcho or area is FutureEcho:
		_add_occupant(area)


# 过去体或未来体离开或消散时移出计数。
func _on_area_exited(area: Area2D) -> void:
	if area is PastEcho or area is FutureEcho:
		_remove_occupant(area)


# 加入一个唯一重叠，只在真实按压状态变化时发信号。
func _add_occupant(occupant: Node) -> void:
	var was_pressed := is_pressed()
	_occupants[occupant.get_instance_id()] = occupant
	occupancy_changed.emit(_occupants.size())
	if was_pressed != is_pressed():
		pressed_changed.emit(is_pressed())


# 移除一个重叠，只在真实按压状态变化时发信号。
func _remove_occupant(occupant: Node) -> void:
	var was_pressed := is_pressed()
	_occupants.erase(occupant.get_instance_id())
	occupancy_changed.emit(_occupants.size())
	if was_pressed != is_pressed():
		pressed_changed.emit(is_pressed())
