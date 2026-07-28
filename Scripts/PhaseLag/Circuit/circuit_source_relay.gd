class_name CircuitSourceRelay
extends EntangledEntity
## Authored bridge from one local or delayed room signal into a named pipeline generator.

signal event_count_changed(count: int, required_count: int)

@export var pipeline_path: NodePath
@export var source_id: StringName = &""
@export var accepted_event_type: StringName = EntanglementBus.POWER_CHANGED
@export var starts_active: bool = false
@export var invert_value: bool = false
@export_range(0.0, 3.0, 0.05, "suffix:s") var pulse_seconds: float = 0.0
@export_range(1, 16, 1) var required_event_count: int = 1
@export var trigger_pipeline_on_threshold: bool = false

var _received_event_count: int = 0
var _threshold_emitted: bool = false

@onready var pipeline: PhaseCausalPipeline = get_node(pipeline_path) as PhaseCausalPipeline
@onready var pulse_timer: Timer = $PulseTimer


# Registers the remote link and applies the authored stable source state to its sibling pipeline.
func _ready() -> void:
	super._ready()
	if pipeline == null or source_id.is_empty():
		push_error("CircuitSourceRelay requires a PhaseCausalPipeline path and non-empty source id")
		return
	if required_event_count > 1 and pulse_seconds <= 0.0:
		push_error("CircuitSourceRelay event counters require an authored pulse_seconds value")
		return
	pulse_timer.timeout.connect(_on_pulse_timeout)
	EntanglementBus.queue_reset.connect(_on_queue_reset)
	pipeline.set_external_source(source_id, starts_active)


# Accepts a directly connected authored signal such as a local pressure plate or socket.
func set_local_value(value: bool) -> void:
	_set_source(value)


# Converts the selected remote event family into one boolean source transition.
func _apply_remote_event(event: EntanglementEvent) -> void:
	if event.event_type != accepted_event_type:
		return
	var default_value := event.event_type != EntanglementBus.POWER_CHANGED
	var value := bool(event.payload.get("value", default_value))
	if required_event_count <= 1:
		event_count_changed.emit(1 if value else 0, required_event_count)
		_set_source(value)
		return
	if not value or _threshold_emitted:
		return
	_received_event_count += 1
	event_count_changed.emit(_received_event_count, required_event_count)
	if _received_event_count < required_event_count:
		return
	_threshold_emitted = true
	_set_source(true)
	if trigger_pipeline_on_threshold:
		pipeline.start_run()


# Applies one source value and turns nonzero pulse inputs back off through an authored Timer.
func _set_source(value: bool) -> void:
	if pipeline == null:
		return
	var source_value := not value if invert_value else value
	pipeline.set_external_source(source_id, source_value)
	if pulse_seconds <= 0.0:
		return
	if source_value:
		pulse_timer.start(pulse_seconds)
	else:
		pulse_timer.stop()


# Ends one temporary source pulse while allowing a memory part to keep its own latched state.
func _on_pulse_timeout() -> void:
	if pipeline != null:
		pipeline.set_external_source(source_id, false)


# Clears counted remote events when the authored room timeline is reset.
func _on_queue_reset() -> void:
	_received_event_count = 0
	_threshold_emitted = false
	event_count_changed.emit(0, required_event_count)
