class_name GameMode
extends Node
## Owns one save-locked play mode and local-coop controller recovery.

signal mode_changed(mode: Mode)
signal active_side_changed(side: int)
signal player_two_waiting
signal player_two_connected(device: int)
signal player_two_disconnected(device: int)

enum Mode {
	SOLO,
	LOCAL_COOP,
}

const P2_ACTIONS: Array[StringName] = [
	&"p2_left",
	&"p2_right",
	&"p2_jump",
	&"p2_down",
	&"p2_primary",
	&"p2_secondary",
	&"p2_dodge",
]

var mode: Mode = Mode.SOLO
var active_side: int = EntangledEntity.Side.LU_HENG
var player_two_device: int = -1
var input_locked: bool = false
var solo_switch_locked: bool = false


# Starts device hot-plug monitoring without changing the save-authored mode.
func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


# Handles only solo role switching because play mode cannot change in-game.
func _input(event: InputEvent) -> void:
	if not input_locked and mode == Mode.SOLO and event.is_action_pressed("solo_switch"):
		switch_active_side()
		get_viewport().set_input_as_handled()


# Applies the save-authored mode once when a chapter scene starts.
func configure(play_mode: StringName) -> void:
	solo_switch_locked = false
	var next_mode := Mode.LOCAL_COOP if play_mode == LevelModule.PLAY_MODE_LOCAL_COOP else Mode.SOLO
	if mode != next_mode:
		mode = next_mode
		mode_changed.emit(mode)
	if mode == Mode.SOLO:
		player_two_device = -1
		return
	if not _claim_connected_player_two():
		player_two_waiting.emit()


# Hands P1 control to the opposite entangled role in solo mode.
func switch_active_side() -> void:
	if input_locked or solo_switch_locked or mode != Mode.SOLO:
		return
	active_side = 1 - active_side
	active_side_changed.emit(active_side)


# Locks solo role switching after one side leaves until the next room starts.
func lock_role_switch_until_room_change() -> void:
	solo_switch_locked = true


# Restores solo role switching after an authored room reset or transition.
func unlock_role_switch() -> void:
	solo_switch_locked = false


# Locks player-authored mode input while failure recovery owns the timeline.
func set_input_locked(value: bool) -> void:
	input_locked = value


# Hands solo ownership to one explicit authored side without toggling twice.
func set_active_side(value: int) -> void:
	if mode != Mode.SOLO or value < 0 or value > 1 or active_side == value:
		return
	active_side = value
	active_side_changed.emit(active_side)


# Reports whether fixed P2 ownership currently has a live controller.
func is_player_two_ready() -> bool:
	return mode != Mode.LOCAL_COOP or player_two_device >= 0


# Claims the first connected controller for P2 and rewrites authored joypad bindings.
func _claim_connected_player_two() -> bool:
	var devices := Input.get_connected_joypads()
	devices.sort()
	for device: int in devices:
		if device == 0:
			continue
		player_two_device = device
		_set_player_two_device(player_two_device)
		return true
	return false


# Retargets every authored P2 joypad event to the connected device.
func _set_player_two_device(device: int) -> void:
	for action: StringName in P2_ACTIONS:
		var events := InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		for event: InputEvent in events:
			var mapped_event := event.duplicate() as InputEvent
			if mapped_event is InputEventJoypadButton or mapped_event is InputEventJoypadMotion:
				mapped_event.device = device
			InputMap.action_add_event(action, mapped_event)


# Pauses fixed local co-op on disconnect and auto-claims the next controller.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if mode != Mode.LOCAL_COOP:
		return
	if connected and player_two_device < 0:
		if _claim_connected_player_two():
			player_two_connected.emit(player_two_device)
		return
	if connected or device != player_two_device:
		return
	player_two_device = -1
	player_two_disconnected.emit(device)
	if _claim_connected_player_two():
		player_two_connected.emit(player_two_device)
