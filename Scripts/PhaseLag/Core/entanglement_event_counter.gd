class_name EntanglementEventCounter
extends EntangledEntity
## Counts authored remote events and emits one final room objective at the threshold.

@export var accepted_event_type: StringName = EntanglementBus.DESTROYED
@export_range(1, 16, 1) var required_count: int = 1
@export var completion_link_id: StringName = &""
@export var completion_delay_override: float = 0.0

var _count: int = 0
var _completed: bool = false


# Registers the incoming link and validates the one outgoing completion contract.
func _ready() -> void:
	super._ready()
	if link_id.is_empty() or completion_link_id.is_empty():
		push_error("EntanglementEventCounter requires input and completion link ids")


# Converts the final accepted true event into one completion edge without duplicates.
func _apply_remote_event(event: EntanglementEvent) -> void:
	if _completed or event.event_type != accepted_event_type or not bool(event.payload.get("value", true)):
		return
	_count += 1
	if _count < required_count:
		return
	_completed = true
	EntanglementBus.emit_event(
		completion_link_id,
		EntanglementBus.POWER_CHANGED,
		{"value": true, "count": _count},
		side,
		completion_delay_override
	)
