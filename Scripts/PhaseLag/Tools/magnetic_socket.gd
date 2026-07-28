class_name MagneticSocket
extends Area2D
## Authored equipment socket that accepts only explicit magnetic object kinds.

signal object_inserted(object: MagneticObject)
signal object_removed(object: MagneticObject)
signal occupied_changed(occupied: bool)

@export var accepted_kinds: Array[StringName] = []
@export var dock_texture: Texture2D
@export var dock_scale: Vector2 = Vector2.ONE
@export var dock_offset: Vector2 = Vector2.ZERO
@export var preview_texture: Texture2D
@export var preview_scale: Vector2 = Vector2.ONE
@export var completion_link_id: StringName = &""
@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.LU_HENG
@export var delay_override: float = -1.0

var occupied_object: MagneticObject

@onready var indicator: Polygon2D = $Indicator
@onready var dock_base: Sprite2D = $DockBase
@onready var slot_preview: Sprite2D = $SlotPreview


# Registers the socket for constrained magnetic-object lookup.
func _ready() -> void:
	add_to_group("magnetic_sockets")
	_update_visual()


# Reports whether one object kind is accepted and the socket is currently free.
func can_accept(object: MagneticObject) -> bool:
	if object == null or occupied_object != null:
		return false
	return accepted_kinds.is_empty() or accepted_kinds.has(object.object_kind)


# Snaps one accepted object into this authored equipment position.
func try_snap(object: MagneticObject) -> bool:
	if not can_accept(object):
		return false
	occupied_object = object
	object.complete_snap(self)
	_update_visual()
	_emit_socket_state(true)
	object_inserted.emit(object)
	occupied_changed.emit(true)
	return true


# Releases the current object so Lu Heng can move it after power is removed.
func release_object() -> MagneticObject:
	var object := occupied_object
	if object == null:
		return null
	occupied_object = null
	object.release_from_socket(self)
	_update_visual()
	_emit_socket_state(false)
	object_removed.emit(object)
	occupied_changed.emit(false)
	return object


# Sends the real installed or removed state only for sockets authored into a causal objective.
func _emit_socket_state(installed: bool) -> void:
	if completion_link_id.is_empty():
		return
	EntanglementBus.emit_event(
		completion_link_id,
		EntanglementBus.POWER_CHANGED,
		{"value": installed, "object_kind": occupied_object.object_kind if occupied_object != null else &""},
		side,
		delay_override
	)


# Shows the stable empty or occupied socket state.
func _update_visual() -> void:
	if not is_node_ready():
		return
	dock_base.texture = dock_texture
	dock_base.scale = dock_scale
	dock_base.position = dock_offset
	slot_preview.texture = preview_texture
	slot_preview.scale = preview_scale
	slot_preview.visible = occupied_object == null
	indicator.color = Color(0.32, 1.0, 0.78, 0.95) if occupied_object != null else Color(0.35, 0.48, 0.5, 0.85)
