class_name PhaseRoomSide
extends Node2D
## One authored universe half of a Phase Lag room with stable-state capture helpers.

signal exit_reached(side: int)
signal checkpoint_activated(side: int, checkpoint_id: StringName)

@export var room_id: StringName = &""
@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.LU_HENG
@export var checkpoint_id: StringName = &""
@export_range(1920, 8192, 32, "suffix:px") var room_width_px: int = 1920
@export var world_bounds_px: Rect2 = Rect2(0.0, 0.0, 1920.0, 704.0)
@export var protect_uncontrolled_player: bool = true

var exit_enabled: bool = false
var room_active: bool = false
var departed: bool = false
var _exit_reported: bool = false

@onready var cold_world_art: Node2D = $WorldArt/Cold
@onready var warm_world_art: Node2D = $WorldArt/Warm
@onready var repeated_world_layers: Array[Sprite2D] = [
	$WorldArt/Cold/Back,
	$WorldArt/Cold/FacilityWall,
	$WorldArt/Cold/Foreground,
	$WorldArt/Warm/Back,
	$WorldArt/Warm/FacilityWall,
	$WorldArt/Warm/Foreground,
]
@onready var cold_ambience: Node2D = $Ambience/Cold
@onready var warm_ambience: Node2D = $Ambience/Warm
@onready var cold_wash: Polygon2D = $Ambience/Cold/Wash
@onready var warm_wash: Polygon2D = $Ambience/Warm/Wash
@onready var cold_dust: GPUParticles2D = $Ambience/Cold/Dust
@onready var warm_sparks: GPUParticles2D = $Ambience/Warm/Sparks
@onready var cold_beacon_a: PointLight2D = $Ambience/Cold/BeaconA
@onready var cold_beacon_b: PointLight2D = $Ambience/Cold/BeaconB
@onready var warm_beacon_a: PointLight2D = $Ambience/Warm/BeaconA
@onready var warm_beacon_b: PointLight2D = $Ambience/Warm/BeaconB
@onready var floor_body: StaticBody2D = $StaticGeometry/Floor
@onready var floor_visual: Polygon2D = $StaticGeometry/Floor/Visual
@onready var floor_edge: Polygon2D = $StaticGeometry/Floor/Edge
@onready var floor_collision: CollisionShape2D = $StaticGeometry/Floor/CollisionShape2D
@onready var left_boundary: StaticBody2D = $StaticGeometry/LeftBoundary
@onready var right_boundary: StaticBody2D = $StaticGeometry/RightBoundary
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var phase_anchor: Area2D = $PhaseAnchor
@onready var phase_anchor_visual: Sprite2D = $PhaseAnchor/Visual
@onready var exit_area: Area2D = $Exit
@onready var exit_visual: Sprite2D = $Exit/Visual
@onready var camera_zone: PhaseCameraZone = $CameraZone


# Applies the authored palette and wires this side's exit trigger.
func _ready() -> void:
	_configure_authored_width()
	_apply_authored_palette()
	phase_anchor.body_entered.connect(_on_phase_anchor_body_entered)
	exit_area.body_entered.connect(_on_exit_body_entered)
	set_exit_enabled(false)
	set_room_active(false)


# Overrides the reusable scene identity from its owning room definition.
func configure_identity(new_room_id: StringName, new_side: int, room_width_px: int = 1920) -> void:
	room_id = new_room_id
	side = new_side
	self.room_width_px = room_width_px
	if is_node_ready():
		_configure_authored_width()
		_apply_authored_palette()


# Returns the authored player spawn in room-local world coordinates.
func get_spawn_position() -> Vector2:
	return spawn_point.global_position


# Returns the authored world rectangle that constrains this side's camera.
func get_world_bounds() -> Rect2:
	return Rect2(global_position + world_bounds_px.position, world_bounds_px.size)


# Preserves the camera-facing API while room sides own their world bounds directly.
func get_camera_bounds() -> Rect2:
	return get_world_bounds()


# Fits authored repeated world layers, floor, boundaries, anchor, and exit to the declared room width.
func _configure_authored_width() -> void:
	var width := world_bounds_px.size.x
	var height := world_bounds_px.size.y
	var floor_top := world_bounds_px.end.y - 64.0
	if not is_equal_approx(width, float(room_width_px)):
		push_error("PhaseRoomSide %s bounds width must equal room_width_px" % room_id)
		return
	for layer: Sprite2D in repeated_world_layers:
		var region := layer.region_rect
		region.size.x = width / absf(layer.scale.x)
		layer.region_rect = region
	var ambience_polygon := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(width, 0.0),
		Vector2(width, floor_top), Vector2(0.0, floor_top),
	])
	cold_wash.polygon = ambience_polygon
	warm_wash.polygon = ambience_polygon
	for particles: GPUParticles2D in [cold_dust, warm_sparks]:
		particles.position.x = width * 0.5
		particles.position.y = height * 0.5
		particles.visibility_rect = Rect2(-width * 0.5, -height * 0.5, width, height)
	(cold_dust.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(width * 0.5, floor_top * 0.44, 1.0)
	(warm_sparks.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(width * 0.5, floor_top * 0.4, 1.0)
	cold_beacon_a.position.x = width * 0.28
	cold_beacon_b.position.x = width * 0.72
	warm_beacon_a.position.x = width * 0.28
	warm_beacon_b.position.x = width * 0.72
	floor_body.position = Vector2(width * 0.5, floor_top + 32.0)
	floor_visual.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -32.0), Vector2(width * 0.5, -32.0),
		Vector2(width * 0.5, 32.0), Vector2(-width * 0.5, 32.0),
	])
	floor_edge.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -3.0), Vector2(width * 0.5, -3.0),
		Vector2(width * 0.5, 3.0), Vector2(-width * 0.5, 3.0),
	])
	var floor_shape := floor_collision.shape as RectangleShape2D
	if floor_shape == null:
		push_error("PhaseRoomSide requires an authored RectangleShape2D floor")
		return
	floor_shape.size = Vector2(width, 64.0)
	var boundary_shape := left_boundary.get_node("CollisionShape2D").shape as RectangleShape2D
	if boundary_shape == null:
		push_error("PhaseRoomSide requires authored rectangle boundary collision")
		return
	boundary_shape.size = Vector2(64.0, height)
	left_boundary.position = Vector2(-32.0, height * 0.5)
	right_boundary.position = Vector2(width + 32.0, height * 0.5)
	phase_anchor.position.x = width - 260.0
	phase_anchor.position.y = floor_top - 24.0
	exit_area.position.x = width - 110.0
	exit_area.position.y = floor_top - 80.0
	camera_zone.size = world_bounds_px.size


# Applies the authored cold-ruin or warm-accident palette to this universe side.
func _apply_authored_palette() -> void:
	var warm_side := side == EntangledEntity.Side.XING_YAO
	cold_world_art.visible = not warm_side
	warm_world_art.visible = warm_side
	cold_ambience.visible = not warm_side
	warm_ambience.visible = warm_side
	floor_visual.color = Color(0.22, 0.11, 0.09, 1.0) if warm_side else Color(0.12, 0.24, 0.25, 1.0)
	floor_edge.color = Color(1.0, 0.38, 0.13, 0.92) if warm_side else Color(0.3, 0.78, 0.72, 0.86)
	phase_anchor_visual.modulate = Color(1.0, 0.58, 0.34, 0.82) if warm_side else Color(0.62, 0.88, 0.86, 0.78)


# Enables gameplay processing only for the current room pair.
func set_room_active(value: bool) -> void:
	room_active = value
	process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	if not value:
		set_exit_enabled(false)
	set_departed(false)


# Stops every room-owned physics body before this side leaves its PhysicsServer space.
func prepare_for_unload() -> void:
	set_room_active(false)
	for node: Node in find_children("*", "CharacterBody2D", true, false):
		var body := node as CharacterBody2D
		if body.has_method("prepare_for_room_unload"):
			body.call("prepare_for_room_unload")
		body.velocity = Vector2.ZERO
		body.set_physics_process(false)
		body.set_process(false)


# Marks this side as already through its exit while the partner finishes.
func set_departed(value: bool) -> void:
	departed = value


# Opens or closes the room exit without changing any causal device state.
func set_exit_enabled(value: bool) -> void:
	exit_enabled = value
	_exit_reported = false
	if is_node_ready():
		var warm_side := side == EntangledEntity.Side.XING_YAO
		if exit_enabled:
			exit_visual.modulate = Color(1.0, 0.68, 0.38, 1.0) if warm_side else Color(0.62, 1.0, 0.9, 1.0)
		else:
			exit_visual.modulate = Color(0.58, 0.34, 0.24, 0.66) if warm_side else Color(0.38, 0.5, 0.52, 0.68)


# Emits a clean checkpoint signal from an authored phase anchor.
func activate_checkpoint() -> void:
	if checkpoint_id.is_empty():
		return
	checkpoint_activated.emit(side, checkpoint_id)


# Captures only stable already-arrived devices under this authored side.
func capture_persistent_state() -> Dictionary:
	var state: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("phase_persistent"):
		if not is_ancestor_of(node) or not node.has_method("capture_persistent_state"):
			continue
		state[String(get_path_to(node))] = node.call("capture_persistent_state")
	return state


# Restores stable devices by authored node path without replaying in-flight events.
func restore_persistent_state(state: Dictionary) -> void:
	for node_path: String in state:
		var node := get_node_or_null(NodePath(node_path))
		if node == null or not node.has_method("restore_persistent_state"):
			push_error("PhaseRoomSide %s cannot restore persistent node '%s'" % [room_id, node_path])
			continue
		node.call("restore_persistent_state", state[node_path])


# Converts a real player overlap with the authored phase anchor into a clean checkpoint signal.
func _on_phase_anchor_body_entered(body: Node2D) -> void:
	if body is PhasePlayer:
		activate_checkpoint()


# Reports the exit only for an authored player body and only once.
func _on_exit_body_entered(body: Node2D) -> void:
	if not room_active or departed or not exit_enabled or _exit_reported or not body is PhasePlayer:
		return
	_exit_reported = true
	set_departed(true)
	exit_reached.emit(side)
