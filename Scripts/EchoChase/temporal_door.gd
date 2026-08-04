class_name TemporalDoor
extends StaticBody2D
## 监听最多三块 authored 压力板的标准时间门。

enum Mode {
	MOMENTARY_ALL,
	LATCHED_ALL,
}

@export var mode: Mode = Mode.MOMENTARY_ALL
@export var source_plates: Array[TemporalPressurePlate] = []
@export var latched_door_id: StringName

const MOMENTARY_CLOSED_COLOR := Color(0.92, 0.34, 0.32, 0.88)
const MOMENTARY_OPEN_COLOR := Color(1.0, 0.58, 0.34, 0.44)
const LATCHED_CLOSED_COLOR := Color(0.52, 0.36, 0.86, 0.92)
const LATCHED_OPEN_COLOR := Color(0.52, 0.86, 1.0, 0.38)

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: CanvasItem = %Visual
@onready var indicator_roots: Array[Node2D] = [
	$Indicators/IndicatorA,
	$Indicators/IndicatorB,
	$Indicators/IndicatorC,
]
@onready var indicator_fills: Array[CanvasItem] = [
	$Indicators/IndicatorA/Fill,
	$Indicators/IndicatorB/Fill,
	$Indicators/IndicatorC/Fill,
]
@onready var open_audio: AudioStreamPlayer2D = %OpenAudio
@onready var close_audio: AudioStreamPlayer2D = %CloseAudio

var _is_open := false
var _latched := false


# 连接显式来源，并从当前板状态应用门与指示格。
func _ready() -> void:
	assert(source_plates.size() <= 3, "TemporalDoor supports at most three source plates")
	for plate in source_plates:
		assert(plate != null, "TemporalDoor source_plates cannot contain null")
		plate.pressed_changed.connect(_on_source_pressed_changed)
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


# 任一压力板变化时重新计算全部输入。
func _on_source_pressed_changed(_is_pressed: bool) -> void:
	_refresh_state()


# Momentary 跟随实时输入；Latched 首次全满足后保持开启。
func _refresh_state() -> void:
	var all_pressed := _are_all_sources_pressed()
	if mode == Mode.LATCHED_ALL and all_pressed:
		_latch()
	_update_indicators(all_pressed)
	set_open(_latched if mode == Mode.LATCHED_ALL else all_pressed)


# Marks a Latched ALL door in memory; the current checkpoint commits it.
func _latch() -> void:
	if _latched:
		return
	_latched = true
	if latched_door_id.is_empty() or LevelModule.instance == null:
		return
	if not LevelModule.instance.open_latched_door(String(latched_door_id)):
		return


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
