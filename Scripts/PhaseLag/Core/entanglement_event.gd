class_name EntanglementEvent
extends Resource
## One deterministic world-state transfer between the two entangled spaces.

@export var link_id: StringName = &""
@export var event_type: StringName = &""
@export var payload: Dictionary = {}
@export var source_side: int = 0
@export var sent_time: float = 0.0
@export var arrival_time: float = 0.0
@export var sequence: int = 0
@export var run_id: StringName = &""


# Returns the side that must receive this cross-space event.
func target_side() -> int:
	return 1 - source_side


# Creates an isolated copy for UI and test inspection.
func copy() -> EntanglementEvent:
	var result := EntanglementEvent.new()
	result.link_id = link_id
	result.event_type = event_type
	result.payload = payload.duplicate(true)
	result.source_side = source_side
	result.sent_time = sent_time
	result.arrival_time = arrival_time
	result.sequence = sequence
	result.run_id = run_id
	return result
