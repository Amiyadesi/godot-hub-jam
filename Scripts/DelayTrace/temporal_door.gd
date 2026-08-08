class_name TemporalDoor
extends StaticBody2D
## 监听最多四块 authored 压力板的标准时间门。

enum Mode {
	MOMENTARY_ALL,
	LATCHED_ALL,
}

@export var mode: Mode = Mode.MOMENTARY_ALL
@export var source_plates: Array[TemporalPressurePlate] = []
@export var latched_door_id: StringName
@export var close_on_checkpoint := false

const MOMENTARY_CLOSED_COLOR := Color(0.92, 0.34, 0.32, 0.88)
const MOMENTARY_OPEN_COLOR := Color(1.0, 0.58, 0.34, 0.44)
const LATCHED_CLOSED_COLOR := Color(0.52, 0.36, 0.86, 0.92)
const LATCHED_OPEN_COLOR := Color(0.52, 0.86, 1.0, 0.38)

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: CanvasItem = %Visual
@onready var mode_label: Label = %ModeLabel
@onready var indicator_roots: Array[Node2D] = [
	$Indicators/IndicatorA,
	$Indicators/IndicatorB,
	$Indicators/IndicatorC,
	$Indicators/IndicatorD,
]
@onready var indicator_fills: Array[CanvasItem] = [
	$Indicators/IndicatorA/Fill,
	$Indicators/IndicatorB/Fill,
	$Indicators/IndicatorC/Fill,
	$Indicators/IndicatorD/Fill,
]
@onready var open_audio: AudioStreamPlayer2D = %OpenAudio
@onready var close_audio: AudioStreamPlayer2D = %CloseAudio

var _is_open := false
var _latched := false
var _checkpoint_closed := false


# 连接显式来源，并从当前板状态应用门与指示格。
func _ready() -> void:
	assert(source_plates.size() <= 4, "TemporalDoor supports at most four source plates")
	for plate in source_plates:
		assert(plate != null, "TemporalDoor source_plates cannot contain null")
		plate.pressed_changed.connect(_on_source_pressed_changed)
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	_refresh_mode_label()
	_checkpoint_closed = (
		mode == Mode.LATCHED_ALL
		and not latched_door_id.is_empty()
		and LevelModule.instance != null
		and LevelModule.instance.is_latched_door_closed(String(latched_door_id))
	)
	if _checkpoint_closed:
		_update_indicators(false)
		set_open(false, false)
		return
	if (
		mode == Mode.LATCHED_ALL
		and not latched_door_id.is_empty()
		and LevelModule.instance != null
		and LevelModule.instance.is_latched_door_open(String(latched_door_id))
	):
		_latched = true
		_update_indicators(true)
		set_open(true, false)
		return
	_refresh_state()


# Refreshes the authored mode label after a runtime language change.
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "language":
		_refresh_mode_label()


# Names the two door contracts without relying on color alone.
func _refresh_mode_label() -> void:
	mode_label.text = tr("DOOR_MODE_LATCHED" if mode == Mode.LATCHED_ALL else "DOOR_MODE_MOMENTARY")


# 任一压力板变化时重新计算全部输入。
func _on_source_pressed_changed(_is_pressed: bool) -> void:
	_refresh_state()


# Momentary 跟随实时输入；Latched 首次全满足后保持开启。
func _refresh_state() -> void:
	if _checkpoint_closed:
		_update_indicators(false)
		set_open(false)
		return
	var all_pressed := _are_all_sources_pressed()
	if mode == Mode.LATCHED_ALL and all_pressed:
		_latch()
	_update_indicators(all_pressed)
	set_open(_latched if mode == Mode.LATCHED_ALL else all_pressed)


# Marks a Latched ALL door in memory; the current checkpoint commits it.
func _latch() -> void:
	if _latched or _checkpoint_closed:
		return
	if (
		not latched_door_id.is_empty()
		and LevelModule.instance != null
		and not LevelModule.instance.open_latched_door(String(latched_door_id))
	):
		return
	_latched = true


# Restores this door from committed checkpoint progress after a reset.
func restore_checkpoint_state() -> void:
	_checkpoint_closed = (
		mode == Mode.LATCHED_ALL
		and not latched_door_id.is_empty()
		and LevelModule.instance != null
		and LevelModule.instance.is_latched_door_closed(String(latched_door_id))
	)
	if _checkpoint_closed:
		_latched = false
		_update_indicators(false)
		set_open(false, false)
		return
	_latched = (
		mode == Mode.LATCHED_ALL
		and not latched_door_id.is_empty()
		and LevelModule.instance != null
		and LevelModule.instance.is_latched_door_open(String(latched_door_id))
	)
	var all_pressed := _are_all_sources_pressed()
	_update_indicators(all_pressed)
	set_open(_latched if mode == Mode.LATCHED_ALL else all_pressed, false)


# Closes and persists this authored door when its checkpoint is activated.
func close_at_checkpoint() -> void:
	if not close_on_checkpoint or mode != Mode.LATCHED_ALL:
		return
	if not _latched and not _is_open:
		return
	_checkpoint_closed = true
	_latched = false
	if not latched_door_id.is_empty() and LevelModule.instance != null:
		LevelModule.instance.close_latched_door(String(latched_door_id))
	_update_indicators(false)
	set_open(false)

# 只有存在来源且每块板都按下时才算满足。
func _are_all_sources_pressed() -> bool:
	if source_plates.is_empty():
		return false
	for plate in source_plates:
		if not plate.is_pressed():
			return false
	return true


# 显示已接线的 authored 指示格及其当前满足状态。
func _update_indicators(all_pressed: bool) -> void:
	for index in indicator_roots.size():
		var connected := index < source_plates.size()
		indicator_roots[index].visible = connected
		indicator_fills[index].visible = connected and (
			_latched or source_plates[index].is_pressed()
		)
		if connected:
			indicator_fills[index].modulate = _mode_color(_latched or all_pressed)


# 开闭物理通路、状态颜色与开关音效，并向关卡脚本暴露清晰状态。
func set_open(value: bool, play_feedback := true) -> void:
	var changed := _is_open != value
	_is_open = value
	if changed and play_feedback:
		collision_shape.set_deferred("disabled", value)
		(open_audio if value else close_audio).play()
	elif changed:
		collision_shape.set_deferred("disabled", value)
	visual.modulate = _mode_color(value)


# 返回当前门模式在关闭或打开时使用的基础色。
func _mode_color(open: bool) -> Color:
	if mode == Mode.LATCHED_ALL:
		return LATCHED_OPEN_COLOR if open else LATCHED_CLOSED_COLOR
	return MOMENTARY_OPEN_COLOR if open else MOMENTARY_CLOSED_COLOR


# 向外部关卡逻辑报告当前障碍状态。
func is_open() -> bool:
	return _is_open
