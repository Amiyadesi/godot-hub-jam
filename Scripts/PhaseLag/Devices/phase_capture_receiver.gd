class_name PhaseCaptureReceiver
extends EntangledEntity
## Powered receiver that latches one arriving destroyed event during its authored window.

signal power_changed(powered: bool)
signal capture_changed(captured: bool)

var powered: bool = false
var captured: bool = false

@onready var status_light: PointLight2D = $StatusLight
@onready var power_ring: Line2D = $VisualGroup/PowerRing
@onready var core: Polygon2D = $VisualGroup/Core
@onready var capture_particles: GPUParticles2D = $CaptureParticles
@onready var capture_audio: AudioStreamPlayer2D = $CaptureAudio


# Registers the remote receiver and applies its authored idle state.
func _ready() -> void:
	super._ready()
	_update_visual()


# Applies the same-space circuit output without emitting a causal event.
func set_powered(value: bool) -> void:
	if powered == value:
		return
	powered = value
	_update_visual()
	power_changed.emit(powered)


# Latches only a destroyed event that arrives while the capture field is powered.
func _apply_remote_event(event: EntanglementEvent) -> void:
	if event.event_type != EntanglementBus.DESTROYED or captured or not powered:
		return
	captured = true
	capture_particles.restart()
	capture_particles.emitting = true
	capture_audio.play()
	_update_visual()
	capture_changed.emit(true)


# Shows idle, powered, and latched states through stable authored shapes and light.
func _update_visual() -> void:
	if not is_node_ready():
		return
	var active_color := Color(0.42, 1.0, 0.86, 1.0)
	var idle_color := Color(0.18, 0.35, 0.36, 0.72)
	power_ring.default_color = active_color if powered else idle_color
	core.color = Color(1.0, 0.64, 0.24, 1.0) if captured else (active_color if powered else Color(0.2, 0.3, 0.31, 1.0))
	status_light.color = core.color
	status_light.energy = 1.15 if captured else (0.72 if powered else 0.18)
