class_name DelayedAirlockLever
extends Node2D
## Physical airlock starter that requires an installed power cell before sending one delayed edge.

signal activated(event: EntanglementEvent)

const OFF_COLOR := Color(0.24, 0.34, 0.35, 0.9)
const READY_COLOR := Color(0.34, 1.0, 0.78, 1.0)
const SENT_COLOR := Color(1.0, 0.56, 0.22, 1.0)

@export var socket_paths: Array[NodePath] = []
@export var conduit_path: NodePath
@export var output_link_id: StringName = &"ch1_r3_airlock"
@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.LU_HENG
@export_range(0.5, 8.0, 0.1, "suffix:s") var relay_delay_seconds: float = 3.0

var _activated: bool = false
var _sockets: Array[MagneticSocket] = []
var _conduit: Line2D
var _activation_tween: Tween

@onready var socket_lamps: Array[Polygon2D] = [$BatteryLamp, $FuseLamp]
@onready var output_lamp: Polygon2D = $OutputLamp
@onready var lever_handle: Node2D = $LeverHandle
@onready var pulse_ring: Line2D = $PulseRing
@onready var status_light: PointLight2D = $StatusLight
@onready var activation_audio: AudioStreamPlayer2D = $ActivationAudio
@onready var interaction_prompt: WorldInteractionPrompt = $InteractionPrompt


# Resolves every authored installation socket and mirrors their initial readiness.
func _ready() -> void:
	if socket_paths.is_empty() or conduit_path.is_empty() or output_link_id.is_empty():
		push_error("DelayedAirlockLever requires authored socket_paths, conduit_path, and output_link_id")
		return
	for socket_path_value: NodePath in socket_paths:
		var socket := get_node(socket_path_value) as MagneticSocket
		if socket == null:
			push_error("DelayedAirlockLever socket_paths must point to MagneticSocket nodes")
			return
		_sockets.append(socket)
		socket.occupied_changed.connect(_on_socket_occupied_changed)
	_conduit = get_node(conduit_path) as Line2D
	if _conduit == null:
		push_error("DelayedAirlockLever conduit_path must point to an authored Line2D")
		return
	lever_handle.rotation = -0.18
	pulse_ring.visible = false
	_update_visual()


# Allows one activation only while every authored installation socket is occupied.
func can_activate() -> bool:
	if _activated or _sockets.is_empty():
		return false
	for socket: MagneticSocket in _sockets:
		if socket.occupied_object == null:
			return false
	return true


# Shows the nearby J action only while the installed parts make the starter usable.
func set_interaction_prompt_active(active: bool) -> void:
	if active and can_activate():
		interaction_prompt.show_prompt("J 操作")
	else:
		interaction_prompt.hide_prompt()


# Pulls the starter and sends one delayed remote airlock edge.
func activate() -> bool:
	if not can_activate():
		return false
	var event := EntanglementBus.emit_event(
		output_link_id,
		EntanglementBus.POWER_CHANGED,
		{"value": true, "output_id": &"airlock_starter"},
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


# Refreshes readiness when the player inserts or removes the physical cell.
func _on_socket_occupied_changed(_occupied: bool) -> void:
	_update_visual()


# Animates only the authored handle, light, and pulse ring.
func _play_activation_feedback() -> void:
	if _activation_tween != null and _activation_tween.is_valid():
		_activation_tween.kill()
	pulse_ring.visible = true
	pulse_ring.scale = Vector2(0.7, 0.7)
	pulse_ring.modulate.a = 0.9
	_activation_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_activation_tween.parallel().tween_property(lever_handle, ^"rotation", 0.18, 0.18)
	_activation_tween.parallel().tween_property(pulse_ring, ^"scale", Vector2(1.6, 1.6), 0.32)
	_activation_tween.parallel().tween_property(pulse_ring, ^"modulate:a", 0.0, 0.32)
	_activation_tween.tween_callback(pulse_ring.hide)


# Distinguishes unpowered, ready, and already-sent states without text.
func _update_visual() -> void:
	if not is_node_ready():
		return
	var ready := can_activate()
	for index in socket_lamps.size():
		var occupied := index < _sockets.size() and _sockets[index].occupied_object != null
		socket_lamps[index].color = SENT_COLOR if _activated else (READY_COLOR if occupied else OFF_COLOR)
	output_lamp.color = SENT_COLOR if _activated else OFF_COLOR
	status_light.color = SENT_COLOR if _activated else (READY_COLOR if ready else OFF_COLOR)
	status_light.energy = 0.62 if _activated else (0.4 if ready else 0.12)
	if _conduit != null:
		_conduit.default_color = SENT_COLOR if _activated else (Color(READY_COLOR, 0.82) if ready else Color(OFF_COLOR, 0.45))
