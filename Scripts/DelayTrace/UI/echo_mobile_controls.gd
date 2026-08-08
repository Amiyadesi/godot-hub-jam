class_name EchoMobileControls
extends Control
## Authored touch controls: analog movement, large action targets, and touchscreen-only presentation.

@export var pause_screen: CanvasItem
@export var setting_screen: CanvasItem
@export var dialogue_npc: DialogueNpc

@onready var move_joystick: VirtualJoystick = %MoveJoystick
@onready var action_pad: Control = %ActionPad
@onready var escape_button: TouchScreenButton = %EscButton
@onready var jump_button: TouchScreenButton = %Y
@onready var dash_button: TouchScreenButton = %X
@onready var interact_button: TouchScreenButton = %B
@onready var recall_button: TouchScreenButton = %A

var _dialogue_active := false
var _last_tree_paused := false


# Validates authored overlay owners and hides this layer on desktop builds.
func _ready() -> void:
	if pause_screen == null or setting_screen == null or dialogue_npc == null:
		push_error("EchoMobileControls requires pause_screen, setting_screen, and dialogue_npc")
		return
	pause_screen.visibility_changed.connect(_refresh_visibility)
	setting_screen.visibility_changed.connect(_refresh_visibility)
	dialogue_npc.dialogue_started_here.connect(_on_dialogue_started)
	dialogue_npc.dialogue_finished.connect(_on_dialogue_finished)
	SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	move_joystick.pressed.connect(_on_touch_control_pressed)
	jump_button.pressed.connect(_on_touch_control_pressed)
	dash_button.pressed.connect(_on_touch_control_pressed)
	interact_button.pressed.connect(_on_touch_control_pressed)
	recall_button.pressed.connect(_on_touch_control_pressed)
	escape_button.pressed.connect(_on_touch_control_pressed)
	_last_tree_paused = get_tree().paused
	_apply_control_settings()
	_refresh_context_actions()
	_refresh_visibility()


# Hides the touch layer as soon as a cinematic or menu pauses the world.
func _process(_delta: float) -> void:
	_refresh_context_actions()
	var tree_paused := get_tree().paused
	if tree_paused == _last_tree_paused:
		return
	_last_tree_paused = tree_paused
	_refresh_visibility()


# Shows contextual actions only while their gameplay systems can consume them.
func _refresh_context_actions() -> void:
	interact_button.visible = dialogue_npc.is_interaction_available()
	recall_button.visible = EchoTimeline.is_future_recording()


# Hides touch controls while authored menus or dialogue own the screen.
func _refresh_visibility() -> void:
	visible = (
		DisplayServer.is_touchscreen_available()
		and not get_tree().paused
		and not pause_screen.visible
		and not setting_screen.visible
		and not _dialogue_active
	)


# Applies saved touch scale, opacity, and haptic preferences to authored nodes.
func _apply_control_settings() -> void:
	var joystick_scale := clampf(
		float(SettingsModule.instance.get_value("mobile_joystick_scale", 1.0)),
		0.8,
		1.4
	)
	move_joystick.scale = Vector2.ONE * joystick_scale
	modulate.a = clampf(
		float(SettingsModule.instance.get_value("mobile_control_opacity", 0.88)),
		0.4,
		1.0
	)


# Reapplies only settings that affect this authored overlay.
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key in [&"mobile_joystick_scale", &"mobile_control_opacity"]:
		_apply_control_settings()


# Gives every touch target one short confirmation pulse when haptics are enabled.
func _on_touch_control_pressed() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	if bool(SettingsModule.instance.get_value("mobile_haptics", true)):
		Input.vibrate_handheld(18, 0.35)


# Removes touch buttons before the dialogue balloon opens.
func _on_dialogue_started() -> void:
	_dialogue_active = true
	_refresh_visibility()


# Restores touch buttons after dialogue returns control to gameplay.
func _on_dialogue_finished() -> void:
	_dialogue_active = false
	_refresh_visibility()
