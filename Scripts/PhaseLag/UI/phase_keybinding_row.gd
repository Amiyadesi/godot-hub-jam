class_name PhaseKeybindingRow
extends PanelContainer
## One authored action row that displays every current input binding.

signal capture_requested(
	row: PhaseKeybindingRow,
	action: String,
	display_name: String,
	event_index: int
)
signal remove_requested(row: PhaseKeybindingRow, action: String, event_index: int)
signal binding_focused(row: PhaseKeybindingRow)

const BINDING_CHIP_SCENE := preload("res://Scenes/PhaseLag/UI/phase_binding_chip.tscn")

@export var action: String = ""
@export var display_name: String = ""

@onready var action_label: Label = %ActionLabel
@onready var bindings_flow: HFlowContainer = %BindingsFlow
@onready var add_button: Button = %AddButton
@onready var hover_frame: Panel = %HoverFrame
@onready var focus_frame: Panel = %FocusFrame
@onready var focus_accent: ColorRect = %FocusAccent

var _binding_chips: Array[PhaseBindingChip] = []
var _hovered: bool = false
var _last_focus_control: Control


# Connects the authored row and renders all configured InputMap events.
func _ready() -> void:
	if action.is_empty():
		push_error("PhaseKeybindingRow requires an authored action")
	action_label.text = display_name if not display_name.is_empty() else action
	add_button.pressed.connect(_on_add_pressed)
	add_button.focus_entered.connect(_on_control_focused.bind(add_button))
	add_button.focus_exited.connect(_on_control_focus_released)
	add_button.mouse_entered.connect(_focus_add_button)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	refresh()


# Rebuilds authored binding-chip instances from the current event array.
func refresh() -> void:
	_clear_binding_chips()
	if KeybindingModule.instance == null:
		return
	var events := KeybindingModule.instance.get_action_events(action)
	for index in events.size():
		_add_binding_chip(index, ResourceSerializer.event_to_display_string(events[index]))
	add_button.text = "+" if not events.is_empty() else "+ 添加绑定"
	add_button.custom_minimum_size.x = 44.0 if not events.is_empty() else 132.0


# Focuses the first binding, or the add command when this action is empty.
func grab_binding_focus() -> void:
	if not _binding_chips.is_empty():
		_binding_chips[0].grab_primary_focus()
	else:
		add_button.grab_focus()
	_ensure_visible()


# Removes prior chip instances before a complete row refresh.
func _clear_binding_chips() -> void:
	for chip: PhaseBindingChip in _binding_chips:
		bindings_flow.remove_child(chip)
		chip.queue_free()
	_binding_chips.clear()


# Adds one authored chip before the fixed add command.
func _add_binding_chip(index: int, text: String) -> void:
	var chip := BINDING_CHIP_SCENE.instantiate() as PhaseBindingChip
	bindings_flow.add_child(chip)
	bindings_flow.move_child(chip, add_button.get_index())
	chip.setup(index, text)
	chip.replace_requested.connect(_on_replace_requested)
	chip.remove_requested.connect(_on_remove_requested)
	chip.focus_requested.connect(_on_control_focused)
	chip.focus_released.connect(_on_control_focus_released)
	_binding_chips.append(chip)


# Moves GUI focus into this row as soon as the pointer enters it.
func _set_hovered(value: bool) -> void:
	_hovered = value
	if value and not _owns_gui_focus():
		if _last_focus_control != null and is_instance_valid(_last_focus_control):
			_last_focus_control.grab_focus()
		else:
			grab_binding_focus()
	hover_frame.visible = value and not _owns_gui_focus()


# Records one focused child and displays the row-level selection frame.
func _on_control_focused(control: Control) -> void:
	_last_focus_control = control
	focus_frame.visible = true
	focus_accent.visible = true
	hover_frame.visible = false
	binding_focused.emit(self)
	_ensure_visible()


# Defers focus cleanup until Godot has assigned the next owner.
func _on_control_focus_released() -> void:
	call_deferred("_sync_focus_state")


# Keeps the row frame visible only while one of its descendants owns focus.
func _sync_focus_state() -> void:
	var focused := _owns_gui_focus()
	focus_frame.visible = focused
	focus_accent.visible = focused
	hover_frame.visible = _hovered and not focused


# Returns whether current GUI focus belongs to this action row.
func _owns_gui_focus() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	while focus_owner != null:
		if focus_owner == self:
			return true
		focus_owner = focus_owner.get_parent() as Control
	return false


# Focuses the fixed add command when directly hovered.
func _focus_add_button() -> void:
	add_button.grab_focus()


# Requests capture for a new binding entry.
func _on_add_pressed() -> void:
	capture_requested.emit(self, action, display_name, -1)


# Requests capture for one existing event index.
func _on_replace_requested(event_index: int) -> void:
	capture_requested.emit(self, action, display_name, event_index)


# Requests removal of one exact event index.
func _on_remove_requested(event_index: int) -> void:
	remove_requested.emit(self, action, event_index)


# Requests the nearest authored ScrollContainer to reveal this row.
func _ensure_visible() -> void:
	var ancestor: Node = get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	var scroll_container := ancestor as ScrollContainer
	if scroll_container != null:
		scroll_container.ensure_control_visible(self)
