class_name PressurePlate
extends EntangledEntity
## Authored weight plate that sends one delayed boolean change per real press transition.

signal pressed_changed(pressed: bool)

@export_range(0.1, 8.0, 0.1) var required_weight: float = 1.0
@export var event_type: StringName = EntanglementBus.POWER_CHANGED
@export var delay_override: float = -1.0

var pressed: bool = false
var _weights: Dictionary[Node, bool] = {}

@onready var detector: Area2D = $Detector
@onready var plate_visual: Sprite2D = $VisualGroup/Plate
@onready var status_light: Polygon2D = $VisualGroup/StatusLight


# Connects authored overlap detection after registering the entangled source.
func _ready() -> void:
	super._ready()
	detector.body_entered.connect(_on_body_entered)
	detector.body_exited.connect(_on_body_exited)
	_update_visual()


# Rechecks tracked bodies because a retained machine can gain weight without re-entering the detector.
func _physics_process(_delta: float) -> void:
	if not _weights.is_empty():
		refresh_weights()


# Changes the plate state and emits one real local event without duplicates.
func set_pressed(value: bool) -> void:
	if pressed == value:
		return
	pressed = value
	_update_visual()
	if not link_id.is_empty():
		send_local_event(event_type, {"value": pressed}, delay_override)
	pressed_changed.emit(pressed)


# Returns the accumulated authored weight currently resting on the plate.
func get_total_weight() -> float:
	var total := 0.0
	for body: Node in _weights.keys():
		if not is_instance_valid(body):
			_weights.erase(body)
			continue
		total += _read_body_weight(body)
	return total


# Recomputes one stable press state from the current weight of every overlapping eligible body.
func refresh_weights() -> void:
	_refresh_from_weights()


# Lets a parasite physically pin this authored plate until it is cleared.
func set_phase_interference(active: bool, mode: StringName = &"press") -> void:
	if mode != &"press":
		return
	if active:
		set_pressed(true)
	else:
		_refresh_from_weights()


# Ignores remote arrivals because this node is a local source, not a remote actuator.
func _apply_remote_event(_event: EntanglementEvent) -> void:
	pass


# Adds one eligible body and reevaluates the real press threshold.
func _on_body_entered(body: Node2D) -> void:
	if not _is_weight_candidate(body):
		return
	_weights[body] = true
	_refresh_from_weights()


# Removes one departed body and reevaluates the real press threshold.
func _on_body_exited(body: Node2D) -> void:
	_weights.erase(body)
	_refresh_from_weights()


# Converts the current body dictionary into one stable pressed state.
func _refresh_from_weights() -> void:
	set_pressed(get_total_weight() >= required_weight)


# Reads explicit corpse or weight contracts while treating players as one unit.
func _read_body_weight(body: Node) -> float:
	if body.has_method("get_pressure_weight"):
		return float(body.call("get_pressure_weight"))
	if body is PhasePlayer:
		return 1.0
	return 1.0 if body.is_in_group("pressure_weights") else 0.0


# Keeps dynamic-weight contracts even when their current weight is temporarily zero.
func _is_weight_candidate(body: Node) -> bool:
	return body.has_method("get_pressure_weight") or body is PhasePlayer or body.is_in_group("pressure_weights")


# Updates the authored plate depth and indicator without spawning UI.
func _update_visual() -> void:
	if not is_node_ready():
		return
	plate_visual.position.y = 2.0 if pressed else 0.0
	status_light.color = Color(0.35, 1.0, 0.7, 0.92) if pressed else Color(0.32, 0.4, 0.42, 0.9)
