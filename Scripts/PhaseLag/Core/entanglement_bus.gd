extends Node
## Global deterministic queue for delayed cross-space world-state events.

signal event_queued(event: EntanglementEvent)
signal event_arrived(event: EntanglementEvent)
signal event_cancelled(event: EntanglementEvent)
signal queue_reset
signal delay_changed(seconds: float)

const POWER_CHANGED: StringName = &"power_changed"
const FORM_CHANGED: StringName = &"form_changed"
const DESTROYED: StringName = &"destroyed"
const VALID_EVENT_TYPES: Array[StringName] = [POWER_CHANGED, FORM_CHANGED, DESTROYED]

var base_delay: float = 3.0
var current_time: float = 0.0
var manual_mode: bool = false

var _next_sequence: int = 1
var _queue: Array[EntanglementEvent] = []
var _receivers: Dictionary[StringName, Array] = {}


# Advances the gameplay clock while normal runtime processing is enabled.
func _process(delta: float) -> void:
	if manual_mode:
		return
	advance(delta)


# Registers one authored entity as a possible remote event receiver.
func register_entity(entity: EntangledEntity) -> void:
	if entity.link_id.is_empty():
		return
	var entities: Array = _receivers.get(entity.link_id, [])
	if not entities.has(entity):
		entities.append(entity)
	_receivers[entity.link_id] = entities


# Removes one entity from its current link registry.
func unregister_entity(entity: EntangledEntity, registered_link: StringName = &"") -> void:
	var key: StringName = registered_link if not registered_link.is_empty() else entity.link_id
	if not _receivers.has(key):
		return
	var entities: Array = _receivers[key]
	entities.erase(entity)
	if entities.is_empty():
		_receivers.erase(key)
	else:
		_receivers[key] = entities


# Queues one local state change for the opposite space and returns its event record.
func emit_event(
		link_id: StringName,
		event_type: StringName,
		payload: Dictionary,
		source_side: int,
		delay_override: float = -1.0,
		run_id: StringName = &"",
		sent_time_override: float = -1.0
	) -> EntanglementEvent:
	if link_id.is_empty():
		push_error("EntanglementBus.emit_event: link_id cannot be empty")
		return null
	if not VALID_EVENT_TYPES.has(event_type):
		push_error("EntanglementBus.emit_event: unsupported event type '%s'" % event_type)
		return null
	if source_side < 0 or source_side > 1:
		push_error("EntanglementBus.emit_event: source_side must be 0 or 1")
		return null

	var event := EntanglementEvent.new()
	event.link_id = link_id
	event.event_type = event_type
	event.payload = payload.duplicate(true)
	event.source_side = source_side
	event.sent_time = sent_time_override if sent_time_override >= 0.0 else current_time
	event.arrival_time = event.sent_time + (delay_override if delay_override >= 0.0 else base_delay)
	event.sequence = _next_sequence
	event.run_id = run_id
	_next_sequence += 1
	_queue.append(event)
	_queue.sort_custom(_event_arrives_first)
	event_queued.emit(event)
	return event


# Cancels only the queued events owned by one circuit run.
func cancel_run(run_id: StringName) -> int:
	if run_id.is_empty():
		return 0
	var kept: Array[EntanglementEvent] = []
	var cancelled: Array[EntanglementEvent] = []
	for event: EntanglementEvent in _queue:
		if event.run_id == run_id:
			cancelled.append(event)
		else:
			kept.append(event)
	_queue = kept
	for event: EntanglementEvent in cancelled:
		event_cancelled.emit(event)
	return cancelled.size()


# Advances the deterministic clock and applies every event now due in stable order.
func advance(delta: float) -> void:
	if delta < 0.0:
		push_error("EntanglementBus.advance: delta cannot be negative")
		return
	current_time += delta
	while not _queue.is_empty() and _queue[0].arrival_time <= current_time:
		var event: EntanglementEvent = _queue.pop_front()
		_apply_event(event)


# Replaces the default transfer delay used by future events.
func set_base_delay(seconds: float) -> void:
	base_delay = maxf(seconds, 0.0)
	delay_changed.emit(base_delay)


# Clears transient causality state without touching authored receivers.
func reset_queue(reset_clock: bool = true) -> void:
	_queue.clear()
	_next_sequence = 1
	if reset_clock:
		current_time = 0.0
	queue_reset.emit()


# Clears both transient events and receiver registrations for a fresh timeline.
func reset_all() -> void:
	reset_queue(true)
	_receivers.clear()
	base_delay = 3.0
	delay_changed.emit(base_delay)


# Returns immutable-style event copies for HUD rendering and tests.
func get_pending_events() -> Array[EntanglementEvent]:
	var result: Array[EntanglementEvent] = []
	for event: EntanglementEvent in _queue:
		result.append(event.copy())
	return result


# Returns the countdown until one queued event arrives.
func get_remaining_time(event: EntanglementEvent) -> float:
	return maxf(event.arrival_time - current_time, 0.0)


# Reports the current number of delayed events.
func pending_count() -> int:
	return _queue.size()


# Applies an arriving event only to matching entities in the opposite space.
func _apply_event(event: EntanglementEvent) -> void:
	var entities: Array = _receivers.get(event.link_id, [])
	var live_entities: Array = []
	for entity_value: Variant in entities:
		if not is_instance_valid(entity_value):
			continue
		var entity := entity_value as EntangledEntity
		live_entities.append(entity)
		if entity.side == event.target_side():
			entity.apply_remote_event(event)
	if live_entities.is_empty():
		_receivers.erase(event.link_id)
	else:
		_receivers[event.link_id] = live_entities
	event_arrived.emit(event)


# Orders equal-time events by creation sequence for deterministic replay.
func _event_arrives_first(a: EntanglementEvent, b: EntanglementEvent) -> bool:
	if is_equal_approx(a.arrival_time, b.arrival_time):
		return a.sequence < b.sequence
	return a.arrival_time < b.arrival_time
