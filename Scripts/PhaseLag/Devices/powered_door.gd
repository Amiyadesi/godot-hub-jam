class_name PoweredDoor
extends PoweredDevice
## Authored collision door whose open state follows delayed remote power.

signal opened(door: PoweredDoor)
signal closed(door: PoweredDoor)

enum EraStyle {
	FUTURE,
	PAST,
}

@export var open_when_powered: bool = true
@export var latch_open: bool = false
@export_enum("未来加固", "过去烧蚀") var era_style: int = EraStyle.FUTURE

const PANEL_CLOSED_POSITION := Vector2.ZERO
const PANEL_OPEN_POSITION := Vector2(0.0, -100.0)

var is_open: bool = false
var _latched_open: bool = false
var _motion_tween: Tween

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var future_back: Node2D = $BackVisualGroup/BackLayer/FutureDoor
@onready var past_back: Node2D = $BackVisualGroup/BackLayer/PastDoor
@onready var future_front: Node2D = $FrontVisualGroup/FrontLayer/FutureDoor
@onready var past_front: Node2D = $FrontVisualGroup/FrontLayer/PastDoor
@onready var future_panel: Sprite2D = $FrontVisualGroup/FrontLayer/FutureDoor/DoorPanel
@onready var past_panel: Sprite2D = $FrontVisualGroup/FrontLayer/PastDoor/DoorPanel
@onready var door_light: PointLight2D = $DoorLight
@onready var motion_particles: GPUParticles2D = $MotionParticles
@onready var open_audio: AudioStreamPlayer2D = $OpenAudio
@onready var close_audio: AudioStreamPlayer2D = $CloseAudio

var _active_panel: Sprite2D


# Selects one complete sourced door set before the inherited power state is resolved.
func _ready() -> void:
	future_back.visible = era_style == EraStyle.FUTURE
	future_front.visible = era_style == EraStyle.FUTURE
	past_back.visible = era_style == EraStyle.PAST
	past_front.visible = era_style == EraStyle.PAST
	_active_panel = future_panel if era_style == EraStyle.FUTURE else past_panel
	super._ready()


# Opens or closes collision after the stable powered state changes.
func _apply_power_state(value: bool) -> void:
	var should_open := value if open_when_powered else not value
	if latch_open and should_open:
		_latched_open = true
	if latch_open and _latched_open:
		should_open = true
	if is_open == should_open:
		_apply_visual_immediate()
		return
	is_open = should_open
	collision.set_deferred("disabled", is_open)
	_play_door_motion()
	if is_open:
		opened.emit(self)
	else:
		closed.emit(self)


# Clears the permanent-open edge for an explicit authored room reset.
func reset_latch() -> void:
	_latched_open = false
	super.reset_latch()


# Persists an already-open latch inside same-room clean checkpoints.
func capture_persistent_state() -> Dictionary:
	var state := super.capture_persistent_state()
	state["latched_open"] = _latched_open
	return state


# Restores the stable power and latch without replaying a remote event.
func restore_persistent_state(state: Dictionary) -> void:
	_latched_open = bool(state.get("latched_open", false))
	super.restore_persistent_state(state)


# Applies the authored open or closed pose without transition feedback during setup and restore.
func _apply_visual_immediate() -> void:
	if not is_node_ready():
		return
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_active_panel.position = PANEL_OPEN_POSITION if is_open else PANEL_CLOSED_POSITION
	_active_panel.modulate = Color(1.0, 1.0, 1.0, 0.0 if is_open else 1.0)
	door_light.color = _get_status_color(is_open)
	door_light.energy = 0.14 if era_style == EraStyle.PAST else (0.18 if is_open else 0.22)
	motion_particles.emitting = false


# Animates the real mechanical state only after the delayed power edge has arrived.
func _play_door_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	var target_position := PANEL_OPEN_POSITION if is_open else PANEL_CLOSED_POSITION
	var target_alpha := 0.0 if is_open else 1.0
	var target_color := _get_status_color(is_open)
	door_light.color = target_color
	door_light.energy = 0.8
	motion_particles.modulate = Color(target_color, 0.86)
	motion_particles.restart()
	motion_particles.emitting = true
	if is_open:
		open_audio.play()
	else:
		close_audio.play()
	_motion_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_motion_tween.parallel().tween_property(_active_panel, ^"position", target_position, 0.24)
	_motion_tween.parallel().tween_property(_active_panel, ^"modulate:a", target_alpha, 0.24)
	_motion_tween.parallel().tween_property(door_light, ^"energy", 0.14 if era_style == EraStyle.PAST else (0.18 if is_open else 0.22), 0.32)


# Returns the era-specific lock lamp color without changing door state semantics.
func _get_status_color(opened: bool) -> Color:
	if era_style == EraStyle.PAST:
		return Color(1.0, 0.64, 0.22, 0.82) if opened else Color(0.92, 0.18, 0.08, 0.74)
	return Color(0.35, 1.0, 0.74, 0.9) if opened else Color(1.0, 0.34, 0.2, 0.88)
