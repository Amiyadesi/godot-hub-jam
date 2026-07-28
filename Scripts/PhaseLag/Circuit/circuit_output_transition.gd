class_name CircuitOutputTransition
extends RefCounted
## One scheduled output edge inside a single circuit run.

var output_id: StringName = &""
var value: bool = false
var at_time: float = 0.0
var send_time: float = 0.0
var transfer_delay: float = 0.0
var link_id: StringName = &""
var event_type: StringName = EntanglementBus.POWER_CHANGED


# Creates one target-time edge and its source dispatch timing.
func _init(
		new_output_id: StringName = &"",
		new_value: bool = false,
		new_at_time: float = 0.0,
		new_send_time: float = 0.0,
		new_transfer_delay: float = 0.0,
		new_link_id: StringName = &"",
		new_event_type: StringName = EntanglementBus.POWER_CHANGED
	) -> void:
	output_id = new_output_id
	value = new_value
	at_time = maxf(new_at_time, 0.0)
	send_time = maxf(new_send_time, 0.0)
	transfer_delay = maxf(new_transfer_delay, 0.0)
	link_id = new_link_id
	event_type = new_event_type


# Creates an isolated transition copy for deterministic inspection.
func copy() -> Variant:
	return get_script().new(output_id, value, at_time, send_time, transfer_delay, link_id, event_type)
