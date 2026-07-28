class_name TemporalDoor
extends StaticBody2D
## Simple authored barrier opened by one or more present temporal bodies.

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: CanvasItem = %Visual

var _is_open := true


# Applies the authored closed state when this door enters a room.
func _ready() -> void:
	set_open(false)


# Opens or closes physical passage while keeping state readable to the level author.
func set_open(value: bool) -> void:
	if _is_open == value:
		return
	_is_open = value
	collision_shape.set_deferred("disabled", value)
	visual.modulate = Color(0.38, 0.96, 0.82, 0.32) if value else Color(0.92, 0.34, 0.32, 0.88)


# Reports the current authored barrier state to external level logic.
func is_open() -> bool:
	return _is_open
