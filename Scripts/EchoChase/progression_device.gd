class_name ProgressionDevice
extends Node2D
## Authored branch device that persists one stable world-progress ID.

signal activated(device_id: StringName)

@export var device_id: StringName

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var activation_audio: AudioStreamPlayer2D = %ActivationAudio

var _active := false


# Restores the authored device from slot progress without replaying feedback.
func _ready() -> void:
	if device_id.is_empty():
		push_error("ProgressionDevice requires a non-empty device_id")
		return
	if LevelModule.instance == null:
		push_error("ProgressionDevice requires LevelModule")
		return
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	_set_active(LevelModule.instance.is_progression_device_active(String(device_id)), false)


# Permanently activates this device and saves the current slot once.
func activate() -> bool:
	if _active:
		return false
	if device_id.is_empty() or LevelModule.instance == null:
		push_error("ProgressionDevice.activate requires a valid device_id and LevelModule")
		return false
	if not LevelModule.instance.activate_progression_device(String(device_id)):
		return false
	_set_active(true, true)
	if not SaveSystem.save_slot(1):
		push_error("ProgressionDevice.activate failed to save slot 1")
	activated.emit(device_id)
	return true


# Reports the stable authored activation state.
func is_active() -> bool:
	return _active


# Applies authored idle/active visuals and optional one-shot feedback.
func _set_active(value: bool, play_feedback: bool) -> void:
	_active = value
	animation_player.play(&"active_reduced" if value and _uses_low_flash_mode() else &"active" if value else &"inactive")
	if play_feedback:
		activation_audio.play()


# Keeps active feedback readable when low-flash mode changes at runtime.
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "low_flash_mode" and _active:
		_set_active(true, false)


# Reads the shared accessibility setting for authored animation selection.
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
