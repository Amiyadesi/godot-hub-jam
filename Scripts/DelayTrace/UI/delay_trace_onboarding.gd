class_name DelayTraceOnboarding
extends Node
## Arms the authored world-space control cue for a fresh run.

@export var player: EchoPlayer
@export var floating_text: Node2D
@export var floating_text2: Node2D
@export var floating_text3: Node2D
@export_range(32.0, 256.0, 8.0) var trigger_distance := 64.0

var _jump_hint_pending := false
var _dash_hint_pending := false
var _drop_hint_pending := false


# Keeps the authored prompt dormant until the new-run intro completes.
func _ready() -> void:
	if (
		player == null
		or floating_text == null
		or floating_text2 == null
		or floating_text3 == null
		or not floating_text.has_method(&"start")
		or not floating_text2.has_method(&"start")
		or not floating_text3.has_method(&"start")
	):
		push_error("DelayTraceOnboarding requires player and three authored floating texts")
		return
	set_process(false)


# Arms the three proximity-triggered prompts for a fresh run only.
func start() -> void:
	_jump_hint_pending = true
	_dash_hint_pending = true
	_drop_hint_pending = true
	set_process(true)


# Shows each world cue once the player approaches its authored location.
func _process(_delta: float) -> void:
	if _jump_hint_pending and _is_near(floating_text):
		_jump_hint_pending = false
		floating_text.call(&"start", _build_jump_prompt_text())
	if _dash_hint_pending and _is_near(floating_text2):
		_dash_hint_pending = false
		floating_text2.call(&"start", _build_dash_prompt_text())
	if _drop_hint_pending and _is_near(floating_text3):
		_drop_hint_pending = false
		floating_text3.call(&"start", _build_drop_prompt_text())
	if not _jump_hint_pending and not _dash_hint_pending and not _drop_hint_pending:
		set_process(false)


# Checks the authored hint's proximity without changing world coordinates.
func _is_near(hint: Node2D) -> bool:
	return player.global_position.distance_to(hint.global_position) <= trigger_distance


# Builds the jump and wall-climb hint from the current binding.
func _build_jump_prompt_text() -> String:
	return tr("TUTORIAL_JUMP_CLIMB").format({"jump": _binding_text(&"echo_jump", "Y")})


# Builds the dash hint from the current binding.
func _build_dash_prompt_text() -> String:
	return tr("TUTORIAL_DASH").format({"dash": _binding_text(&"echo_dash", "X")})


# Builds the platform drop hint from the current binding.
func _build_drop_prompt_text() -> String:
	return tr("TUTORIAL_DROP").format({"down": _binding_text(&"echo_move_down", "↓")})


# Returns the same binding label used by the authored controls screen.
func _binding_text(action: StringName, touch_label: String) -> String:
	if DisplayServer.is_touchscreen_available():
		return touch_label
	var events := InputMap.action_get_events(action)
	if KeybindingModule.instance != null:
		events = KeybindingModule.instance.get_action_events(String(action))
	if events.is_empty():
		return tr("INPUT_UNBOUND")
	return ResourceSerializer.event_to_display_string(events[0])
