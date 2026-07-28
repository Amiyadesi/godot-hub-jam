class_name ShieldGenerator
extends PoweredDevice
## Authored shield wall whose collision and field visual follow delayed power.

var shield_active: bool = false

@onready var shield_collision: CollisionShape2D = $ShieldBody/CollisionShape2D
@onready var field: Polygon2D = $VisualGroup/Field
@onready var status_light: Polygon2D = $VisualGroup/StatusLight
@onready var activation_audio: AudioStreamPlayer2D = $ActivationAudio


# Applies blocking collision and stable field visibility from the powered state.
func _apply_power_state(value: bool) -> void:
	var was_active := shield_active
	shield_active = value
	if not is_node_ready():
		return
	shield_collision.set_deferred("disabled", not shield_active)
	field.visible = shield_active
	status_light.color = Color(0.34, 0.92, 1.0, 0.95) if shield_active else Color(0.3, 0.38, 0.42, 0.9)
	if shield_active and not was_active:
		activation_audio.play()
