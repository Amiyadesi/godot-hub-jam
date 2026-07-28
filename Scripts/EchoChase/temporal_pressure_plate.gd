class_name TemporalPressurePlate
extends Area2D
## Counts present temporal bodies and drives an optional authored temporal door.

signal pressed_changed(is_pressed: bool)
signal occupancy_changed(occupancy: int)

@export var target_door: TemporalDoor

var _occupants: Dictionary = {}


# Wires player and temporal-area overlap without searching the scene tree.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	if target_door != null:
		pressed_changed.connect(target_door.set_open)


# Reports whether at least one valid temporal body presses this plate.
func is_pressed() -> bool:
	return not _occupants.is_empty()


# Adds the current player when it enters the authored plate area.
func _on_body_entered(body: Node2D) -> void:
	if body is EchoPlayer:
		_add_occupant(body)


# Removes the current player when it leaves the authored plate area.
func _on_body_exited(body: Node2D) -> void:
	if body is EchoPlayer:
		_remove_occupant(body)


# Adds a past or future body when it overlaps the authored plate area.
func _on_area_entered(area: Area2D) -> void:
	if area is PastEcho or area is FutureEcho:
		_add_occupant(area)


# Removes a past or future body when it leaves or dissipates.
func _on_area_exited(area: Area2D) -> void:
	if area is PastEcho or area is FutureEcho:
		_remove_occupant(area)


# Adds one unique overlap and emits only a real pressed-state change.
func _add_occupant(occupant: Node) -> void:
	var was_pressed := is_pressed()
	_occupants[occupant.get_instance_id()] = occupant
	occupancy_changed.emit(_occupants.size())
	if was_pressed != is_pressed():
		pressed_changed.emit(is_pressed())


# Removes one overlap and emits only a real pressed-state change.
func _remove_occupant(occupant: Node) -> void:
	var was_pressed := is_pressed()
	_occupants.erase(occupant.get_instance_id())
	occupancy_changed.emit(_occupants.size())
	if was_pressed != is_pressed():
		pressed_changed.emit(is_pressed())
