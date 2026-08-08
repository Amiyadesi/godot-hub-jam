class_name DelayTraceOnboarding
extends Node
## Arms the authored world-space control cue for a fresh run.

@export var player: EchoPlayer
@export var floating_text: Node2D
@export var floating_text2: Node2D
@export var floating_text3: Node2D

var _jump_hint_pending := false
var _dash_hint_pending := false
var _drop_hint_pending := false


# Connects the three Area2D triggers and keeps prompts dormant until armed.
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

	# Connect Area2D signals for each floating text
	var area1 := floating_text.get_node_or_null("Area2D") as Area2D
	var area2 := floating_text2.get_node_or_null("Area2D") as Area2D
	var area3 := floating_text3.get_node_or_null("Area2D") as Area2D

	if area1 != null:
		area1.body_entered.connect(_on_float_text1_body_entered)
	if area2 != null:
		area2.body_entered.connect(_on_float_text2_body_entered)
	if area3 != null:
		area3.body_entered.connect(_on_float_text3_body_entered)


# Arms the three proximity-triggered prompts for a fresh run only.
func start() -> void:
	_jump_hint_pending = true
	_dash_hint_pending = true
	_drop_hint_pending = true


# Triggered when player enters the first hint area.
func _on_float_text1_body_entered(body: Node2D) -> void:
	if _jump_hint_pending and body == player:
		_jump_hint_pending = false
		floating_text.call(&"start", _build_jump_prompt_text())


# Triggered when player enters the second hint area.
func _on_float_text2_body_entered(body: Node2D) -> void:
	if _dash_hint_pending and body == player:
		_dash_hint_pending = false
		floating_text2.call(&"start", _build_dash_prompt_text())


# Triggered when player enters the third hint area.
func _on_float_text3_body_entered(body: Node2D) -> void:
	if _drop_hint_pending and body == player:
		_drop_hint_pending = false
		floating_text3.call(&"start", _build_drop_prompt_text())


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
