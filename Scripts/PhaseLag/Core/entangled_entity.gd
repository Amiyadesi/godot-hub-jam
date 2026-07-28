class_name EntangledEntity
extends Node2D
## Base contract for authored objects that receive delayed remote state.

signal remote_event_applied(event: EntanglementEvent)
signal local_event_sent(event: EntanglementEvent)

enum Side {
	LU_HENG,
	XING_YAO,
}

@export var link_id: StringName = &""
@export_enum("陆衡", "星遥") var side: int = Side.LU_HENG
@export var remote_arrival_vfx_path: NodePath

var _applying_remote: bool = false
var _remote_arrival_vfx: RemoteArrivalVfx


# Registers the authored link when the entity enters the active timeline.
func _ready() -> void:
	EntanglementBus.register_entity(self)
	if remote_arrival_vfx_path.is_empty():
		return
	_remote_arrival_vfx = get_node(remote_arrival_vfx_path) as RemoteArrivalVfx
	if _remote_arrival_vfx == null:
		push_error("%s requires a RemoteArrivalVfx at '%s'" % [name, remote_arrival_vfx_path])
		return
	EntanglementBus.event_queued.connect(_on_entanglement_event_queued)
	EntanglementBus.event_cancelled.connect(_on_entanglement_event_cancelled)
	EntanglementBus.queue_reset.connect(_on_entanglement_queue_reset)


# Removes the entity from the global registry before it leaves the timeline.
func _exit_tree() -> void:
	EntanglementBus.unregister_entity(self)


# Changes a reusable authored entity to another chapter-specific link.
func configure_link(new_link_id: StringName) -> void:
	var previous_link := link_id
	if is_inside_tree():
		EntanglementBus.unregister_entity(self, previous_link)
	if _remote_arrival_vfx != null:
		_remote_arrival_vfx.clear_events()
	link_id = new_link_id
	if is_inside_tree():
		EntanglementBus.register_entity(self)


# Emits a local state change unless this call is part of remote application.
func send_local_event(
		event_type: StringName,
		payload: Dictionary = {},
		delay_override: float = -1.0
	) -> EntanglementEvent:
	if _applying_remote:
		return null
	var event: EntanglementEvent = EntanglementBus.emit_event(
		link_id,
		event_type,
		payload,
		side,
		delay_override
	)
	if event != null:
		local_event_sent.emit(event)
	return event


# Applies one remote event without allowing it to echo back into the bus.
func apply_remote_event(event: EntanglementEvent) -> void:
	_applying_remote = true
	_apply_remote_event(event)
	_applying_remote = false
	if _remote_arrival_vfx != null:
		_remote_arrival_vfx.complete_event(event)
	remote_event_applied.emit(event)


# Fails loudly when a concrete entangled entity omits its remote behavior.
func _apply_remote_event(event: EntanglementEvent) -> void:
	push_error("%s must implement _apply_remote_event for '%s'" % [name, event.event_type])


# Starts target-local arrival feedback for matching events sent from the other space.
func _on_entanglement_event_queued(event: EntanglementEvent) -> void:
	if event.link_id == link_id and event.target_side() == side:
		_remote_arrival_vfx.enqueue_event(event)


# Removes target feedback when its owning circuit attempt is cancelled.
func _on_entanglement_event_cancelled(event: EntanglementEvent) -> void:
	if event.link_id == link_id and event.target_side() == side:
		_remote_arrival_vfx.cancel_event(event)


# Clears target-local feedback whenever the active timeline is reset.
func _on_entanglement_queue_reset() -> void:
	_remote_arrival_vfx.clear_events()
