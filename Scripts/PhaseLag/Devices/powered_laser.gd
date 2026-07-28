class_name PoweredLaser
extends PoweredDevice
## Authored laser hazard whose Area2D is enabled only by its stable power state.

signal target_hit(target: Node)

@export_range(1, 3, 1) var damage: int = 1
@export var guard_break: bool = false

var is_active: bool = false

@onready var damage_area: Area2D = $DamageArea
@onready var collision: CollisionShape2D = $DamageArea/CollisionShape2D
@onready var beam: Polygon2D = $VisualGroup/Beam
@onready var status_light: Polygon2D = $VisualGroup/StatusLight
@onready var activation_audio: AudioStreamPlayer2D = $ActivationAudio


# Connects the authored damage field after registering the shared receiver.
func _ready() -> void:
	super._ready()
	damage_area.body_entered.connect(_on_body_entered)


# Enables collision, monitoring, and visible beam from the stable power state.
func _apply_power_state(value: bool) -> void:
	var was_active := is_active
	is_active = value
	if not is_node_ready():
		return
	collision.set_deferred("disabled", not is_active)
	damage_area.set_deferred("monitoring", is_active)
	beam.visible = is_active
	status_light.color = Color(1.0, 0.28, 0.16, 0.95) if is_active else Color(0.28, 0.38, 0.4, 0.9)
	if is_active and not was_active:
		activation_audio.play()


# Applies the authored laser hit contract only while the field is active.
func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	target_hit.emit(body)
	if body.has_method("take_damage"):
		body.call("take_damage", damage, guard_break)
