class_name EntanglementPulseEmitter
extends Node2D
## Authored Lu Heng device that schedules one delayed off window and deterministic recovery.

signal pulse_started(shutdown_arrival: float, restore_arrival: float)
signal ready_changed(ready: bool)

@export var link_id: StringName = &""
@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.LU_HENG
@export_range(0.0, 12.0, 0.1, "suffix:s") var shutdown_delay: float = 3.0
@export_range(0.1, 12.0, 0.1, "suffix:s") var disabled_window: float = 6.0

var _busy_until: float = -1.0
var _was_ready: bool = true

@onready var lever: Polygon2D = $VisualGroup/Lever
@onready var status_light: Polygon2D = $VisualGroup/StatusLight
@onready var pulse_ring: Line2D = $VisualGroup/PulseRing
@onready var pulse_light: PointLight2D = $PulseLight
@onready var discharge_particles: GPUParticles2D = $DischargeParticles
@onready var activation_audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var interaction_prompt: WorldInteractionPrompt = $VisualGroup/InteractionPrompt


# Registers timeline reset handling and applies the authored idle pose.
func _ready() -> void:
	EntanglementBus.queue_reset.connect(_on_queue_reset)
	_update_visual(true)


# Refreshes readiness and the slow nonverbal cooldown ring from bus time.
func _process(_delta: float) -> void:
	_refresh_ready_state()
	_update_visual(can_activate())


# Queues armor shutdown and recovery as two ordered power events.
func activate() -> bool:
	_refresh_ready_state()
	if not can_activate():
		return false
	if link_id.is_empty():
		push_error("EntanglementPulseEmitter requires a non-empty link_id")
		return false
	var shutdown_event := EntanglementBus.emit_event(
		link_id,
		EntanglementBus.POWER_CHANGED,
		{"value": false, "pulse_phase": &"shutdown"},
		side,
		shutdown_delay
	)
	var restore_event := EntanglementBus.emit_event(
		link_id,
		EntanglementBus.POWER_CHANGED,
		{"value": true, "pulse_phase": &"restore"},
		side,
		shutdown_delay + disabled_window
	)
	if shutdown_event == null or restore_event == null:
		return false
	_busy_until = restore_event.arrival_time
	_set_ready(false)
	_play_activation_feedback()
	pulse_started.emit(shutdown_event.arrival_time, restore_event.arrival_time)
	return true


# Reports whether the current timeline has completed the previous recovery event.
func can_activate() -> bool:
	return _busy_until < 0.0 or EntanglementBus.current_time >= _busy_until


# Shows the nearby J action only after the previous pulse has fully recovered.
func set_interaction_prompt_active(active: bool) -> void:
	if active and can_activate():
		interaction_prompt.show_prompt("J 操作")
	else:
		interaction_prompt.hide_prompt()


# Clears transient ownership when the active room or timeline is reset.
func reset_pulse() -> void:
	_busy_until = -1.0
	_set_ready(true)
	_update_visual(true)


# Promotes an elapsed deterministic recovery time back to interactable state.
func _refresh_ready_state() -> void:
	if _busy_until >= 0.0 and EntanglementBus.current_time >= _busy_until:
		_busy_until = -1.0
		_set_ready(true)


# Emits a readiness transition only when the stable state actually changes.
func _set_ready(value: bool) -> void:
	if _was_ready == value:
		return
	_was_ready = value
	ready_changed.emit(value)


# Resets this device alongside all in-flight causal changes.
func _on_queue_reset() -> void:
	reset_pulse()


# Animates only authored visual nodes and leaves event timing on EntanglementBus.
func _play_activation_feedback() -> void:
	activation_audio.play()
	discharge_particles.restart()
	discharge_particles.emitting = true
	lever.rotation = -0.72
	pulse_ring.visible = true
	pulse_ring.scale = Vector2(0.55, 0.55)
	pulse_ring.modulate.a = 0.9
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lever, ^"rotation", 0.72, 0.18)
	tween.parallel().tween_property(pulse_ring, ^"scale", Vector2(1.8, 1.8), 0.34)
	tween.parallel().tween_property(pulse_ring, ^"modulate:a", 0.0, 0.34)
	tween.tween_callback(pulse_ring.hide)


# Displays ready, travelling, and recovery states without text or countdowns.
func _update_visual(ready: bool) -> void:
	if not is_node_ready():
		return
	status_light.color = Color(0.38, 1.0, 0.76, 1.0) if ready else Color(1.0, 0.5, 0.2, 0.92)
	pulse_light.color = Color(0.32, 1.0, 0.82, 1.0) if ready else Color(1.0, 0.42, 0.12, 1.0)
	pulse_light.energy = 0.3 if ready else 0.54
	if ready or _busy_until <= EntanglementBus.current_time:
		pulse_ring.visible = false
		return
	var total := shutdown_delay + disabled_window
	var remaining := _busy_until - EntanglementBus.current_time
	var progress := clampf(1.0 - remaining / maxf(total, 0.001), 0.0, 1.0)
	pulse_ring.visible = true
	pulse_ring.scale = Vector2.ONE * lerpf(1.45, 0.72, progress)
	pulse_ring.modulate.a = 0.26
