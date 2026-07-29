extends Control

signal start_requested

enum CreditsOrigin {
	MAIN_MENU,
	SETTINGS,
}

const ENTER_TRANSITION := preload("res://resources/scene_transitions/stage_enter_fade_to_black.tres")
const ENTRY_STATE_META := &"echo_chase_entry_temporal_state"
const ENTRY_STATE_PRESENT := &"present"
const ENTRY_STATE_PAST := &"past"
const MENU_INTRO := &"menu_enter"
const MENU_INTRO_REDUCED := &"menu_enter_reduced"
const MENU_IDLE := &"menu_idle"
const PULSE_PRESENT := &"pulse_present"
const PULSE_PAST := &"pulse_past"
const BACKGROUND_ORIGIN := Vector2(-32.0, -32.0)
const BACKGROUND_PARALLAX := Vector2(16.0, 10.0)
const BACKGROUND_FOLLOW_SPEED := 7.0

@export_file("*.tscn") var echo_chase_entry_scene_path := ""
@export var menu_music: AudioStream
@export var start_transition: SceneTransition
@export var start_transition_reduced: SceneTransition
@export var continue_transition: SceneTransition
@export var continue_transition_reduced: SceneTransition

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
@onready var transition_animation_player: AnimationPlayer = %TransitionAnimationPlayer
@onready var background: TextureRect = %Background

var _credits_origin: CreditsOrigin = CreditsOrigin.MAIN_MENU
var _settings_tab_before_credits := 0
var _intro_active := false
var _transition_active := false


# 初始化存档、音频、固定信号和 authored 菜单入场。
func _ready() -> void:
	assert(start_transition != null, "Menu requires an authored start transition")
	assert(start_transition_reduced != null, "Menu requires an authored reduced start transition")
	assert(continue_transition != null, "Menu requires an authored continue transition")
	assert(continue_transition_reduced != null, "Menu requires an authored reduced continue transition")
	setting_screen.is_in_menu_flag = true
	_load_slot_progress()
	_configure_audio()
	_connect_signals()
	refresh_progress_controls()
	SceneManager.transition_start(ENTER_TRANSITION, true)
	_play_menu_intro()
	if menu_music != null:
		GameAudio.play_music("menu", menu_music, 0.4)


# 只让地图背景跟随鼠标，三时态角色保持严格三等分构图。
func _process(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var pointer_ratio := get_viewport().get_mouse_position() / viewport_size
	var centered_pointer := (pointer_ratio - Vector2(0.5, 0.5)) * 2.0
	var target := BACKGROUND_ORIGIN - centered_pointer * BACKGROUND_PARALLAX
	var follow := 1.0 - exp(-BACKGROUND_FOLLOW_SPEED * delta)
	background.position = background.position.lerp(target, follow)


# 连接五个主菜单命令与设置、感谢页返回路由。
func _connect_signals() -> void:
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	setting_button.pressed.connect(setting_screen.open_modal)
	thanks_button.pressed.connect(_on_main_thanks_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	setting_screen.thanks_requested.connect(_on_setting_thanks_requested)
	setting_screen.return_completed.connect(setting_button.grab_focus)
	thank_screen.return_requested.connect(_on_thank_return_requested)
	menu_animation_player.animation_finished.connect(_on_menu_animation_finished)


# 复用共享音频服务配置全部菜单按钮反馈。
func _configure_audio() -> void:
	GameAudio.setup_menu_shader_button(start_button)
	GameAudio.setup_menu_shader_button(continue_button)
	GameAudio.setup_menu_shader_button(setting_button)
	GameAudio.setup_menu_shader_button(thanks_button)
	GameAudio.setup_menu_shader_button(exit_button)
	GameAudio.setup_plain_button(exit_button, "cancel")


# 根据 authored 入口和有效 checkpoint 刷新开始、继续状态。
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


# 确认覆盖存档后，以现在体转场建立新时间线。
func _on_start_pressed() -> void:
	if _transition_active or not _has_authored_entry_scene():
		refresh_progress_controls()
		return
	if LevelModule.instance != null and LevelModule.instance.has_continue_point():
		var restart_confirmed := await FeedbackOverlay.ask(
			"重新开始",
			"开始新游戏会覆盖当前复活点。确定重新开始吗？",
			"重新开始",
			"取消"
		)
		if not restart_confirmed:
			start_button.grab_focus()
			return
	SaveSystem.new_game(1)
	SaveSystem.save_slot(1)
	start_requested.emit()
	await _transition_to_game(echo_chase_entry_scene_path, ENTRY_STATE_PRESENT)


# 加载最近的干净 checkpoint，并以过去体转场进入。
func _on_continue_pressed() -> void:
	if _transition_active or not SaveSystem.load_slot(1) or LevelModule.instance == null:
		refresh_progress_controls()
		return
	var scene_path := LevelModule.instance.get_continue_scene_path()
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		refresh_progress_controls()
		return
	await _transition_to_game(scene_path, ENTRY_STATE_PAST)


# 先播放 authored 时态原点脉冲，再用同色径向遮罩切入玩法。
func _transition_to_game(scene_path: String, temporal_state: StringName) -> bool:
	_transition_active = true
	_set_main_menu_input_enabled(false)
	var reduced := _uses_reduced_intro()
	if not reduced:
		transition_animation_player.play(PULSE_PRESENT if temporal_state == ENTRY_STATE_PRESENT else PULSE_PAST)
		await transition_animation_player.animation_finished
	var transition := _get_exit_transition(temporal_state, reduced)
	SceneManager.set_meta(ENTRY_STATE_META, temporal_state)
	var tween := SceneManager.transition_start(transition)
	if tween != null:
		await tween.finished
	var error := SceneManager.change_scene_to_file(scene_path)
	if error == OK:
		return true
	SceneManager.remove_meta(ENTRY_STATE_META)
	SceneManager.transition_clear()
	_transition_active = false
	_set_main_menu_input_enabled(true)
	push_error("Menu failed to load Echo Chase scene: %s" % scene_path)
	if temporal_state == ENTRY_STATE_PRESENT:
		start_button.grab_focus()
	else:
		continue_button.grab_focus()
	return false


# 按入口时态和低闪烁设置选择固定的 authored 径向资源。
func _get_exit_transition(temporal_state: StringName, reduced: bool) -> SceneTransition:
	if temporal_state == ENTRY_STATE_PAST:
		return continue_transition_reduced if reduced else continue_transition
	return start_transition_reduced if reduced else start_transition


# 退出桌面进程前保留一次明确确认。
func _on_exit_pressed() -> void:
	if await FeedbackOverlay.ask("退出游戏", "确定要退出当前游戏吗？", "退出", "取消"):
		get_tree().quit()


# 从主菜单打开感谢页并记录返回来源。
func _on_main_thanks_pressed() -> void:
	_credits_origin = CreditsOrigin.MAIN_MENU
	thank_screen.open_modal()


# 从设置页进入感谢页时保留原标签。
func _on_setting_thanks_requested() -> void:
	_credits_origin = CreditsOrigin.SETTINGS
	_settings_tab_before_credits = setting_screen.get_current_tab()
	var tween := setting_screen.close_modal()
	if tween != null:
		await tween.finished
	thank_screen.open_modal()


# 按记录来源返回主菜单或原设置标签。
func _on_thank_return_requested() -> void:
	var tween := thank_screen.close_modal()
	if tween != null:
		await tween.finished
	if _credits_origin == CreditsOrigin.SETTINGS:
		setting_screen.select_tab(_settings_tab_before_credits)
		setting_screen.open_modal()
		return
	thanks_button.grab_focus()


# 播放 authored 入场，并在结束前屏蔽五个命令。
func _play_menu_intro() -> void:
	_intro_active = true
	_set_main_menu_input_enabled(false)
	menu_animation_player.play(MENU_INTRO_REDUCED if _uses_reduced_intro() else MENU_INTRO)
	menu_animation_player.seek(0.0, true)


# 标准或低闪烁入场自然结束后统一开放输入。
func _on_menu_animation_finished(animation_name: StringName) -> void:
	if not _intro_active or animation_name not in [MENU_INTRO, MENU_INTRO_REDUCED]:
		return
	_finish_menu_intro()


# 入场落定后恢复焦点并启动三时态漂浮。
func _finish_menu_intro() -> void:
	_intro_active = false
	_set_main_menu_input_enabled(true)
	if not start_button.disabled:
		start_button.grab_focus()
	elif not continue_button.disabled:
		continue_button.grab_focus()
	else:
		setting_button.grab_focus()
	_start_menu_phase_cycle()


# 开始三个固定剪影的错相位漂浮循环。
func _start_menu_phase_cycle() -> void:
	phase_cycle_animation_player.play(MENU_IDLE)


# 跳过时先应用 authored 最终帧，避免残留半入场状态。
func _skip_menu_intro() -> void:
	menu_animation_player.seek(menu_animation_player.current_animation_length, true)
	menu_animation_player.stop()
	_finish_menu_intro()


# 读取既有低闪烁设置选择稳定入场和较慢径向转场。
func _uses_reduced_intro() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)


# 只门控五个主菜单命令，不影响隐藏模态页自身路由。
func _set_main_menu_input_enabled(enabled: bool) -> void:
	for button: ShaderButton in [start_button, continue_button, setting_button, thanks_button, exit_button]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


# 预读固定槽位，使有效 Echo checkpoint 能启用继续游戏。
func _load_slot_progress() -> void:
	if SaveSystem.slot_exists(1):
		SaveSystem.load_slot(1)


# 只接受真实存在的 authored 灰盒入口。
func _has_authored_entry_scene() -> bool:
	return not echo_chase_entry_scene_path.is_empty() and ResourceLoader.exists(echo_chase_entry_scene_path)


# 只把离散按下识别为入场跳过，忽略键盘重复事件。
func _is_intro_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false


# 消费首次跳过输入，禁止它顺带触发已落定按钮。
func _unhandled_input(event: InputEvent) -> void:
	if not _intro_active or not _is_intro_skip_event(event):
		return
	_skip_menu_intro()
	get_viewport().set_input_as_handled()
