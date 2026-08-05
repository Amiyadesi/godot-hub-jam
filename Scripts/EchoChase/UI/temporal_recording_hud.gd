class_name TemporalRecordingHUD
extends Control
## 未来录像的 authored HUD：只显示进度、回传键和金色时间反馈。

@export var player: EchoPlayer

@onready var screen_edge: ColorRect = %ScreenEdge
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var recall_key_label: Label = %RecallKeyLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer


# 监听全局录像状态、按键与低闪烁设置。
func _ready() -> void:
	EchoTimeline.future_recording_started.connect(_on_recording_started)
	EchoTimeline.future_recording_progress.connect(_on_recording_progress)
	EchoTimeline.future_recording_finished.connect(_on_recording_finished)
	if KeybindingModule.instance != null:
		KeybindingModule.instance.bindings_changed.connect(refresh_recall_binding)
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	refresh_recall_binding()
	_set_recording_visible(false)


# 从当前 InputMap 刷新回传键，重绑定后无需重载场景。
func refresh_recall_binding() -> void:
	if OS.has_feature("mobile"):
		recall_key_label.text = "A"
		return
	if KeybindingModule.instance != null:
		recall_key_label.text = KeybindingModule.instance.get_primary_display_string("echo_recall")
		return
	var events := InputMap.action_get_events(&"echo_recall")
	recall_key_label.text = ResourceSerializer.event_to_display_string(events[0]) if not events.is_empty() else tr("INPUT_UNBOUND")


# 返回 HUD 是否正在显示录像状态，供场景验证使用。
func is_recording_visible() -> bool:
	return visible


# 返回当前无数字进度条的归一化进度。
func get_progress_ratio() -> float:
	return progress_bar.value / progress_bar.max_value


# 返回玩家当前看到的回传键文本。
func get_recall_binding_text() -> String:
	return recall_key_label.text


# 录像开始时显示所有 authored 金色反馈。
func _on_recording_started() -> void:
	progress_bar.value = 0.0
	refresh_recall_binding()
	_set_recording_visible(true)


# 使用控制器提供的确定性时长推进0到5秒进度。
func _on_recording_progress(elapsed_seconds: float, maximum_seconds: float) -> void:
	progress_bar.max_value = maximum_seconds
	progress_bar.value = clampf(elapsed_seconds, 0.0, maximum_seconds)


# 回传、自动提交或时间线重置时立即清除录制提示。
func _on_recording_finished() -> void:
	_set_recording_visible(false)


# 低闪烁设置变化时切换为稳定金边，不重新开始录像。
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "low_flash_mode" and visible:
		_play_recording_animation(true)
		player.set_recording_feedback(true, _uses_low_flash_mode(), true)


# 同步 HUD 与玩家轮廓的可见状态。
func _set_recording_visible(value: bool) -> void:
	visible = value
	player.set_recording_feedback(value, _uses_low_flash_mode())
	if value:
		_play_recording_animation(false)
	else:
		animation_player.play(&"RESET")


# 根据低闪烁设置选择脉冲或稳定 authored 动画，并按需保留进度。
func _play_recording_animation(preserve_progress: bool) -> void:
	var progress_ratio := 0.0
	if preserve_progress and animation_player.current_animation_length > 0.0:
		progress_ratio = animation_player.current_animation_position / animation_player.current_animation_length
	animation_player.play(&"recording_reduced" if _uses_low_flash_mode() else &"recording")
	if preserve_progress:
		animation_player.seek(progress_ratio * animation_player.current_animation_length, true)


# 读取当前低闪烁开关。
func _uses_low_flash_mode() -> bool:
	return SettingsModule.instance != null and bool(SettingsModule.instance.get_value("low_flash_mode", false))
