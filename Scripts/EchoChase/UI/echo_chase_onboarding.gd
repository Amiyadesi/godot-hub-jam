class_name EchoChaseOnboarding
extends CanvasLayer
## Shows remap-aware opening controls until the player performs each action.

@export var player: EchoPlayer

@onready var move_prompt: Label = %MovePrompt
@onready var jump_prompt: Label = %JumpPrompt
@onready var dash_prompt: Label = %DashPrompt

var _active := false
var _move_done := false
var _jump_done := false
var _dash_done := false


# Connects actual player actions and keeps the authored labels hidden until a new run starts.
func _ready() -> void:
	if player == null:
		push_error("EchoChaseOnboarding requires an authored player reference")
		return
	player.jump_started.connect(_on_jump_started)
	player.dash_started.connect(_on_dash_started)
	if KeybindingModule.instance != null:
		KeybindingModule.instance.bindings_changed.connect(_refresh_labels)
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	_refresh_labels()
	visible = false
	set_process(false)


# Opens the three compact prompts for a fresh run only.
func start() -> void:
	if player == null:
		return
	_active = true
	_move_done = false
	_jump_done = false
	_dash_done = false
	for prompt in [move_prompt, jump_prompt, dash_prompt]:
		prompt.show()
		_set_alpha(prompt, 1.0)
	_refresh_labels()
	visible = true
	set_process(true)


# Completes movement only after the player actually gains horizontal velocity.
func _process(_delta: float) -> void:
	if _active and not _move_done and absf(player.velocity.x) > 8.0:
		_move_done = true
		_fade_prompt(move_prompt)


# Completes the jump prompt from the player's successful jump signal.
func _on_jump_started() -> void:
	if not _active or _jump_done:
		return
	_jump_done = true
	_fade_prompt(jump_prompt)


# Completes the dash prompt from the player's successful dash signal.
func _on_dash_started(_direction: Vector2) -> void:
	if not _active or _dash_done:
		return
	_dash_done = true
	_fade_prompt(dash_prompt)


# Fades one completed instruction without delaying or blocking gameplay.
func _fade_prompt(prompt: Label) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(prompt, "modulate:a", 0.0, 0.28)
	await tween.finished
	prompt.hide()
	if _move_done and _jump_done and _dash_done:
		_active = false
		visible = false
		set_process(false)


# Rebuilds all prompt text from the current remappable primary bindings.
func _refresh_labels() -> void:
	move_prompt.text = tr("TUTORIAL_MOVE").format({
		"left": _binding_text(&"echo_move_left"),
		"right": _binding_text(&"echo_move_right"),
	})
	jump_prompt.text = tr("TUTORIAL_JUMP").format({"jump": _binding_text(&"echo_jump")})
	dash_prompt.text = tr("TUTORIAL_DASH").format({"dash": _binding_text(&"echo_dash")})


# Returns the same binding label used by the authored controls screen.
func _binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if KeybindingModule.instance != null:
		events = KeybindingModule.instance.get_action_events(String(action))
	if events.is_empty():
		return tr("INPUT_UNBOUND")
	return ResourceSerializer.event_to_display_string(events[0])


# Refreshes visible instructions when the locale changes in settings.
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "language":
		_refresh_labels()


# Changes only opacity while preserving the authored prompt styling.
func _set_alpha(item: CanvasItem, alpha: float) -> void:
	var color := item.modulate
	color.a = alpha
	item.modulate = color
