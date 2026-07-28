class_name PhaseAnchorEmitter
extends Area2D
## Authored Lu Heng anchor that sends one delayed exit event after a successful capture.

signal anchor_sent(event: EntanglementEvent)

@export var capture_path: NodePath
@export var link_id: StringName = &""
@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.LU_HENG
@export_range(0.0, 6.0, 0.1, "suffix:s") var delay_seconds: float = 3.0

var _sent: bool = false

@onready var capture: Variant = get_node(capture_path)
@onready var ring: Line2D = $VisualGroup/Ring
@onready var core: Sprite2D = $VisualGroup/Core
@onready var status_light: PointLight2D = $StatusLight
@onready var send_particles: GPUParticles2D = $SendParticles
@onready var send_audio: AudioStreamPlayer2D = $SendAudio


# Validates the authored capture reference and listens for the Lu Heng player.
func _ready() -> void:
	if capture == null or link_id.is_empty():
		push_error("PhaseAnchorEmitter requires a capture device and non-empty link_id")
		return
	body_entered.connect(_on_body_entered)
	capture.capture_changed.connect(_on_capture_changed)
	_update_visual()


# Sends one three-second anchor event only after the capture latch is ready.
func _on_body_entered(body: Node2D) -> void:
	var player := body as PhasePlayer
	try_activate(player)


# Activates the anchor for one eligible Lu Heng player and returns its causal event.
func try_activate(player: PhasePlayer) -> EntanglementEvent:
	if _sent or not capture.captured or player == null or player.role != PhasePlayer.Role.LU_HENG:
		return null
	var event := EntanglementBus.emit_event(
		link_id,
		EntanglementBus.POWER_CHANGED,
		{"value": true, "source": &"phase_anchor"},
		side,
		delay_seconds
	)
	if event == null:
		return null
	_sent = true
	send_particles.restart()
	send_particles.emitting = true
	send_audio.play()
	_update_visual()
	anchor_sent.emit(event)
	return event


# Reveals anchor readiness when the capture device latches successfully.
func _on_capture_changed(_captured: bool) -> void:
	_update_visual()


# Displays locked, ready, and spent states without instructional text.
func _update_visual() -> void:
	if not is_node_ready():
		return
	var ready: bool = capture != null and capture.captured and not _sent
	var color := Color(0.4, 1.0, 0.84, 1.0) if ready else Color(0.2, 0.36, 0.38, 0.62)
	if _sent:
		color = Color(1.0, 0.58, 0.22, 0.82)
	ring.default_color = color
	core.modulate = Color(0.76, 1.0, 0.94, 1.0) if ready else Color(0.56, 0.68, 0.7, 0.82)
	if _sent:
		core.modulate = Color(0.92, 0.64, 0.4, 0.82)
	status_light.color = color
	status_light.energy = 0.9 if ready else (0.48 if _sent else 0.16)
