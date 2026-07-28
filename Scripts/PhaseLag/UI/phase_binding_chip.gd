class_name PhaseBindingChip
extends HBoxContainer
## One authored binding chip with replace and remove commands.

signal replace_requested(index: int)
signal remove_requested(index: int)
signal focus_requested(control: Control)
signal focus_released

@onready var binding_button: Button = %BindingButton
@onready var remove_button: Button = %RemoveButton

var event_index: int = -1


# Configures one visible binding without changing authored layout or styles.
func setup(index: int, display_text: String) -> void:
	event_index = index
	binding_button.text = display_text
	binding_button.tooltip_text = "替换绑定：%s" % display_text


# Wires chip commands and pointer-driven focus.
func _ready() -> void:
	binding_button.pressed.connect(_on_replace_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	binding_button.focus_entered.connect(_emit_focus.bind(binding_button))
	remove_button.focus_entered.connect(_emit_focus.bind(remove_button))
	binding_button.focus_exited.connect(_emit_focus_released)
	remove_button.focus_exited.connect(_emit_focus_released)
	mouse_entered.connect(_focus_binding_button)
	binding_button.mouse_entered.connect(_focus_binding_button)
	remove_button.mouse_entered.connect(_focus_remove_button)


# Gives keyboard focus to the binding command when the pointer enters the chip.
func _focus_binding_button() -> void:
	binding_button.grab_focus()


# Gives keyboard focus to remove when the pointer targets that icon.
func _focus_remove_button() -> void:
	remove_button.grab_focus()


# Restores focus to the chip's primary replace command.
func grab_primary_focus() -> void:
	binding_button.grab_focus()


# Reports the focused child so the owning row can draw one selection frame.
func _emit_focus(control: Control) -> void:
	focus_requested.emit(control)


# Lets the row defer one stable focus-owner check after navigation.
func _emit_focus_released() -> void:
	focus_released.emit()


# Requests replacement of this exact binding index.
func _on_replace_pressed() -> void:
	replace_requested.emit(event_index)


# Requests removal of this exact binding index.
func _on_remove_pressed() -> void:
	remove_requested.emit(event_index)
