class_name RemoteArrivalVfx
extends Node2D
## Object-local shader and outline feedback for delayed remote state arrivals.

@export var visual_group_path: NodePath = ^"../VisualGroup"

var _events: Array[EntanglementEvent] = []
var _active_sequence: int = -1
var _progress_value: float = 0.0
var _progress_tween: Tween
var _arrival_tween: Tween
var _low_flash_mode: bool = false

@onready var visual_group: CanvasItem = get_node(visual_group_path)
@onready var arrival_flash: Polygon2D = $ArrivalFlash
@onready var arrival_outline: Line2D = $ArrivalOutline
@onready var send_audio: AudioStreamPlayer2D = $SendAudio
@onready var arrival_audio: AudioStreamPlayer2D = $ArrivalAudio


# Resolves the authored group material and follows the persisted flash preference.
func _ready() -> void:
	if not (visual_group.material is ShaderMaterial):
		push_error("RemoteArrivalVfx requires a ShaderMaterial on %s" % visual_group.get_path())
		return
	set_low_flash_mode(_read_low_flash_mode())
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	_reset_material()


# Adds one matching future event in deterministic arrival and sequence order.
func enqueue_event(event: EntanglementEvent) -> void:
	_events.append(event.copy())
	_events.sort_custom(_event_arrives_first)
	send_audio.play()
	_refresh_active_event()


# Removes one arrived event and plays its restrained target-local completion flash.
func complete_event(event: EntanglementEvent) -> void:
	for index: int in range(_events.size()):
		if _events[index].sequence == event.sequence:
			_events.remove_at(index)
			break
	arrival_audio.play()
	_play_arrival(event)
	_active_sequence = -1
	_refresh_active_event()


# Removes one cancelled arrival without playing completion feedback.
func cancel_event(event: EntanglementEvent) -> void:
	for index: int in range(_events.size()):
		if _events[index].sequence == event.sequence:
			_events.remove_at(index)
			break
	if event.sequence == _active_sequence:
		_active_sequence = -1
	_refresh_active_event()


# Clears every pending visual without changing the real entity state.
func clear_events() -> void:
	_events.clear()
	_active_sequence = -1
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	if _arrival_tween != null and _arrival_tween.is_valid():
		_arrival_tween.kill()
	arrival_flash.visible = false
	arrival_outline.visible = false
	send_audio.stop()
	arrival_audio.stop()
	_reset_material()


# Switches rapid flicker and bright arrival peaks to stable outlines and slow pulses.
func set_low_flash_mode(value: bool) -> void:
	_low_flash_mode = value
	var material := visual_group.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("low_flash_mode", value)


# Reports queued visuals for deterministic headless coverage.
func pending_count() -> int:
	return _events.size()


# Reports the event currently driving the shared group shader.
func active_sequence() -> int:
	return _active_sequence


# Reports the latest normalized progress written to the shader.
func active_progress() -> float:
	return _progress_value


# Restarts the group shader only when the earliest queued event changes.
func _refresh_active_event() -> void:
	if _events.is_empty():
		_active_sequence = -1
		_reset_material()
		return
	var event: EntanglementEvent = _events[0]
	if event.sequence == _active_sequence:
		return
	_active_sequence = event.sequence
	_start_progress(event)


# Drives exact sent-to-arrival duration through a pausable Tween.
func _start_progress(event: EntanglementEvent) -> void:
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	var duration: float = maxf(event.arrival_time - event.sent_time, 0.0)
	var elapsed: float = maxf(EntanglementBus.current_time - event.sent_time, 0.0)
	var start_progress: float = 1.0 if is_zero_approx(duration) else clampf(elapsed / duration, 0.0, 1.0)
	var remaining: float = maxf(event.arrival_time - EntanglementBus.current_time, 0.0)
	var material := visual_group.material as ShaderMaterial
	material.set_shader_parameter("event_kind", _event_kind(event.event_type))
	material.set_shader_parameter("source_tint", _source_color(event.source_side))
	material.set_shader_parameter("effect_strength", 0.78 if not _low_flash_mode else 0.48)
	_set_progress(start_progress)
	if is_zero_approx(remaining):
		return
	_progress_tween = create_tween()
	_progress_tween.tween_method(_set_progress, start_progress, 1.0, remaining)


# Writes one normalized progress sample into the target CanvasGroup material.
func _set_progress(value: float) -> void:
	_progress_value = clampf(value, 0.0, 1.0)
	var material := visual_group.material as ShaderMaterial
	material.set_shader_parameter("progress", _progress_value)


# Plays a compact outline and pixel block burst at the real arrival moment.
func _play_arrival(event: EntanglementEvent) -> void:
	if _arrival_tween != null and _arrival_tween.is_valid():
		_arrival_tween.kill()
	var color := _source_color(event.source_side)
	arrival_outline.default_color = Color(color, 0.82 if not _low_flash_mode else 0.58)
	arrival_flash.color = Color(color, 0.46 if not _low_flash_mode else 0.2)
	arrival_outline.visible = true
	arrival_flash.visible = true
	arrival_outline.modulate.a = 1.0
	arrival_flash.modulate.a = 1.0
	arrival_flash.scale = Vector2(0.45, 0.45)
	var duration: float = 0.2 if not _low_flash_mode else 0.42
	_arrival_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arrival_tween.parallel().tween_property(arrival_flash, ^"scale", Vector2.ONE, duration)
	_arrival_tween.parallel().tween_property(arrival_flash, ^"modulate:a", 0.0, duration)
	_arrival_tween.parallel().tween_property(arrival_outline, ^"modulate:a", 0.0, duration + 0.12)
	_arrival_tween.tween_callback(arrival_flash.hide)
	_arrival_tween.tween_callback(arrival_outline.hide)


# Restores the shared object material after its local queue becomes empty.
func _reset_material() -> void:
	_progress_value = 0.0
	var material := visual_group.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("effect_strength", 0.0)
	material.set_shader_parameter("low_flash_mode", _low_flash_mode)


# Maps the three legal causality contracts to shader branches.
func _event_kind(event_type: StringName) -> int:
	match event_type:
		EntanglementBus.FORM_CHANGED:
			return 1
		EntanglementBus.DESTROYED:
			return 2
		_:
			return 0


# Returns the cold or warm source-space color used by every transfer effect.
func _source_color(source_side: int) -> Color:
	return Color(0.36, 0.98, 0.9, 1.0) if source_side == EntangledEntity.Side.LU_HENG else Color(1.0, 0.42, 0.18, 1.0)


# Orders multiple visuals by the same contract as the deterministic bus.
func _event_arrives_first(a: EntanglementEvent, b: EntanglementEvent) -> bool:
	if is_equal_approx(a.arrival_time, b.arrival_time):
		return a.sequence < b.sequence
	return a.arrival_time < b.arrival_time


# Reads the accessibility flag without requiring save modules in isolated tests.
func _read_low_flash_mode() -> bool:
	return bool(SettingsModule.instance.get_value("low_flash_mode", false)) if SettingsModule.instance != null else false


# Applies live accessibility changes to an already queued target effect.
func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "low_flash_mode":
		set_low_flash_mode(bool(value))
