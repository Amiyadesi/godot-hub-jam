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
const PHASE_LAG_CHAPTERS: Array[ChapterDefinition] = [
	preload("res://resources/phase_lag/chapters/chapter_01.tres"),
	preload("res://resources/phase_lag/chapters/chapter_02.tres"),
	preload("res://resources/phase_lag/chapters/chapter_03.tres"),
	preload("res://resources/phase_lag/chapters/chapter_04.tres"),
	preload("res://resources/phase_lag/chapters/chapter_05.tres"),
]

@export_file("*.tscn") var start_scene_path := ""
@export var menu_music: AudioStream

@onready var start_button: ShaderButton = %StartButton
@onready var continue_button: ShaderButton = %ContinueButton
@onready var setting_button: ShaderButton = %SettingButton
@onready var thanks_button: ShaderButton = %ThanksButton
@onready var exit_button: ShaderButton = %ExitButton
@onready var mode_selection: ColorRect = %ModeSelection
@onready var solo_mode_button: ShaderButton = %SoloModeButton
@onready var coop_mode_button: ShaderButton = %CoopModeButton
@onready var mode_cancel_button: ShaderButton = %ModeCancelButton
@onready var setting_screen: SettingScreen = %SettingScreen
@onready var thank_screen: ThankScreen = %ThankScreen
@onready var status_label: Label = %StatusLabel
@onready var menu_animation_player: AnimationPlayer = %MenuAnimationPlayer
@onready var phase_cycle_animation_player: AnimationPlayer = %PhaseCycleAnimationPlayer

var _credits_origin: CreditsOrigin = CreditsOrigin.MAIN_MENU
var _settings_tab_before_credits: int = 0
var _intro_active: bool = false


# Initializes menu state, persisted progress, audio, and title transition.
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


# Connects the five authored menu commands and modal handoffs.
func _connect_signals() -> void:
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	setting_button.pressed.connect(setting_screen.open_modal)
	thanks_button.pressed.connect(_on_main_thanks_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	solo_mode_button.pressed.connect(_on_solo_mode_pressed)
	coop_mode_button.pressed.connect(_on_coop_mode_pressed)
	mode_cancel_button.pressed.connect(_hide_mode_selection)
	setting_screen.thanks_requested.connect(_on_setting_thanks_requested)
	thank_screen.return_requested.connect(_on_thank_return_requested)
	menu_animation_player.animation_finished.connect(_on_menu_animation_finished)


# Routes each authored button through the shared menu audio service.
func _configure_audio() -> void:
	GameAudio.setup_menu_shader_button(start_button)
	GameAudio.setup_menu_shader_button(continue_button)
	GameAudio.setup_menu_shader_button(setting_button)
	GameAudio.setup_menu_shader_button(thanks_button)
	GameAudio.setup_menu_shader_button(exit_button)
	GameAudio.setup_menu_shader_button(solo_mode_button)
	GameAudio.setup_menu_shader_button(coop_mode_button)
	GameAudio.setup_menu_shader_button(mode_cancel_button)
	GameAudio.setup_plain_button(exit_button, "cancel")


# Enables the new-timeline command only when its authored scene path exists.
func _refresh_start_button() -> void:
	var ready_to_start := not start_scene_path.is_empty()
	start_button.disabled = not ready_to_start
	status_label.visible = not ready_to_start
	status_label.text = "缺少游戏入口场景。" if not ready_to_start else ""


# Refreshes every menu command that depends on slot or global progress.
func refresh_progress_controls() -> void:
	_refresh_start_button()
	_refresh_continue_button()


# Reports whether starting now would overwrite a post-tutorial Phase Lag checkpoint.
func requires_new_timeline_confirmation() -> bool:
	return LevelModule.instance != null and LevelModule.instance.has_phase_lag_resume_point()


# Resolves the exact scene that owns the most recent clean slot checkpoint.
func get_continue_scene_path() -> String:
	if LevelModule.instance == null:
		return ""
	var resume_point := LevelModule.instance.get_phase_lag_resume_point()
	if resume_point.is_empty():
		return ""
	var chapter_id := str(resume_point.get("chapter_id", ""))
	for chapter: ChapterDefinition in PHASE_LAG_CHAPTERS:
		if String(chapter.chapter_id) == chapter_id:
			return chapter.chapter_scene_path
	push_error("Menu.get_continue_scene_path: unknown chapter '%s'" % chapter_id)
	return ""


# Enables Continue only after the tutorial has produced a valid clean checkpoint.
func _refresh_continue_button() -> void:
	continue_button.disabled = get_continue_scene_path().is_empty()


# Starts a new timeline directly on a first run and confirms before overwriting progress.
func _on_start_pressed() -> void:
	if requires_new_timeline_confirmation():
		if not await FeedbackOverlay.ask("重新开始", "现有进度会被新的时间线覆盖。", "重新开始", "返回"):
			start_button.grab_focus()
			return
	_show_mode_selection()


# Resets slot progress, persists the chosen mode, and enters chapter one.
func _begin_new_timeline(play_mode: StringName) -> void:
	SaveSystem.new_game(1)
	LevelModule.instance.set_play_mode(play_mode)
	SaveSystem.save_slot(1)
	start_requested.emit()
	var tween := SceneManager.transition_start(EXIT_TRANSITION)
	if tween != null:
		await tween.finished
	SceneManager.change_scene_to_file(start_scene_path)


# Opens the authored single-player/local-coop choice before a fresh save exists.
func _show_mode_selection() -> void:
	mode_selection.visible = true
	solo_mode_button.grab_focus()


# Closes mode selection without touching the current save slot.
func _hide_mode_selection() -> void:
	mode_selection.visible = false
	start_button.grab_focus()


# Starts the new timeline with role switching owned by player one.
func _on_solo_mode_pressed() -> void:
	_begin_new_timeline(LevelModule.PLAY_MODE_SOLO)


# Starts the new timeline with fixed P1/P2 role ownership.
func _on_coop_mode_pressed() -> void:
	_begin_new_timeline(LevelModule.PLAY_MODE_LOCAL_COOP)


# Loads the active slot again, then enters the authored scene for its recent checkpoint.
func _on_continue_pressed() -> void:
	if not SaveSystem.load_slot(1):
		refresh_progress_controls()
		return
	var continue_scene_path := get_continue_scene_path()
	if continue_scene_path.is_empty():
		refresh_progress_controls()
		return
	EntanglementBus.reset_queue(true)
	var tween := SceneManager.transition_start(EXIT_TRANSITION)
	if tween != null:
		await tween.finished
	SceneManager.change_scene_to_file(continue_scene_path)


# Confirms before closing the desktop game process.
func _on_exit_pressed() -> void:
	if await FeedbackOverlay.ask("退出游戏", "确定要退出当前游戏吗？", "退出", "取消"):
		get_tree().quit()


# Opens credits from the title and records the focus destination for return.
func _on_main_thanks_pressed() -> void:
	_credits_origin = CreditsOrigin.MAIN_MENU
	thank_screen.open_modal()


# Hands the open settings modal to credits while preserving its selected tab.
func _on_setting_thanks_requested() -> void:
	_credits_origin = CreditsOrigin.SETTINGS
	_settings_tab_before_credits = setting_screen.get_current_tab()
	var tween := setting_screen.close_modal()
	if tween != null:
		await tween.finished
	thank_screen.open_modal()


# Returns credits to its recorded origin and restores keyboard focus.
func _on_thank_return_requested() -> void:
	var tween := thank_screen.close_modal()
	if tween != null:
		await tween.finished
	if _credits_origin == CreditsOrigin.SETTINGS:
		setting_screen.select_tab(_settings_tab_before_credits)
		setting_screen.open_modal()
		return
	thanks_button.grab_focus()


# Starts the authored calibration entrance without allowing the first input to activate a command.
func _play_menu_intro() -> void:
	_intro_active = true
	_set_main_menu_input_enabled(false)
	menu_animation_player.play(MENU_INTRO_REDUCED if _uses_reduced_intro() else MENU_INTRO)
	menu_animation_player.seek(0.0, true)


# Completes the entrance when either authored animation reaches its final keyframe.
func _on_menu_animation_finished(animation_name: StringName) -> void:
	if not _intro_active or animation_name not in [MENU_INTRO, MENU_INTRO_REDUCED]:
		return
	_finish_menu_intro()


# Applies the final interactive state once calibration has completed or been skipped.
func _finish_menu_intro() -> void:
	_intro_active = false
	_set_main_menu_input_enabled(true)
	start_button.grab_focus()
	_start_menu_phase_cycle()


# Starts the slow authored past/future background cycle after title controls settle.
func _start_menu_phase_cycle() -> void:
	phase_cycle_animation_player.play(
		MENU_PHASE_CYCLE_REDUCED if _uses_reduced_intro() else MENU_PHASE_CYCLE
	)


# Seeks to the authored final frame so the first input skips cleanly without visual popping.
func _skip_menu_intro() -> void:
	menu_animation_player.seek(menu_animation_player.current_animation_length, true)
	menu_animation_player.stop()
	_finish_menu_intro()


# Uses the existing low-flash accessibility setting as the reduced-motion menu variant.
func _uses_reduced_intro() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)


# Gates only the five title commands without changing their disabled presentation.
func _set_main_menu_input_enabled(enabled: bool) -> void:
	for button: ShaderButton in [start_button, continue_button, setting_button, thanks_button, exit_button]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


# Loads the current slot so completion records survive title returns.
func _load_slot_progress() -> void:
	if SaveSystem.slot_exists(1):
		SaveSystem.load_slot(1)

# Reports whether a discrete keyboard, mouse, or controller press should skip calibration.
func _is_intro_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false


# Lets the first input skip calibration and later cancel input dismiss mode selection.
func _unhandled_input(event: InputEvent) -> void:
	if _intro_active and _is_intro_skip_event(event):
		_skip_menu_intro()
		get_viewport().set_input_as_handled()
		return
	if mode_selection.visible and event.is_action_pressed("ui_cancel"):
		_hide_mode_selection()
		get_viewport().set_input_as_handled()
