class_name CircuitLocalDeviceRelay
extends Node2D
## Routes one pipeline output directly to a same-space authored powered device.

@export var pipeline_path: NodePath
@export var output_id: StringName = &""
@export var device_path: NodePath

@onready var pipeline: PhaseCausalPipeline = get_node(pipeline_path) as PhaseCausalPipeline
@onready var device: Node = get_node(device_path)


# Connects one exact pipeline output to one authored local device contract.
func _ready() -> void:
	if pipeline == null or output_id.is_empty() or not device.has_method("set_powered"):
		push_error("CircuitLocalDeviceRelay requires a pipeline, output id, and set_powered device")
		return
	pipeline.output_state_changed.connect(_on_output_state_changed)


# Applies local power immediately while cross-space outputs keep their own bus delay.
func _on_output_state_changed(changed_output_id: StringName, powered: bool, _delay: float, event: EntanglementEvent) -> void:
	if changed_output_id == output_id and event == null:
		device.call("set_powered", powered)
