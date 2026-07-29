class_name DelayPickup
extends Area2D
## 可重复使用的 authored 过去延迟台。

enum State {
	INACTIVE,
	PENDING,
	ACTIVE,
}

@export_enum("1", "3", "5") var delay_seconds := 3
@export var delay_switch_id: StringName = &"delay_3s"
@export var default_active := false
@export var timeline: EchoTimelineController

@onready var delay_label: Label = %DelayLabel
@onready var state_animation_player: AnimationPlayer = %StateAnimationPlayer

var _state := State.INACTIVE


# 校验 authored 合同，并监听时间线的选择状态。
func _ready() -> void:
	assert(timeline != null, "DelayPickup requires an authored EchoTimelineController reference")
	assert(not delay_switch_id.is_empty(), "DelayPickup requires a delay_switch_id")
	delay_label.text = "%d" % delay_seconds
	body_entered.connect(_on_body_entered)
	timeline.past_delay_switch_started.connect(_on_past_delay_switch_started)
	timeline.past_delay_changed.connect(_on_past_delay_changed)
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	_set_state(State.ACTIVE if default_active else State.INACTIVE)


# 玩家触碰时请求切档，节点始终留在场景中。
func _on_body_entered(body: Node2D) -> void:
	if body != timeline.player:
		return
	timeline.request_past_delay(float(delay_seconds), delay_switch_id)


# 新选择出现时只让目标延迟台显示预警环。
func _on_past_delay_switch_started(_seconds: float, switch_id: StringName) -> void:
	_set_state(State.PENDING if switch_id == delay_switch_id else State.INACTIVE)


# 切档完成后只保留当前延迟台的稳定激活环。
func _on_past_delay_changed(_seconds: float, switch_id: StringName) -> void:
	_set_state(State.ACTIVE if switch_id == delay_switch_id else State.INACTIVE)


# 返回该台是否处于稳定激活状态。
func is_active() -> bool:
	return _state == State.ACTIVE


# 返回该台是否正在等待切档抵达。
func is_pending() -> bool:
	return _state == State.PENDING


# 返回 authored 唯一 ID，供场景控制器校验和存档。
func get_delay_switch_id() -> StringName:
	return delay_switch_id


# 通过 authored 动画切换视觉状态，不在脚本中拼装样式。
func _set_state(value: State) -> void:
	_state = value
	_play_state_animation(false)


# 当前延迟台切换低闪时只替换已有状态动画。
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "low_flash_mode" and _state != State.INACTIVE:
		_play_state_animation(true)


# 在同一状态的标准与稳定动画之间保留归一化进度。
func _play_state_animation(preserve_progress: bool) -> void:
	var progress_ratio := 0.0
	if preserve_progress and state_animation_player.current_animation_length > 0.0:
		progress_ratio = state_animation_player.current_animation_position / state_animation_player.current_animation_length
	match _state:
		State.INACTIVE:
			state_animation_player.play(&"inactive")
		State.PENDING:
			state_animation_player.play(&"pending_reduced" if _uses_low_flash_mode() else &"pending")
		State.ACTIVE:
			state_animation_player.play(&"active_reduced" if _uses_low_flash_mode() else &"active")
	if preserve_progress:
		state_animation_player.seek(progress_ratio * state_animation_player.current_animation_length, true)


# 读取全局低闪烁偏好，缺少模块时使用正常表现。
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
