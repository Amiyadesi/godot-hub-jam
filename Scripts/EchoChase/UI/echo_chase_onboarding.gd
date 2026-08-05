class_name EchoChaseOnboarding
extends Node
## Arms the authored world-space control cue for a fresh run.

@export var player: EchoPlayer
@export var floating_text: Node2D
@export_range(32.0, 256.0, 8.0) var trigger_distance := 128.0

var _active := false


# Keeps the authored prompt dormant until the new-run intro completes.
func _ready() -> void:
	if player == null or floating_text == null or not floating_text.has_method(&"start"):
		push_error("EchoChaseOnboarding requires player and floating_text")
		return
	set_process(false)


# Arms one proximity-triggered prompt for a fresh run only.
func start() -> void:
	_active = true
	set_process(true)


# Shows the world cue once the player approaches its authored location.
func _process(_delta: float) -> void:
	if not _active or player.global_position.distance_to(floating_text.global_position) > trigger_distance:
		return
	_active = false
	set_process(false)
	floating_text.call(&"start", _build_prompt_text())


# Builds the two essential actions from the current remappable bindings.
func _build_prompt_text() -> String:
	var dash_binding := "X" if OS.has_feature("mobile") else _binding_text(&"echo_dash")
	var jump_binding := "Y" if OS.has_feature("mobile") else _binding_text(&"echo_jump")
	var dash_text := tr("TUTORIAL_DASH").format({"dash": dash_binding})
	var jump_text := tr("TUTORIAL_JUMP").format({"jump": jump_binding})
	return "%s\n%s" % [dash_text, jump_text]


# Returns the same binding label used by the authored controls screen.
func _binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if KeybindingModule.instance != null:
		events = KeybindingModule.instance.get_action_events(String(action))
	if events.is_empty():
		return tr("INPUT_UNBOUND")
	return ResourceSerializer.event_to_display_string(events[0])
