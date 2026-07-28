class_name PoweredPlatform
extends PoweredDevice
## Authored moving platform whose AnimatableBody2D follows delayed power state.

@export var powered_offset: Vector2 = Vector2(0.0, -160.0)
@export_range(1.0, 800.0, 1.0, "suffix:px/s") var travel_speed: float = 180.0

var _target_position: Vector2 = Vector2.ZERO

@onready var platform_body: AnimatableBody2D = $PlatformBody
@onready var status_light: Polygon2D = $PlatformBody/VisualGroup/StatusLight


# Captures the authored unpowered origin after the shared receiver is registered.
func _ready() -> void:
	_target_position = powered_offset if starts_powered else Vector2.ZERO
	super._ready()


# Advances the authored platform body without changing the root receiver position.
func _physics_process(delta: float) -> void:
	advance_motion(delta)


# Moves toward the selected stable endpoint and supports deterministic headless tests.
func advance_motion(delta: float) -> void:
	if delta <= 0.0 or platform_body == null:
		return
	platform_body.position = platform_body.position.move_toward(_target_position, travel_speed * delta)


# Selects the powered or unpowered authored endpoint.
func _apply_power_state(value: bool) -> void:
	_target_position = powered_offset if value else Vector2.ZERO
	if is_node_ready():
		status_light.color = Color(0.34, 1.0, 0.76, 0.92) if value else Color(0.32, 0.42, 0.46, 0.9)


# Reports whether the moving body has reached its current powered endpoint.
func is_at_powered_position() -> bool:
	return platform_body != null and platform_body.position.is_equal_approx(powered_offset)


# Restores a clean checkpoint directly at its already-arrived stable endpoint.
func restore_persistent_state(state: Dictionary) -> void:
	super.restore_persistent_state(state)
	if platform_body != null:
		platform_body.position = _target_position
