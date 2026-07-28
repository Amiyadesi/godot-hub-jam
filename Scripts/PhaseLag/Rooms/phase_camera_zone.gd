class_name PhaseCameraZone
extends Node2D
## Authored horizontal camera bounds for one room side.

@export var size: Vector2 = Vector2(1920.0, 704.0)


# Applies definition-owned room dimensions to this authored camera marker.
func configure_width(room_width_px: int) -> void:
	size = Vector2(float(room_width_px), 704.0)


# Returns this room's camera rectangle in chapter-world coordinates.
func get_world_bounds() -> Rect2:
	return Rect2(global_position, size)
