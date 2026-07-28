class_name MagneticObject
extends RigidBody2D
## Constrained magnetic maintenance object with snap-socket and free-weight modes.

signal hold_changed(held: bool)
signal snapped(socket: MagneticSocket)
signal unsnapped(socket: MagneticSocket)

enum Mode {
	SNAP_SOCKET,
	FREE_WEIGHT,
}

@export var mode: int = Mode.SNAP_SOCKET
@export var object_kind: StringName = &"battery"
@export var prop_texture: Texture2D
@export var prop_scale: Vector2 = Vector2.ONE
@export var prop_offset: Vector2 = Vector2.ZERO
@export_range(32.0, 320.0, 1.0, "suffix:px") var hold_distance: float = 180.0
@export_range(16.0, 320.0, 1.0, "suffix:px") var snap_distance: float = 220.0
@export_range(32.0, 420.0, 1.0, "suffix:px") var outline_distance: float = 190.0
@export_range(0.1, 8.0, 0.1) var pressure_weight: float = 1.0

var held_by: Node2D
var _snapped_socket: MagneticSocket
var _stored_collision_layer: int = 0
var _stored_collision_mask: int = 0

@onready var status_light: Polygon2D = $VisualGroup/StatusLight
@onready var prop_sprite: Sprite2D = $VisualGroup/PropSprite
@onready var outline_material: ShaderMaterial = prop_sprite.material as ShaderMaterial
@onready var interaction_prompt: WorldInteractionPrompt = $VisualGroup/InteractionPrompt


# Registers the authored magnetic target and remembers its normal collision contract.
func _ready() -> void:
	add_to_group("magnetic_objects")
	_stored_collision_layer = collision_layer
	_stored_collision_mask = collision_mask
	_update_visual()


# Keeps a held object at range and refreshes the authored proximity outline.
func _physics_process(_delta: float) -> void:
	if held_by != null:
		var direction: float = held_by.facing if held_by is PhasePlayer else 1.0
		global_position = held_by.global_position + Vector2(direction * hold_distance, -30.0)
		reset_physics_interpolation()
	_update_outline()


# Begins a constrained hold and detaches the object from any equipment socket.
func begin_magnetic_hold(holder: Node2D) -> bool:
	if holder == null or not can_begin_magnetic_hold():
		return false
	if _snapped_socket != null:
		var previous_socket := _snapped_socket
		previous_socket.release_object()
	held_by = holder
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	gravity_scale = 0.0
	collision_layer = 0
	collision_mask = 0
	_update_visual()
	hold_changed.emit(true)
	return true


# Reports whether the object is currently available for Lu Heng to pick up.
func can_begin_magnetic_hold() -> bool:
	return held_by == null


# Shows only the pickup or carried-object action selected by the tool controller.
func set_interaction_prompt_active(active: bool) -> void:
	if not active:
		interaction_prompt.hide_prompt()
		return
	interaction_prompt.show_prompt("J 放下 · K 旋转" if held_by != null else "J 拿起")


# Ends a hold, preferring a matching nearby socket only for snap-mode objects.
func end_magnetic_hold() -> void:
	if held_by == null:
		return
	held_by = null
	if mode == Mode.SNAP_SOCKET:
		var socket := _find_nearest_socket()
		if socket != null and socket.try_snap(self):
			hold_changed.emit(false)
			return
	_restore_free_physics()
	_update_visual()
	hold_changed.emit(false)


# Rotates one held maintenance object clockwise by exactly ninety degrees.
func rotate_held_clockwise() -> bool:
	if held_by == null:
		return false
	rotation = snappedf(rotation + PI * 0.5, PI * 0.5)
	return true


# Completes one accepted equipment snap without using generic inventory logic.
func complete_snap(socket: MagneticSocket) -> void:
	held_by = null
	_snapped_socket = socket
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	gravity_scale = 0.0
	collision_layer = 0
	collision_mask = 0
	global_position = socket.global_position
	rotation = socket.global_rotation
	reset_physics_interpolation()
	_update_visual()
	snapped.emit(socket)


# Restores physics after its owning authored socket explicitly releases it.
func release_from_socket(socket: MagneticSocket) -> void:
	if _snapped_socket != socket:
		return
	_snapped_socket = null
	_restore_free_physics()
	_update_visual()
	unsnapped.emit(socket)


# Returns the stable socket reference used by equipment and tests.
func get_snapped_socket() -> MagneticSocket:
	return _snapped_socket


# Makes only free-weight objects eligible for authored pressure plates.
func get_pressure_weight() -> float:
	return pressure_weight if mode == Mode.FREE_WEIGHT else 0.0


# Finds the closest compatible socket in the same SubViewport.
func _find_nearest_socket() -> MagneticSocket:
	var nearest: MagneticSocket = null
	var nearest_distance := snap_distance
	for candidate: Node in get_tree().get_nodes_in_group("magnetic_sockets"):
		var socket := candidate as MagneticSocket
		if socket == null or socket.get_viewport() != get_viewport() or not socket.can_accept(self):
			continue
		var distance := global_position.distance_to(socket.global_position)
		if distance <= nearest_distance:
			nearest = socket
			nearest_distance = distance
	return nearest


# Restores gravity and the authored collision layers after hold or socket release.
func _restore_free_physics() -> void:
	freeze = false
	gravity_scale = 1.0
	collision_layer = _stored_collision_layer
	collision_mask = _stored_collision_mask
	sleeping = false


# Shows whether the object is held, installed, or freely physical.
func _update_visual() -> void:
	if not is_node_ready():
		return
	prop_sprite.texture = prop_texture
	prop_sprite.scale = prop_scale
	prop_sprite.position = prop_offset
	if held_by != null:
		status_light.color = Color(0.35, 1.0, 0.82, 0.96)
	elif _snapped_socket != null:
		status_light.color = Color(0.95, 0.78, 0.25, 0.96)
	else:
		status_light.color = Color(0.36, 0.48, 0.5, 0.9)
	_update_outline()


# Reveals magnetic affordance only to a nearby Lu Heng player, strongest while held.
func _update_outline() -> void:
	var strength := 1.0 if held_by != null else 0.0
	if held_by == null:
		for candidate: Node in get_tree().get_nodes_in_group("phase_players"):
			var player := candidate as PhasePlayer
			if (
				player == null
				or player.role != PhasePlayer.Role.LU_HENG
				or not player.controlled
				or player.departed
				or player.get_viewport() != get_viewport()
			):
				continue
			if global_position.distance_to(player.global_position) <= outline_distance:
				strength = 0.62
				break
	outline_material.set_shader_parameter("outline_strength", strength)
