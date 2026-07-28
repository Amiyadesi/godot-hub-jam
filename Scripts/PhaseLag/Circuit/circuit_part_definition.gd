class_name CircuitPartDefinition
extends Resource
## Read-only authored definition for one 32px physical circuit tile.

enum PartType {
	EMPTY,
	GENERATOR,
	WIRE_STRAIGHT,
	WIRE_CORNER,
	WIRE_TEE,
	TIMER,
	INVERTER,
	AND_GATE,
	MEMORY,
	OUTPUT,
}

const PORT_UP: int = 1
const PORT_RIGHT: int = 2
const PORT_DOWN: int = 4
const PORT_LEFT: int = 8

@export var part_type: PartType = PartType.EMPTY
@export var display_name: String = "空槽"
@export_flags("上", "右", "下", "左") var port_mask: int = 0
@export_flags("上", "右", "下", "左") var input_port_mask: int = 0
@export_flags("上", "右", "下", "左") var output_port_mask: int = 0
@export_range(0.0, 18.0, 0.1, "suffix:s") var delay_seconds: float = 0.0
@export var movable: bool = true
@export var visual_texture: Texture2D
@export var visual_scale: Vector2 = Vector2.ONE
@export var visual_offset: Vector2 = Vector2.ZERO


# Rotates one four-direction bit mask clockwise by the requested quarter turns.
func rotate_mask(mask: int, quarter_turns: int) -> int:
	var result := mask & 0xF
	for _turn in range(posmod(quarter_turns, 4)):
		result = ((result << 1) & 0xF) | ((result >> 3) & 1)
	return result


# Returns all physical ports after applying the part's current rotation.
func get_ports(rotation_quarters: int) -> int:
	return rotate_mask(port_mask | input_port_mask | output_port_mask, rotation_quarters)


# Returns the directed input ports after applying the part's current rotation.
func get_input_ports(rotation_quarters: int) -> int:
	return rotate_mask(input_port_mask if input_port_mask != 0 else port_mask, rotation_quarters)


# Returns the directed output ports after applying the part's current rotation.
func get_output_ports(rotation_quarters: int) -> int:
	return rotate_mask(output_port_mask if output_port_mask != 0 else port_mask, rotation_quarters)


# Reports whether the tile is one of the directionless wire variants.
func is_wire() -> bool:
	return part_type in [PartType.WIRE_STRAIGHT, PartType.WIRE_CORNER, PartType.WIRE_TEE]
