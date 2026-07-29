class_name EchoChaseStart
extends Node
## 起始施工场景控制器：只负责存档点、失败复位和暂停界面路由。

signal reset_completed(respawn_position: Vector2)

const RESET_DELAY_SECONDS := 0.4
const ENTRY_STATE_META := &"echo_chase_entry_temporal_state"
const ENTRY_STATE_PRESENT := &"present"
const ENTRY_STATE_PAST := &"past"

@export_file("*.tscn") var checkpoint_scene_path := ""
@export_file("*.tscn") var menu_scene_path := ""
@export var player: EchoPlayer
@export var timeline: EchoTimelineController
@export var gameplay_world: Node2D
@export var spawn_point: Marker2D
@export var checkpoint_paths: Array[NodePath] = []
@export var delay_switch_paths: Array[NodePath] = []
@export var fall_reset_area: Area2D
@export var pause_screen: PauseScreen
@export var setting_screen: SettingScreen
@export var reset_audio: AudioStreamPlayer
@export var present_entry_transition: SceneTransition
@export var past_entry_transition: SceneTransition

var _checkpoints: Array[EchoCheckpoint] = []
var _delay_switches: Array[DelayPickup] = []
var _default_delay_switch: DelayPickup
var _respawn_position := Vector2.ZERO
var _respawn_past_delay_seconds := EchoTimelineController.DEFAULT_PAST_DELAY
var _respawn_delay_switch_id := EchoTimelineController.DEFAULT_DELAY_SWITCH_ID
var _reset_in_progress := false
var _entry_intro_active := false
var _entry_tween: Tween


# 校验全部 authored 引用，并接通存档、失败和暂停信号。
func _ready() -> void:
	assert(not checkpoint_scene_path.is_empty(), "EchoChaseStart requires checkpoint_scene_path")
	assert(not menu_scene_path.is_empty(), "EchoChaseStart requires menu_scene_path")
	assert(player != null, "EchoChaseStart requires an authored EchoPlayer reference")
	assert(timeline != null, "EchoChaseStart requires an authored EchoTimelineController reference")
	assert(gameplay_world != null, "EchoChaseStart requires an authored gameplay world reference")
	assert(spawn_point != null, "EchoChaseStart requires an authored SpawnPoint reference")
	assert(fall_reset_area != null, "EchoChaseStart requires an authored FallResetArea reference")
	assert(pause_screen != null, "EchoChaseStart requires an authored PauseScreen reference")
	assert(setting_screen != null, "EchoChaseStart requires an authored SettingScreen reference")
	assert(reset_audio != null, "EchoChaseStart requires an authored reset audio reference")
	assert(present_entry_transition != null, "EchoChaseStart requires an authored present entry transition")
	assert(past_entry_transition != null, "EchoChaseStart requires an authored past entry transition")
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


# 将 Inspector 中的存档点路径解析为固定实例并拒绝空或重复 ID。
func _resolve_checkpoints() -> void:
	assert(not checkpoint_paths.is_empty(), "EchoChaseStart requires at least one authored checkpoint")
	var checkpoint_ids := {}
	for checkpoint_path in checkpoint_paths:
		var checkpoint := get_node(checkpoint_path) as EchoCheckpoint
		assert(checkpoint != null, "EchoChaseStart checkpoint path must reference EchoCheckpoint")
		var checkpoint_id := String(checkpoint.get_checkpoint_id())
		assert(not checkpoint_id.is_empty(), "EchoChaseStart checkpoint id cannot be empty")
		assert(not checkpoint_ids.has(checkpoint_id), "EchoChaseStart checkpoint ids must be unique")
		checkpoint_ids[checkpoint_id] = true
		_checkpoints.append(checkpoint)


# 解析延迟台并拒绝重复 ID 或缺失的唯一3秒默认台。
func _resolve_delay_switches() -> void:
	assert(not delay_switch_paths.is_empty(), "EchoChaseStart requires authored delay switches")
	var switch_ids := {}
	for switch_path in delay_switch_paths:
		var delay_switch := get_node(switch_path) as DelayPickup
		assert(delay_switch != null, "EchoChaseStart delay switch path must reference DelayPickup")
		var switch_id := String(delay_switch.get_delay_switch_id())
		assert(not switch_id.is_empty(), "EchoChaseStart delay switch id cannot be empty")
		assert(not switch_ids.has(switch_id), "EchoChaseStart delay switch ids must be unique")
		switch_ids[switch_id] = true
		_delay_switches.append(delay_switch)
		if delay_switch.default_active:
			assert(_default_delay_switch == null, "EchoChaseStart requires exactly one default delay switch")
			_default_delay_switch = delay_switch
	assert(_default_delay_switch != null, "EchoChaseStart requires one default delay switch")
	assert(_default_delay_switch.delay_seconds == 3, "EchoChaseStart default delay switch must be 3 seconds")


# 连接场景内唯一的玩家失败、出界和 checkpoint 请求。
func _connect_gameplay_signals() -> void:
	timeline.player_caught.connect(_on_player_caught)
	player.failure_requested.connect(_on_player_failure_requested)
	fall_reset_area.body_entered.connect(_on_fall_reset_body_entered)
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
	_respawn_past_delay_seconds = float(_default_delay_switch.delay_seconds)
	_respawn_delay_switch_id = _default_delay_switch.get_delay_switch_id()
	var checkpoint := LevelModule.instance.get_checkpoint() if LevelModule.instance != null else {}
	if checkpoint.is_empty() or checkpoint.get("scene_path", "") != checkpoint_scene_path:
		player.reset_player(_respawn_position)
		timeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)
		return
	var checkpoint_id := String(checkpoint.get("checkpoint_id", ""))
	var active_checkpoint := _get_checkpoint(checkpoint_id)
	if active_checkpoint == null:
		push_error("EchoChaseStart cannot restore unknown checkpoint '%s'" % checkpoint_id)
		player.reset_player(_respawn_position)
		timeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)
		return
	var saved_switch_id := StringName(str(checkpoint.get("delay_switch_id", "")))
	var saved_delay := float(checkpoint.get("past_delay_seconds", 0.0))
	var saved_delay_switch := _get_delay_switch(saved_switch_id)
	if saved_delay_switch == null or not is_equal_approx(float(saved_delay_switch.delay_seconds), saved_delay):
		push_error("EchoChaseStart cannot restore invalid delay switch '%s'" % saved_switch_id)
		LevelModule.instance.clear_checkpoint()
		player.reset_player(_respawn_position)
		timeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)
		return
	_respawn_position = checkpoint.get("position", active_checkpoint.get_respawn_position()) as Vector2
	_respawn_past_delay_seconds = saved_delay
	_respawn_delay_switch_id = saved_switch_id
	active_checkpoint.set_active(true, false)
	player.reset_player(_respawn_position)
	timeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)


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
	for authored_checkpoint in _checkpoints:
		authored_checkpoint.set_active(authored_checkpoint == checkpoint, authored_checkpoint == checkpoint)
	_respawn_position = checkpoint.get_respawn_position()
	_respawn_past_delay_seconds = timeline.get_selected_past_delay_seconds()
	_respawn_delay_switch_id = timeline.get_selected_delay_switch_id()
	LevelModule.instance.set_checkpoint(
		checkpoint_scene_path,
		String(checkpoint.get_checkpoint_id()),
		_respawn_position,
		_respawn_past_delay_seconds,
		String(_respawn_delay_switch_id)
	)
	SaveSystem.save_slot(1)


# 过去体抓到玩家时播放失败反馈并排入复位。
func _on_player_caught() -> void:
	_begin_failure_reset(&"hit")


# 玩家 Hurtbox 和过去体共用带动画语义的 checkpoint 失败入口。
func _on_player_failure_requested(animation_name: StringName) -> void:
	_begin_failure_reset(animation_name)


# 只有当前玩家进入 authored 出界区域时才触发跌落复位。
func _on_fall_reset_body_entered(body: Node2D) -> void:
	if body != player:
		return
	_begin_failure_reset(&"death")


# 冻结玩家 0.4 秒，然后先恢复坐标、再清空时间线。
func _begin_failure_reset(animation_name: StringName) -> void:
	if _reset_in_progress:
		return
	_reset_in_progress = true
	player.prepare_for_reset(animation_name)
	reset_audio.play()
	await get_tree().create_timer(RESET_DELAY_SECONDS).timeout
	player.reset_player(_respawn_position)
	timeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)
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
	timeline.reset_timeline(_respawn_past_delay_seconds, _respawn_delay_switch_id)


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
	SceneManager.change_scene_to_file(menu_scene_path)
