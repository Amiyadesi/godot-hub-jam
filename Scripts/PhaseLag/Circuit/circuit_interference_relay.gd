class_name CircuitInterferenceRelay
extends EntangledEntity
## Authored delayed link that clears or reapplies one named parasite override on a pipeline.

@export var pipeline_path: NodePath
@export var interference_source_id: StringName = &""
@export var interference_mode: StringName = &"cut"
@export var accepted_event_type: StringName = EntanglementBus.DESTROYED
@export var starts_active: bool = true
@export var truthy_event_clears: bool = true

@onready var pipeline: PhaseCausalPipeline = get_node(pipeline_path) as PhaseCausalPipeline


# Registers the delayed link and applies the parasite's authored opening interference state.
func _ready() -> void:
	super._ready()
	if pipeline == null or interference_source_id.is_empty():
		push_error("CircuitInterferenceRelay requires a PhaseCausalPipeline path and non-empty source id")
		return
	pipeline.set_phase_interference_source(interference_source_id, starts_active, interference_mode)


# Converts an arriving parasite state into one deterministic named pipeline override.
func _apply_remote_event(event: EntanglementEvent) -> void:
	if event.event_type != accepted_event_type or pipeline == null:
		return
	var event_value := bool(event.payload.get("value", true))
	var active := not event_value if truthy_event_clears else event_value
	pipeline.set_phase_interference_source(interference_source_id, active, interference_mode)


# Allows authored local encounters to drive the same named source without emitting another event.
func set_local_active(active: bool) -> void:
	if pipeline != null:
		pipeline.set_phase_interference_source(interference_source_id, active, interference_mode)
