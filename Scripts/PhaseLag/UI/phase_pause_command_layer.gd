class_name PhasePauseCommandLayer
extends CanvasLayer
## Dedicated pause command above the HUD and below every blocking modal.

signal pause_requested

@onready var pause_button: Button = %PauseButton


# Connects the single authored command and starts unavailable until gameplay binds it.
func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	set_available(false)


# Exposes or removes the pointer and keyboard pause command as one state change.
func set_available(value: bool) -> void:
	pause_button.visible = value
	pause_button.disabled = not value
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	pause_button.focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE


# Emits only while unobstructed gameplay explicitly keeps this command available.
func _on_pause_pressed() -> void:
	if pause_button.disabled:
		return
	pause_requested.emit()
