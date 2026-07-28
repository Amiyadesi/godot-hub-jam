class_name EntangledDestructionReceiver
extends EntangledEntity
## Applies one remote destroyed event to an authored target without emitting feedback.

signal destruction_arrived(event: EntanglementEvent)

@export var target_path: NodePath
@export var target_method: StringName = &"apply_remote_destruction"

var _target: Node


# Resolves the authored target after registering this delayed receiver.
func _ready() -> void:
	super._ready()
	if target_path.is_empty():
		return
	_target = get_node(target_path)
	if not _target.has_method(target_method):
		push_error("EntangledDestructionReceiver target lacks method '%s'" % target_method)


# Accepts only a true destroyed arrival and delegates its visible result locally.
func _apply_remote_event(event: EntanglementEvent) -> void:
	if event.event_type != EntanglementBus.DESTROYED or not bool(event.payload.get("value", true)):
		return
	if _target != null:
		_target.call(target_method, event)
	destruction_arrived.emit(event)
