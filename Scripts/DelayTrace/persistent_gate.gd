class_name PersistentGate
extends StaticBody2D
## Authored gate that opens while its progression device is active in slot progress.

@export var required_device_id: StringName

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var open_audio: AudioStreamPlayer2D = %OpenAudio

var _open := false


# Restores the gate from slot progress and listens only for its required device ID.
func _ready() -> void:
	if required_device_id.is_empty():
		push_error("PersistentGate requires a non-empty required_device_id")
		return
	if LevelModule.instance == null:
		push_error("PersistentGate requires LevelModule")
		return
	LevelModule.instance.progression_device_activated.connect(_on_progression_device_activated)
	_set_open(LevelModule.instance.is_progression_device_active(String(required_device_id)), false)


# Reports whether this persistent obstacle no longer blocks the world.
func is_open() -> bool:
	return _open


# Opens when the matching device activates during the current scene.
func _on_progression_device_activated(device_id: String) -> void:
	if device_id == String(required_device_id):
		_set_open(true, true)


# Applies collision and authored visual state without adding puzzle logic.
func _set_open(value: bool, play_feedback: bool) -> void:
	if _open == value and animation_player.current_animation != "":
		return
	_open = value
	collision_shape.set_deferred("disabled", value)
	animation_player.play(&"open" if value else &"closed")
	if value and not play_feedback:
		animation_player.seek(animation_player.current_animation_length, true)
	if value and play_feedback:
		open_audio.play()
