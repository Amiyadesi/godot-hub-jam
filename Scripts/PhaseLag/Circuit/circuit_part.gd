class_name CircuitPart
extends Node2D
## Mutable per-socket circuit tile backed by a shared read-only definition.

@export var definition: CircuitPartDefinition
@export_range(0, 3, 1) var rotation_quarters: int = 0
@export var fixed: bool = false
@export var source_id: StringName = &""
@export var output_id: StringName = &""
@export var output_link_id: StringName = &""
@export var output_event_type: StringName = EntanglementBus.POWER_CHANGED

var powered: bool = false
var memory_latched: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var power_glow: Polygon2D = $PowerGlow
@onready var delay_label: Label = $DelayLabel
@onready var outline_material: ShaderMaterial = sprite.material as ShaderMaterial
@onready var port_markers: Array[Polygon2D] = [$PortUp, $PortRight, $PortDown, $PortLeft]


# Applies the authored definition to the replaceable visual interface.
func _ready() -> void:
	_refresh_visual()


# Replaces this existing authored tile without creating any runtime nodes.
func configure(
		new_definition: CircuitPartDefinition,
		new_rotation: int = 0,
		new_fixed: bool = false,
		new_source_id: StringName = &"",
		new_output_id: StringName = &"",
		new_output_link_id: StringName = &"",
		new_event_type: StringName = EntanglementBus.POWER_CHANGED
	) -> void:
	definition = new_definition
	rotation_quarters = posmod(new_rotation, 4)
	fixed = new_fixed or (definition != null and not definition.movable)
	source_id = new_source_id
	output_id = new_output_id
	output_link_id = new_output_link_id
	output_event_type = new_event_type
	powered = false
	memory_latched = false
	if is_node_ready():
		_refresh_visual()


# Clears one socket's mutable tile state while retaining its authored node.
func clear() -> void:
	definition = null
	rotation_quarters = 0
	fixed = false
	source_id = &""
	output_id = &""
	output_link_id = &""
	output_event_type = EntanglementBus.POWER_CHANGED
	powered = false
	memory_latched = false
	if is_node_ready():
		_refresh_visual()


# Rotates this tile clockwise by exactly ninety degrees when it is movable.
func rotate_clockwise() -> bool:
	if definition == null or fixed:
		return false
	rotation_quarters = posmod(rotation_quarters + 1, 4)
	_refresh_visual()
	return true


# Returns every physical port exposed by the rotated definition.
func get_ports() -> int:
	return definition.get_ports(rotation_quarters) if definition != null else 0


# Returns every rotated port that accepts an incoming signal.
func get_input_ports() -> int:
	return definition.get_input_ports(rotation_quarters) if definition != null else 0


# Returns every rotated port that can emit a downstream signal.
func get_output_ports() -> int:
	return definition.get_output_ports(rotation_quarters) if definition != null else 0


# Updates local power feedback without changing logical topology.
func set_powered(value: bool) -> void:
	powered = value
	if is_node_ready():
		power_glow.visible = definition != null and powered
		_update_outline()


# Raises the pre-authored outline for nearby and selected movable parts.
func set_outline_feedback(strength: float, color: Color) -> void:
	if is_node_ready():
		outline_material.set_shader_parameter("outline_color", color)
		_update_outline(strength)


# Updates the output-adjacent accumulated-time readout.
func set_delay_readout(seconds: float, visible_readout: bool) -> void:
	if not is_node_ready():
		return
	delay_label.visible = visible_readout
	delay_label.text = "%.1fs" % seconds


# Refreshes the authored module texture and ninety-degree orientation.
func _refresh_visual() -> void:
	var has_part := definition != null
	visible = has_part
	if not has_part:
		return
	sprite.texture = definition.visual_texture
	sprite.position = definition.visual_offset
	sprite.scale = definition.visual_scale
	sprite.visible = definition.visual_texture != null
	rotation = 0.0
	sprite.rotation = float(rotation_quarters) * PI * 0.5
	power_glow.visible = powered
	match definition.part_type:
		CircuitPartDefinition.PartType.TIMER:
			delay_label.visible = true
			delay_label.text = "%.0fs" % definition.delay_seconds
		CircuitPartDefinition.PartType.OUTPUT:
			delay_label.visible = true
		_:
			delay_label.visible = false
	_update_port_markers()
	_update_outline()


# Shows the resolved physical openings after the module's ninety-degree rotation.
func _update_port_markers() -> void:
	var ports := get_ports()
	for index in port_markers.size():
		var direction := Vector2.UP.rotated(float(index) * PI * 0.5)
		port_markers[index].position = direction * 38.0
		port_markers[index].rotation = direction.angle() + PI * 0.5
		port_markers[index].visible = (ports & (1 << index)) != 0


# Keeps movable parts faintly readable while focused feedback raises their outline.
func _update_outline(feedback_strength: float = 0.0) -> void:
	var movable := definition != null and not fixed
	var strength := 0.0
	if movable:
		strength = maxf(feedback_strength, 0.56 if powered else 0.3)
	outline_material.set_shader_parameter("outline_strength", strength)
