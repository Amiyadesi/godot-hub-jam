extends Control

signal start_requested

enum CreditsOrigin {
	MAIN_MENU,
	SETTINGS,
}

const EXIT_TRANSITION := preload("res://resources/scene_transitions/stage_exit_fade_to_black.tres")
const ENTER_TRANSITION := preload("res://resources/scene_transitions/stage_enter_fade_to_black.tres")
const MENU_INTRO := &"menu_enter"
const MENU_INTRO_REDUCED := &"menu_enter_reduced"
const MENU_PHASE_CYCLE := &"menu_phase_cycle"
const MENU_PHASE_CYCLE_REDUCED := &"menu_phase_cycle_reduced"

@export_file("*.tscn") var echo_chase_entry_scene_path := ""
@export var menu_music: AudioStream

@onready var start_button: ShaderButton = %StartButton
@onready var continue_button: ShaderButton = %ContinueButton
@onready var setting_button: ShaderButton = %SettingButton
@onready var thanks_button: ShaderButton = %ThanksButton
@onready var exit_button: ShaderButton = %ExitButton
@onready var setting_screen: SettingScreen = %SettingScreen
@onready var thank_screen: ThankScreen = %ThankScreen
@onready var status_label: Label = %StatusLabel
@onready var menu_animation_player: AnimationPlayer = %MenuAnimationPlayer
@onready var phase_cycle_animation_player: AnimationPlayer = %PhaseCycleAnimationPlayer

var _credits_origin: CreditsOrigin = CreditsOrigin.MAIN_MENU
var _settings_tab_before_credits := 0
var _intro_active := false


# Initializes title state, persisted settings, and the authored entrance animation.
func _ready() -> void:
	setting_screen.is_in_menu_flag = true
	_load_slot_progress()
	_configure_audio()
	_connect_signals()
	refresh_progress_controls()
	SceneManager.transition_start(ENTER_TRANSITION, true)
	_play_menu_intro()
	if menu_music != null:
		GameAudio.play_music("menu", menu_music, 0.4)


# Connects the fixed title controls and credit routing.
func _connect_signals() -> void:
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	setting_button.pressed.connect(setting_screen.open_modal)
	thanks_button.pressed.connect(_on_main_thanks_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	setting_screen.thanks_requested.connect(_on_setting_thanks_requested)
	thank_screen.return_requested.connect(_on_thank_return_requested)
	menu_animation_player.animation_finished.connect(_on_menu_animation_finished)


# Routes title commands through the existing shared audio service.
func _configure_audio() -> void:
	GameAudio.setup_menu_shader_button(start_button)
	GameAudio.setup_menu_shader_button(continue_button)
	GameAudio.setup_menu_shader_button(setting_button)
	GameAudio.setup_menu_shader_button(thanks_button)
	GameAudio.setup_menu_shader_button(exit_button)
	GameAudio.setup_plain_button(exit_button, "cancel")


# Refreshes start and continue availability from authored scene and save state.
func refresh_progress_controls() -> void:
	var entry_ready := _has_authored_entry_scene()
	start_button.disabled = not entry_ready
	continue_button.disabled = (
		not entry_ready
		or LevelModule.instance == null
		or not LevelModule.instance.has_continue_point()
		or not ResourceLoader.exists(LevelModule.instance.get_continue_scene_path())
	)
	status_label.visible = not entry_ready
	status_label.text = "等待灰盒入口场景。" if not entry_ready else ""


# Starts a fresh Echo Chase timeline only when the user has authored an entry scene.
func _on_start_pressed() -> void:
	if not _has_authored_entry_scene():
		refresh_progress_controls()
		return
	SaveSystem.new_game(1)
	SaveSystem.save_slot(1)
	start_requested.emit()
	var tween := SceneManager.transition_start(EXIT_TRANSITION)
	if tween != null:
		await tween.finished
	SceneManager.change_scene_to_file(echo_chase_entry_scene_path)


# Restores the latest clean authored checkpoint without replaying in-flight time state.
func _on_continue_pressed() -> void:
	if not SaveSystem.load_slot(1) or LevelModule.instance == null:
		refresh_progress_controls()
		return
	var scene_path := LevelModule.instance.get_continue_scene_path()
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		refresh_progress_controls()
		return
	var tween := SceneManager.transition_start(EXIT_TRANSITION)
	if tween != null:
		await tween.finished
	SceneManager.change_scene_to_file(scene_path)


# Confirms before closing the desktop game process.
func _on_exit_pressed() -> void:
	if await FeedbackOverlay.ask("退出游戏", "确定要退出当前游戏吗？", "退出", "取消"):
		get_tree().quit()


# Opens credits from the title and records the return destination.
func _on_main_thanks_pressed() -> void:
	_credits_origin = CreditsOrigin.MAIN_MENU
	thank_screen.open_modal()


# Hands settings to credits while preserving the selected settings page.
func _on_setting_thanks_requested() -> void:
	_credits_origin = CreditsOrigin.SETTINGS
	_settings_tab_before_credits = setting_screen.get_current_tab()
	var tween := setting_screen.close_modal()
	if tween != null:
		await tween.finished
	thank_screen.open_modal()


# Restores credits to their recorded origin and returns keyboard focus.
func _on_thank_return_requested() -> void:
	var tween := thank_screen.close_modal()
	if tween != null:
		await tween.finished
	if _credits_origin == CreditsOrigin.SETTINGS:
		setting_screen.select_tab(_settings_tab_before_credits)
		setting_screen.open_modal()
		return
	thanks_button.grab_focus()


# Starts the authored title entrance without letting its first input fire a button.
func _play_menu_intro() -> void:
	_intro_active = true
	_set_main_menu_input_enabled(false)
	menu_animation_player.play(MENU_INTRO_REDUCED if _uses_reduced_intro() else MENU_INTRO)
	menu_animation_player.seek(0.0, true)


# Completes the title entrance after either authored animation variant finishes.
func _on_menu_animation_finished(animation_name: StringName) -> void:
	if not _intro_active or animation_name not in [MENU_INTRO, MENU_INTRO_REDUCED]:
		return
	_finish_menu_intro()


# Enables title commands after the entrance settles.
func _finish_menu_intro() -> void:
	_intro_active = false
	_set_main_menu_input_enabled(true)
	setting_button.grab_focus()
	_start_menu_phase_cycle()


# Starts the ambient temporal background cycle.
func _start_menu_phase_cycle() -> void:
	phase_cycle_animation_player.play(
		MENU_PHASE_CYCLE_REDUCED if _uses_reduced_intro() else MENU_PHASE_CYCLE
	)


# Seeks to the authored final entrance keyframe before enabling controls.
func _skip_menu_intro() -> void:
	menu_animation_player.seek(menu_animation_player.current_animation_length, true)
	menu_animation_player.stop()
	_finish_menu_intro()


# Uses the existing low-flash setting for the reduced title animation.
func _uses_reduced_intro() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)


# Gates only the five title commands during the authored entrance.
func _set_main_menu_input_enabled(enabled: bool) -> void:
	for button: ShaderButton in [start_button, continue_button, setting_button, thanks_button, exit_button]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


# Loads the selected slot so valid Echo checkpoints can enable Continue.
func _load_slot_progress() -> void:
	if SaveSystem.slot_exists(1):
		SaveSystem.load_slot(1)


# Checks whether the user has supplied an authored graybox entry scene.
func _has_authored_entry_scene() -> bool:
	return not echo_chase_entry_scene_path.is_empty() and ResourceLoader.exists(echo_chase_entry_scene_path)


# Recognizes a discrete press that may skip title entrance animation.
func _is_intro_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false


# Lets one input skip entrance animation without activating a menu command.
func _unhandled_input(event: InputEvent) -> void:
	if not _intro_active or not _is_intro_skip_event(event):
		return
	_skip_menu_intro()
	get_viewport().set_input_as_handled()
