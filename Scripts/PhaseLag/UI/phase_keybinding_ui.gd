class_name PhaseKeybindingUI
extends VBoxContainer
## Fixed authored action rows sharing one add-or-replace capture dialog.

@onready var rows: VBoxContainer = %Rows
@onready var reset_button: Button = %ResetBindingsButton
@onready var capture_dialog: KeyCaptureDialog = %KeyCaptureDialog

var _capture_row: PhaseKeybindingRow
var _capture_event_index: int = -1
var _last_focused_row: PhaseKeybindingRow


# Connects fixed rows, capture flow, removal, and binding broadcasts.
func _ready() -> void:
	for child: Node in rows.get_children():
		var row := child as PhaseKeybindingRow
		if row == null:
			push_error("PhaseKeybindingUI Rows may contain only PhaseKeybindingRow scenes")
			continue
		row.capture_requested.connect(_on_capture_requested)
		row.remove_requested.connect(_on_remove_requested)
		row.binding_focused.connect(_on_row_focused)
	reset_button.pressed.connect(_on_reset_pressed)
	reset_button.mouse_entered.connect(reset_button.grab_focus)
	capture_dialog.key_captured.connect(_on_key_captured)
	capture_dialog.capture_cancelled.connect(_on_capture_cancelled)
	if KeybindingModule.instance != null:
		KeybindingModule.instance.bindings_changed.connect(refresh_all)
	refresh_all()


# Refreshes every authored row after load, reset, add, replace, or removal.
func refresh_all() -> void:
	for child: Node in rows.get_children():
		var row := child as PhaseKeybindingRow
		if row != null:
			row.refresh()


# Focuses the first action row when the controls page opens.
func focus_first_row() -> void:
	if rows.get_child_count() == 0:
		return
	var first_row := rows.get_child(0) as PhaseKeybindingRow
	first_row.grab_binding_focus()


# Opens capture for either a new event or one exact existing event index.
func _on_capture_requested(
	row: PhaseKeybindingRow,
	action: String,
	display_name: String,
	event_index: int
) -> void:
	_capture_row = row
	_capture_event_index = event_index
	var allow_mouse_buttons := not _is_player_gameplay_action(action)
	capture_dialog.open_for(action, display_name, allow_mouse_buttons)


# Applies one accepted event while silently ignoring same-action duplicates.
func _on_key_captured(event: InputEvent, action: String) -> void:
	if KeybindingModule.instance == null:
		push_error("PhaseKeybindingUI requires KeybindingModule")
		return
	if KeybindingModule.instance.has_action_event(action, event):
		_restore_capture_row_focus()
		return
	if _capture_event_index < 0:
		KeybindingModule.instance.add_action_event(action, event)
	else:
		KeybindingModule.instance.rebind_action_event(action, _capture_event_index, event)
	SaveSystem.save_global()
	refresh_all()
	_restore_capture_row_focus()


# Removes one binding and persists the complete remaining event array.
func _on_remove_requested(row: PhaseKeybindingRow, action: String, event_index: int) -> void:
	if KeybindingModule.instance == null:
		push_error("PhaseKeybindingUI requires KeybindingModule")
		return
	KeybindingModule.instance.remove_action_event(action, event_index)
	SaveSystem.save_global()
	refresh_all()
	row.grab_binding_focus()


# Restores the originating row when capture closes without changes.
func _on_capture_cancelled(_action: String) -> void:
	_restore_capture_row_focus()


# Restores project bindings and returns focus to the active action row.
func _on_reset_pressed() -> void:
	if KeybindingModule.instance == null:
		push_error("PhaseKeybindingUI requires KeybindingModule")
		return
	KeybindingModule.instance.reset_to_defaults()
	SaveSystem.save_global()
	refresh_all()
	if _last_focused_row != null and is_instance_valid(_last_focused_row):
		_last_focused_row.grab_binding_focus()
	else:
		focus_first_row()


# Tracks the last row selected through pointer, keyboard, or controller.
func _on_row_focused(row: PhaseKeybindingRow) -> void:
	if capture_dialog.visible:
		return
	_last_focused_row = row


# Returns whether one action controls a player and must reject mouse buttons.
func _is_player_gameplay_action(action: String) -> bool:
	return action.begins_with("p1_") or action.begins_with("p2_") or action == "solo_switch"


# Clears capture state only after focus returns to the originating row.
func _restore_capture_row_focus() -> void:
	var row := _capture_row
	_capture_row = null
	_capture_event_index = -1
	if row != null and is_instance_valid(row):
		row.grab_binding_focus()
