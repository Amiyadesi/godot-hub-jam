extends Control

signal start_requested

const EXIT_TRANSITION := preload("res://resources/scene_transitions/stage_exit_fade_to_black.tres")
const ENTER_TRANSITION := preload("res://resources/scene_transitions/stage_enter_fade_to_black.tres")

@export_file("*.tscn") var start_scene_path := ""
@export var menu_music: AudioStream
@export_range(0.05, 2.0, 0.05, "suffix:s") var boot_flash_seconds := 0.22

@onready var start_button: ShaderButton = %StartButton
@onready var setting_button: ShaderButton = %SettingButton
@onready var thanks_button: ShaderButton = %ThanksButton
@onready var exit_button: ShaderButton = %ExitButton
@onready var setting_screen: SettingScreen = %SettingScreen
@onready var thank_screen: ThankScreen = %ThankScreen
@onready var status_label: Label = %StatusLabel
@onready var boot_flash: ColorRect = %BootFlash


func _ready() -> void:
	setting_screen.is_in_menu_flag = true
	_configure_audio()
	_connect_signals()
	_refresh_start_button()
	SceneManager.transition_start(ENTER_TRANSITION, true)
	_play_boot_flash()
	if menu_music != null:
		GameAudio.play_music("menu", menu_music, 0.4)


func _connect_signals() -> void:
	start_button.pressed.connect(_on_start_pressed)
	setting_button.pressed.connect(setting_screen.open_modal)
	thanks_button.pressed.connect(thank_screen.open_modal)
	exit_button.pressed.connect(get_tree().quit)
	setting_screen.thanks_requested.connect(_on_setting_thanks_requested)
	thank_screen.return_requested.connect(_on_thank_return_requested)


func _configure_audio() -> void:
	GameAudio.setup_menu_shader_button(start_button)
	GameAudio.setup_menu_shader_button(setting_button)
	GameAudio.setup_menu_shader_button(thanks_button)
	GameAudio.setup_menu_shader_button(exit_button)
	GameAudio.setup_plain_button(exit_button, "cancel")


func _refresh_start_button() -> void:
	var ready_to_start := not start_scene_path.is_empty()
	start_button.disabled = not ready_to_start
	status_label.text = "" if ready_to_start else "在 Inspector 里给 Menu.start_scene_path 指定你的游戏入口场景。"


func _on_start_pressed() -> void:
	start_requested.emit()
	var tween := SceneManager.transition_start(EXIT_TRANSITION)
	if tween != null:
		await tween.finished
	SceneManager.change_scene_to_file(start_scene_path)


func _on_setting_thanks_requested() -> void:
	setting_screen.close_modal()
	thank_screen.open_modal()


func _on_thank_return_requested() -> void:
	thank_screen.close_modal()
	setting_screen.open_modal()


func _play_boot_flash() -> void:
	boot_flash.visible = true
	boot_flash.modulate = Color(1, 1, 1, 0.8)
	var tween := create_tween()
	tween.tween_property(boot_flash, "modulate:a", 0.0, boot_flash_seconds)
	await tween.finished
	boot_flash.visible = false
