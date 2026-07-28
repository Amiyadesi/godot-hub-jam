class_name PhaseWorldSide
extends Node2D
## Persistent player and camera host for one authored universe viewport.

signal player_failed(side: int, reason: StringName)
signal room_transition_finished(side: int)

const AUTHORED_WORLD_SIZE := Vector2(1920.0, 704.0)
const CAMERA_FOLLOW_SPEED: float = 7.5
const CAMERA_DEAD_ZONE := Vector2(160.0, 92.0)

@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.LU_HENG

var _boss_preview_tween: Tween
var _camera_tween: Tween
var _departure_tween: Tween
var _camera_follow_enabled: bool = false
var _fill_viewport: bool = false
var _camera_bounds := Rect2(Vector2.ZERO, AUTHORED_WORLD_SIZE)
var _current_room: PhaseRoomSide
var _base_camera_zoom := Vector2.ONE

@onready var camera: Camera2D = $Camera2D
@onready var boss_spawn: Marker2D = $BossSpawn
@onready var player: PhasePlayer = $Player
@onready var boss_afterimage: Sprite2D = $BossAfterimage
@onready var boss_arrival_ring: Line2D = $BossArrivalRing
@onready var departure_fade: ColorRect = $DepartureLayer/DepartureFade


# Configures the fixed role and keeps the camera synced to its SubViewport crop.
func _ready() -> void:
	get_viewport().size_changed.connect(_fit_camera_to_viewport)
	_fit_camera_to_viewport()
	player.configure_role(side)
	player.failed.connect(_on_player_failed)
	departure_fade.visible = false
	clear_boss_visuals()


# Follows the retained player on both axes without exposing authored room bounds.
func _process(delta: float) -> void:
	if not _camera_follow_enabled or _current_room == null:
		return
	var target := _camera_position_with_dead_zone(_camera_bounds, player.position)
	camera.position = camera.position.lerp(target, minf(delta * CAMERA_FOLLOW_SPEED, 1.0))


# Fits the authored room by width normally, or fills merged mode without exposing outside space.
func _fit_camera_to_viewport() -> void:
	var viewport_size := Vector2(get_viewport().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var uniform_zoom := _camera_zoom_for_viewport(viewport_size)
	_base_camera_zoom = Vector2.ONE * uniform_zoom
	camera.zoom = _base_camera_zoom
	if _current_room != null:
		_camera_bounds = _current_room.get_camera_bounds()
		_update_camera_limits(_camera_bounds)
	camera.position = _camera_position_for(_camera_bounds, player.position)


# Switches merged-space framing between full-screen fill and normal split-screen width fit.
func set_full_viewport_fill(value: bool) -> void:
	if _fill_viewport == value:
		return
	_fill_viewport = value
	_fit_camera_to_viewport()


# Gives P1 or P2 ownership to this universe's persistent player.
func set_player_controlled(value: bool, slot: int) -> void:
	player.set_control_slot(slot)
	player.set_controlled(value)


# Moves the persistent player to the newly loaded authored room.
func reset_player_for_authored_room(room_spawn: Vector2, refill_health: bool) -> void:
	player.reset_player(room_spawn, refill_health)


# Binds the persistent player and camera to one active authored room side.
func bind_room(room_side: PhaseRoomSide, refill_health: bool, snap_camera: bool = true) -> void:
	if room_side == null:
		push_error("PhaseWorldSide.bind_room requires an authored room side")
		return
	cancel_transient_state()
	_current_room = room_side
	_camera_bounds = room_side.get_camera_bounds()
	_update_camera_limits(_camera_bounds)
	player.auto_defend = room_side.protect_uncontrolled_player
	player.reset_player(room_side.get_spawn_position(), refill_health)
	player.set_departed(false)
	_camera_follow_enabled = true
	if snap_camera:
		camera.position = _camera_position_for(_camera_bounds, player.position)
	_set_departure_fade(false)


# Locks one departed side while its partner remains in the current room.
func set_departed(value: bool) -> void:
	player.set_departed(value)
	_camera_follow_enabled = not value
	_set_departure_fade(value)


# Pans under the departure veil, then binds the retained player to the next room.
func transition_to_room(room_side: PhaseRoomSide, refill_health: bool, duration: float = 0.55) -> void:
	if room_side == null:
		push_error("PhaseWorldSide.transition_to_room requires an authored room side")
		return
	cancel_transient_state()
	player.set_departed(true)
	_camera_follow_enabled = false
	_set_departure_fade(true)
	var next_bounds := room_side.get_camera_bounds()
	var union_bounds := _camera_bounds.merge(next_bounds)
	_update_camera_limits(union_bounds)
	var target := _camera_position_for(next_bounds, room_side.get_spawn_position())
	_camera_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(camera, ^"position", target, maxf(duration, 0.0))
	_camera_tween.tween_callback(_finish_room_transition.bind(room_side, refill_health))


# Shows a non-interactive Boss afterimage at the departure point.
func show_boss_afterimage(at_position: Vector2) -> void:
	boss_afterimage.position = at_position
	boss_afterimage.visible = true
	boss_afterimage.modulate.a = 0.72
	var tween := create_tween()
	tween.tween_property(boss_afterimage, ^"modulate:a", 0.0, 1.0)
	tween.tween_callback(boss_afterimage.hide)


# Previews the target-space landing point while the single Boss body remains elsewhere.
func show_boss_arrival_preview(seconds: float) -> void:
	if _boss_preview_tween != null and _boss_preview_tween.is_valid():
		_boss_preview_tween.kill()
	boss_afterimage.position = boss_spawn.position
	boss_afterimage.visible = true
	boss_afterimage.scale = Vector2(1.35, 1.35)
	boss_afterimage.modulate.a = 0.12
	boss_arrival_ring.position = boss_spawn.position
	boss_arrival_ring.visible = true
	boss_arrival_ring.scale = Vector2(1.5, 1.5)
	boss_arrival_ring.modulate.a = 0.35
	_boss_preview_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_boss_preview_tween.parallel().tween_property(boss_afterimage, ^"scale", Vector2.ONE, seconds)
	_boss_preview_tween.parallel().tween_property(boss_afterimage, ^"modulate:a", 0.78, seconds)
	_boss_preview_tween.parallel().tween_property(boss_arrival_ring, ^"scale", Vector2(0.82, 0.82), seconds)
	_boss_preview_tween.parallel().tween_property(boss_arrival_ring, ^"modulate:a", 0.9, seconds)


# Clears the target preview after the Boss body reaches this viewport.
func clear_boss_arrival_preview() -> void:
	if _boss_preview_tween != null and _boss_preview_tween.is_valid():
		_boss_preview_tween.kill()
	boss_afterimage.visible = false
	boss_arrival_ring.visible = false


# Clears every Boss-only cue when a round or timeline resets.
func clear_boss_visuals() -> void:
	if _boss_preview_tween != null and _boss_preview_tween.is_valid():
		_boss_preview_tween.kill()
	boss_afterimage.visible = false
	boss_arrival_ring.visible = false


# Cancels room-owned camera and departure motion before a clean rebind.
func cancel_transient_state() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null
	if _departure_tween != null and _departure_tween.is_valid():
		_departure_tween.kill()
	_departure_tween = null
	_camera_follow_enabled = false
	departure_fade.visible = false
	var fade_color := departure_fade.color
	fade_color.a = 0.0
	departure_fade.color = fade_color
	player.prepare_for_role_switch()


# Returns the persistent authored player for ownership and Boss targeting.
func get_player() -> PhasePlayer:
	return player


# Returns the authored Boss arrival point in this viewport's world coordinates.
func get_boss_spawn_position() -> Vector2:
	return boss_spawn.position


# Completes the camera pan, restores control eligibility, and clears the veil.
func _finish_room_transition(room_side: PhaseRoomSide, refill_health: bool) -> void:
	_camera_tween = null
	bind_room(room_side, refill_health, true)
	room_transition_finished.emit(side)


# Centers a one-off spawn or transition target inside the authored room bounds.
func _camera_position_for(bounds: Rect2, target_position: Vector2) -> Vector2:
	return _clamp_camera_position(bounds, target_position)


# Moves only after the retained player leaves the authored screen-space dead zone.
func _camera_position_with_dead_zone(bounds: Rect2, target_position: Vector2) -> Vector2:
	var desired := camera.position
	if target_position.x < camera.position.x - CAMERA_DEAD_ZONE.x:
		desired.x = target_position.x + CAMERA_DEAD_ZONE.x
	elif target_position.x > camera.position.x + CAMERA_DEAD_ZONE.x:
		desired.x = target_position.x - CAMERA_DEAD_ZONE.x
	if target_position.y < camera.position.y - CAMERA_DEAD_ZONE.y:
		desired.y = target_position.y + CAMERA_DEAD_ZONE.y
	elif target_position.y > camera.position.y + CAMERA_DEAD_ZONE.y:
		desired.y = target_position.y - CAMERA_DEAD_ZONE.y
	return _clamp_camera_position(bounds, desired)


# Clamps the camera center using the real viewport crop so no map exterior can appear.
func _clamp_camera_position(bounds: Rect2, target_position: Vector2) -> Vector2:
	var viewport_size := Vector2(get_viewport().size)
	var uniform_zoom := _camera_zoom_for_viewport(viewport_size)
	var visible_width := viewport_size.x / uniform_zoom
	var visible_height := viewport_size.y / uniform_zoom
	var min_x := bounds.position.x + visible_width * 0.5
	var max_x := bounds.end.x - visible_width * 0.5
	var min_y := bounds.position.y + visible_height * 0.5
	var max_y := bounds.end.y - visible_height * 0.5
	var camera_x := bounds.get_center().x if min_x > max_x else clampf(target_position.x, min_x, max_x)
	var camera_y := bounds.get_center().y if min_y > max_y else clampf(target_position.y, min_y, max_y)
	return Vector2(camera_x, camera_y)


# Returns one uniform zoom that either preserves horizontal framing or fills the entire viewport.
func _camera_zoom_for_viewport(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	var width_zoom := viewport_size.x / AUTHORED_WORLD_SIZE.x
	if not _fill_viewport:
		return width_zoom
	var height_zoom := viewport_size.y / AUTHORED_WORLD_SIZE.y
	return maxf(width_zoom, height_zoom)


# Applies integer Camera2D limits from one authored world rectangle.
func _update_camera_limits(bounds: Rect2) -> void:
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)


# Fades the authored waiting-side veil without hiding the world completely.
func _set_departure_fade(value: bool) -> void:
	if _departure_tween != null and _departure_tween.is_valid():
		_departure_tween.kill()
	departure_fade.visible = true
	_departure_tween = create_tween()
	_departure_tween.tween_property(departure_fade, ^"color:a", 0.78 if value else 0.0, 0.2)
	if not value:
		_departure_tween.tween_callback(departure_fade.hide)


# Attaches the universe identity to player death and fall failures.
func _on_player_failed(_player: PhasePlayer, reason: StringName) -> void:
	player_failed.emit(side, reason)
