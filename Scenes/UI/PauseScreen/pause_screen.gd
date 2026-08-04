@tool
class_name PauseScreen
extends SceneManagerBackdrop

signal setting_pressed
signal quit_pressed
signal continue_pressed
signal restart_pressed
signal hint_pressed

@onready var continue_button: ShaderButton = %ContinueButton
@onready var restart_button: ShaderButton = %RestartButton
@onready var hint_button: ShaderButton = %HintButton
@onready var setting_button: ShaderButton = %SettingButton
@onready var quit_button: ShaderButton = %QuitButton
@onready var run_countdown_label: Label = %RunCountdownLabel

# 连接暂停菜单按钮并补局内确认音。
func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	EchoTimeline.run_countdown_changed.connect(_on_run_countdown_changed)
	_on_run_countdown_changed(EchoTimeline.get_run_countdown_remaining(), 0.0)
	var game_audio: Node = get_tree().root.get_node_or_null("GameAudio")
	if game_audio != null:
		game_audio.call("setup_ingame_shader_button", continue_button)
		game_audio.call("setup_ingame_shader_button", restart_button)
		game_audio.call("setup_ingame_shader_button", hint_button)
		game_audio.call("setup_ingame_shader_button", setting_button)
		game_audio.call("setup_ingame_shader_button", quit_button)
		if game_audio.has_method("setup_plain_button"):
			game_audio.call("setup_plain_button", quit_button, "cancel")
	continue_button.pressed.connect(continue_pressed.emit)
	restart_button.pressed.connect(restart_pressed.emit)
	hint_button.pressed.connect(hint_pressed.emit)
	setting_button.pressed.connect(setting_pressed.emit)
	quit_button.pressed.connect(quit_pressed.emit)


# Keeps the paused view aware of the live whole-run limit.
func _on_run_countdown_changed(remaining_seconds: float, _maximum_seconds: float) -> void:
	var total_seconds := maxi(0, ceili(remaining_seconds))
	var minutes := int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	run_countdown_label.text = "%02d:%02d" % [minutes, seconds]


# Enables the authored hint action only when the active room defines one.
func set_hint_available(value: bool) -> void:
	hint_button.disabled = not value
	hint_button.visible = value
