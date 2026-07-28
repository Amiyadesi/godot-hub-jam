class_name PhasePipelineSocket
extends Node2D
## One authored world-space module socket with explicit physical conduit neighbours.

const PICKUP_OUTLINE := Color(0.36, 1.0, 0.84, 1.0)
const LEGAL_OUTLINE := Color(0.48, 1.0, 0.72, 1.0)
const INVALID_OUTLINE := Color(0.94, 0.52, 0.2, 1.0)
const FIXED_OUTLINE := Color(0.72, 0.65, 0.54, 0.92)

@export var socket_id: StringName = &""
@export var connected_socket_ids: Array[StringName] = []
@export var enabled: bool = true
@export var allowed_part_types: Array[int] = []
@export var initial_definition: CircuitPartDefinition
@export_range(0, 3, 1) var initial_rotation_quarters: int = 0
@export var initial_fixed: bool = false
@export var source_id: StringName = &""
@export var output_id: StringName = &""
@export var output_link_id: StringName = &""
@export var output_event_type: StringName = EntanglementBus.POWER_CHANGED

@onready var part: CircuitPart = $Part
@onready var socket_plate: Sprite2D = $SocketPlate
@onready var interaction_point: Marker2D = $InteractionPoint
@onready var socket_outline_material: ShaderMaterial = socket_plate.material as ShaderMaterial


# Applies the authored module state without creating runtime gameplay nodes.
func _ready() -> void:
	visible = enabled
	if not enabled:
		return
	if initial_definition == null:
		part.clear()
	else:
		part.configure(
			initial_definition,
			initial_rotation_quarters,
			initial_fixed,
			source_id,
			output_id,
			output_link_id,
			output_event_type
		)
	set_feedback(false, false, false)


# Reports whether this physical socket accepts the requested module family.
func can_accept(definition: CircuitPartDefinition) -> bool:
	if not enabled or definition == null:
		return enabled
	return allowed_part_types.is_empty() or allowed_part_types.has(int(definition.part_type))


# Places one module into the existing authored visual and logical socket.
func set_part(
		definition: CircuitPartDefinition,
		rotation_quarters: int = 0,
		fixed: bool = false,
		new_source_id: StringName = &"",
		new_output_id: StringName = &"",
		new_output_link_id: StringName = &"",
		new_output_event_type: StringName = EntanglementBus.POWER_CHANGED
	) -> bool:
	if not can_accept(definition):
		return false
	part.configure(
		definition,
		rotation_quarters,
		fixed,
		new_source_id,
		new_output_id,
		new_output_link_id,
		new_output_event_type
	)
	return true


# Clears the replaceable module while retaining the authored wall fixture.
func clear_part() -> void:
	part.clear()


# Returns the reachable lower edge of this wall-mounted socket for proximity interaction.
func get_interaction_position() -> Vector2:
	return interaction_point.global_position


# Expresses pickup, placement, invalid, and fixed states through authored outlines.
func set_feedback(
		nearby: bool,
		legal: bool,
		selected: bool,
		fixed_landmark: bool = false,
		invalid: bool = false
	) -> void:
	if not enabled:
		return
	var outline_strength := 1.0 if selected else (0.52 if nearby else 0.0)
	var outline_color := PICKUP_OUTLINE
	if fixed_landmark:
		outline_strength = 0.56 if selected else (0.28 if nearby else 0.0)
		outline_color = FIXED_OUTLINE
	elif legal:
		outline_color = LEGAL_OUTLINE
	elif invalid:
		outline_strength = 0.68 if selected else (0.34 if nearby else 0.0)
		outline_color = INVALID_OUTLINE
	socket_outline_material.set_shader_parameter("outline_strength", outline_strength)
	socket_outline_material.set_shader_parameter("outline_color", outline_color)
	part.set_outline_feedback(outline_strength, outline_color)
