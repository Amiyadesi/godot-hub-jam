class_name DelayedPowerBreaker
extends Node2D
## World-mounted breaker that sends one delayed, latched door signal.

signal activated(event: EntanglementEvent)

const OFF_COLOR := Color(0.24, 0.34, 0.35, 0.9)
const READY_COLOR := Color(0.34, 1.0, 0.78, 1.0)
const SENT_COLOR := Color(1.0, 0.56, 0.22, 1.0)

@export var output_link_id: StringName = &"ch1_r1_door"
@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.LU_HENG
@export_range(0.0, 8.0, 0.1, "suffix:s") var relay_delay_seconds: float = 3.0

var _activated: bool = false
var _feedback_tween: Tween

@onready var breaker_handle: Node2D = $BreakerHandle
@onready var ready_lamp: Polygon2D = $ReadyLamp
@onready var output_lamp: Polygon2D = $OutputLamp
@onready var pulse_ring: Line2D = $PulseRing
@onready var status_light: PointLight2D = $StatusLight
@onready var activation_audio: AudioStreamPlayer2D = $ActivationAudio
@onready var interaction_prompt: WorldInteractionPrompt = $InteractionPrompt


# Registers the authored reset hook and presents the idle breaker pose.
func _ready() -> void:
	if output_link_id.is_empty():
		push_error("DelayedPowerBreaker requires a non-empty output_link_id")
	EntanglementBus.queue_reset.connect(_on_queue_reset)
	breaker_handle.rotation = -0.28
	pulse_ring.visible = false
	_update_visual()


# Allows the player to pull this physical breaker exactly once per room state.
func can_activate() -> bool:
	return not _activated and not output_link_id.is_empty()


# Shows the nearby J action only before this one-shot breaker has been pulled.
func set_interaction_prompt_active(active: bool) -> void:
	if active and can_activate():
		interaction_prompt.show_prompt("J 操作")
	else:
		interaction_prompt.hide_prompt()


# Sends the delayed door edge directly from the physical breaker.
func activate() -> bool:
	if not can_activate():
		return false
	var event := EntanglementBus.emit_event(
		output_link_id,
		EntanglementBus.POWER_CHANGED,
		{"value": true, "output_id": &"r1_breaker"},
		side,
		relay_delay_seconds
	)
	if event == null:
		return false
	_activated = true
	activation_audio.play()
	_play_activation_feedback()
	_update_visual()
	activated.emit(event)
	return true


# Restores the authored ready state whenever the room timeline is reset.
func _on_queue_reset() -> void:
	_activated = false
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	breaker_handle.rotation = -0.28
	pulse_ring.visible = false
	_update_visual()


# Animates only authored handle, lights, and pulse feedback nodes.
func _play_activation_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	pulse_ring.visible = true
	pulse_ring.scale = Vector2(0.7, 0.7)
	pulse_ring.modulate.a = 0.9
	_feedback_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(breaker_handle, ^"rotation", 0.28, 0.18)
	_feedback_tween.parallel().tween_property(pulse_ring, ^"scale", Vector2(1.65, 1.65), 0.34)
	_feedback_tween.parallel().tween_property(pulse_ring, ^"modulate:a", 0.0, 0.34)
	_feedback_tween.tween_callback(pulse_ring.hide)


# Distinguishes a ready breaker from one whose delayed edge is travelling.
func _update_visual() -> void:
	if not is_node_ready():
		return
	var color := SENT_COLOR if _activated else (READY_COLOR if can_activate() else OFF_COLOR)
	ready_lamp.color = color
	output_lamp.color = SENT_COLOR if _activated else OFF_COLOR
	status_light.color = color
	status_light.energy = 0.62 if _activated else (0.4 if can_activate() else 0.12)
