class_name EchoChaseStart
extends Node
## 起始施工场景控制器：只负责存档点、失败复位和暂停界面路由。

signal reset_completed(respawn_position: Vector2)

const RESET_DELAY_SECONDS := 0.4
const ENTRY_STATE_META := &"echo_chase_entry_temporal_state"
const ENTRY_STATE_PRESENT := &"present"
const ENTRY_STATE_PAST := &"past"
const CURRENT_ROOM_CHECKPOINT_ID := &"current_room"

@export_file("*.tscn") var checkpoint_scene_path := ""
@export_file("*.tscn") var menu_scene_path := ""
@export var player: EchoPlayer
@export var gameplay_world: Node2D
@export var spawn_point: Marker2D
@export var present_room: PresentRoom
@export var pause_screen: PauseScreen
@export var setting_screen: SettingScreen
@export var reset_audio: AudioStreamPlayer
@export var gameplay_music: AudioStream
@export var present_entry_transition: SceneTransition
@export var past_entry_transition: SceneTransition

var _checkpoints: Array[EchoCheckpoint] = []
var _delay_switches: Array[DelayPickup] = []
var _default_delay_switch: DelayPickup
var _respawn_position := Vector2.ZERO
var _respawn_past_delay_seconds := EchoTimeline.DEFAULT_PAST_DELAY
var _respawn_delay_switch_id := EchoTimeline.DEFAULT_DELAY_SWITCH_ID
var _reset_in_progress := false
var _entry_intro_active := false
var _entry_tween: Tween


# 收集当前场景实际摆放的机关，并接通存档、失败和暂停信号。
func _ready() -> void:
	EchoTimeline.set_gameplay_active(false)
	if gameplay_music == null:
		push_error("EchoChaseStart requires gameplay_music")
	else:
		GameAudio.play_music("echo_chase_gameplay", gameplay_music, 0.6)
	_resolve_checkpoints()
	_resolve_delay_switches()
	_connect_gameplay_signals()
	_configure_ui()
	_restore_entry_position()
	_play_entry_intro()


# 让 Esc 在暂停前后都走同一条 authored 菜单路径。
func _unhandled_input(event: InputEvent) -> void:
	if _reset_in_progress:
		return
	if event.is_action_pressed(&"pause"):
		if _entry_intro_active:
			_finish_entry_intro()
		get_viewport().set_input_as_handled()
		if pause_screen.visible:
			_resume_game()
		else:
			_pause_game()
		return
	if _entry_intro_active and _is_entry_skip_event(event):
		_finish_entry_intro()
		get_viewport().set_input_as_handled()


# 返回玩法入场是否仍在冻结时间线。
func is_entry_intro_active() -> bool:
	return _entry_intro_active


# 允许测试与后续 authored 流程显式跳过入场。
func skip_entry_intro() -> void:
	if _entry_intro_active:
		_finish_entry_intro()


# 收集当前玩法世界内实际摆放的存档点，不依赖固定层级或数量。
func _resolve_checkpoints() -> void:
	_checkpoints.clear()
	for node in gameplay_world.find_children("*", "EchoCheckpoint", true, false):
		_checkpoints.append(node as EchoCheckpoint)


# 收集当前玩法世界内实际摆放的延迟台；未摆默认台时仍从标准三秒开始。
func _resolve_delay_switches() -> void:
	_delay_switches.clear()
	_default_delay_switch = null
	for node in gameplay_world.find_children("*", "DelayPickup", true, false):
		var delay_switch := node as DelayPickup
		_delay_switches.append(delay_switch)
		if delay_switch.default_active and _default_delay_switch == null:
			_default_delay_switch = delay_switch


# 连接场景内唯一的玩家失败、出界和 checkpoint 请求。
func _connect_gameplay_signals() -> void:
	EchoTimeline.player_caught.connect(_on_player_caught)
	player.failure_requested.connect(_on_player_failure_requested)
	for checkpoint in _checkpoints:
		checkpoint.activation_requested.connect(_on_checkpoint_activation_requested)


# 禁用未使用的 Hint，并让设置页返回后继续停在暂停状态。
func _configure_ui() -> void:
	pause_screen.set_hint_available(false)
	setting_screen.is_in_menu_flag = false
	pause_screen.continue_pressed.connect(_resume_game)
	pause_screen.restart_pressed.connect(_restart_from_pause)
	pause_screen.setting_pressed.connect(_open_settings_from_pause)
	pause_screen.quit_pressed.connect(_return_to_menu)
	setting_screen.return_completed.connect(_on_settings_return_completed)


# 新游戏使用默认3秒台；Continue 恢复坐标、延迟台和干净时间线。
func _restore_entry_position() -> void:
	_respawn_position = spawn_point.global_position
	_respawn_past_delay_seconds = EchoTimeline.DEFAULT_PAST_DELAY
	_respawn_delay_switch_id = EchoTimeline.DEFAULT_DELAY_SWITCH_ID
	if _default_delay_switch != null:
		_respawn_past_delay_seconds = float(_default_delay_switch.delay_seconds)
		_respawn_delay_switch_id = _default_delay_switch.get_delay_switch_id()
	var checkpoint := LevelModule.instance.get_checkpoint() if LevelModule.instance != null else {}
	if checkpoint.is_empty() or checkpoint.get("scene_path", "") != checkpoint_scene_path:
		player.reset_player(_respawn_position)
		EchoTimeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)
		return
	var checkpoint_id := String(checkpoint.get("checkpoint_id", ""))
	var active_checkpoint := _get_checkpoint(checkpoint_id)
	if active_checkpoint == null:
		push_error("EchoChaseStart cannot restore unknown checkpoint '%s'" % checkpoint_id)
		player.reset_player(_respawn_position)
		EchoTimeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)
		return
	var saved_switch_id := StringName(str(checkpoint.get("delay_switch_id", "")))
	var saved_delay := float(checkpoint.get("past_delay_seconds", 0.0))
	var saved_delay_switch := _get_delay_switch(saved_switch_id)
	if saved_delay_switch == null or not is_equal_approx(float(saved_delay_switch.delay_seconds), saved_delay):
		push_error("EchoChaseStart cannot restore invalid delay switch '%s'" % saved_switch_id)
		LevelModule.instance.clear_checkpoint()
		player.reset_player(_respawn_position)
		EchoTimeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)
		return
	_respawn_position = checkpoint.get("position", active_checkpoint.get_respawn_position()) as Vector2
	_respawn_past_delay_seconds = saved_delay
	_respawn_delay_switch_id = saved_switch_id
	active_checkpoint.set_active(true, false)
	player.reset_player(_respawn_position)
	EchoTimeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)


# 复用菜单满屏时态色淡入，并冻结整个 authored 玩法世界。
func _play_entry_intro() -> void:
	_entry_intro_active = true
	gameplay_world.process_mode = Node.PROCESS_MODE_DISABLED
	var temporal_state := StringName(SceneManager.get_meta(ENTRY_STATE_META, ENTRY_STATE_PRESENT))
	if SceneManager.has_meta(ENTRY_STATE_META):
		SceneManager.remove_meta(ENTRY_STATE_META)
	var transition := past_entry_transition if temporal_state == ENTRY_STATE_PAST else present_entry_transition
	_entry_tween = SceneManager.transition_start(transition, true)
	if _entry_tween == null:
		_finish_entry_intro()
		return
	_entry_tween.finished.connect(_finish_entry_intro, CONNECT_ONE_SHOT)


# 清掉同色遮罩并恢复正常玩法时间。
func _finish_entry_intro() -> void:
	if not _entry_intro_active:
		return
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	_entry_tween = null
	SceneManager.transition_clear()
	gameplay_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	EchoTimeline.set_gameplay_active(true)
	_entry_intro_active = false


# 识别键盘、手柄和鼠标的离散跳过输入。
func _is_entry_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false


# 返回与存档 ID 对应的 authored checkpoint。
func _get_checkpoint(checkpoint_id: String) -> EchoCheckpoint:
	for checkpoint in _checkpoints:
		if String(checkpoint.get_checkpoint_id()) == checkpoint_id:
			return checkpoint
	return null


# 返回与存档 ID 对应的 authored 延迟台。
func _get_delay_switch(switch_id: StringName) -> DelayPickup:
	for delay_switch in _delay_switches:
		if delay_switch.get_delay_switch_id() == switch_id:
			return delay_switch
	return null


# 激活最新复活点并写入槽位，不改动当前时间线。
func _on_checkpoint_activation_requested(checkpoint: EchoCheckpoint) -> void:
	if EchoTimeline.is_future_recording():
		return
	for authored_checkpoint in _checkpoints:
		authored_checkpoint.set_active(authored_checkpoint == checkpoint, authored_checkpoint == checkpoint)
	_respawn_position = checkpoint.get_respawn_position()
	_respawn_past_delay_seconds = EchoTimeline.get_selected_past_delay_seconds()
	_respawn_delay_switch_id = EchoTimeline.get_selected_delay_switch_id()
	LevelModule.instance.set_checkpoint(
		checkpoint_scene_path,
		String(checkpoint.get_checkpoint_id()),
		_respawn_position,
		_respawn_past_delay_seconds,
		String(_respawn_delay_switch_id)
	)
	SaveSystem.save_slot(1)
	if checkpoint.get_checkpoint_id() == CURRENT_ROOM_CHECKPOINT_ID:
		present_room.request_checkpoint_dialogue()


# 过去体抓到玩家时播放失败反馈并排入复位。
func _on_player_caught() -> void:
	_begin_failure_reset(&"hit")


# 玩家 Hurtbox 和过去体共用带动画语义的 checkpoint 失败入口。
func _on_player_failure_requested(animation_name: StringName) -> void:
	_begin_failure_reset(animation_name)





# 冻结玩家 0.4 秒，然后先恢复坐标、再清空时间线。
func _begin_failure_reset(animation_name: StringName) -> void:
	if _reset_in_progress:
		return
	_reset_in_progress = true
	EchoTimeline.set_gameplay_active(false)
	player.prepare_for_reset(animation_name)
	# Clear temporal entities before the death animation so Past/VFX cannot linger behind it.
	EchoTimeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)
	reset_audio.play()
	await get_tree().create_timer(RESET_DELAY_SECONDS).timeout
	player.reset_player(_respawn_position)
	EchoTimeline.set_gameplay_active(true)
	_reset_in_progress = false
	reset_completed.emit(_respawn_position)


# 打开 authored 暂停页并冻结玩法世界。
func _pause_game() -> void:
	get_tree().paused = true
	pause_screen.open_modal()
	pause_screen.continue_button.grab_focus()


# 关闭暂停页后恢复玩法世界。
func _resume_game() -> void:
	var tween := pause_screen.close_modal()
	if tween != null:
		await tween.finished
	get_tree().paused = false


# 从暂停页重新建立当前 checkpoint 的干净时间线。
func _restart_from_pause() -> void:
	var tween := pause_screen.close_modal()
	if tween != null:
		await tween.finished
	get_tree().paused = false
	player.reset_player(_respawn_position)
	EchoTimeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)
	EchoTimeline.set_gameplay_active(true)


# 从暂停页进入设置页，整个往返过程保持游戏暂停。
func _open_settings_from_pause() -> void:
	var tween := pause_screen.close_modal()
	if tween != null:
		await tween.finished
	setting_screen.open_modal()


# 设置页完成返回后重新显示暂停页。
func _on_settings_return_completed() -> void:
	if not get_tree().paused:
		return
	pause_screen.open_modal()
	pause_screen.continue_button.grab_focus()


# 退出玩法前解除暂停并返回 authored 主菜单场景。
func _return_to_menu() -> void:
	get_tree().paused = false
	EchoTimeline.set_gameplay_active(false)
	SceneManager.change_scene_to_file(menu_scene_path)
